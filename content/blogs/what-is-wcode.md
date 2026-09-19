---
title: "wcode 是怎么从一个 MCP Bridge 变成现在这样的"
date: 2026-09-12T05:40:00+08:00
lastmod: 2026-09-17
draft: false
url: /blog/what-is-wcode/
translationKey: what-is-wcode
image: /img/wcode/wcode-intro-architecture.png
description: "wcode 最早只是想让网页里的模型碰到本地代码。后来我越用越觉得，真正麻烦的是模型怎么读仓库、怎么改、以及怎么证明改完了。"
tags:
  - wcode
  - Rust
  - MCP
  - Coding Agent
  - Developer Tools
images:
  - /img/wcode/wcode-intro-architecture.png
---

<p class="project-logo"><a href="https://wcode.francis.run/" target="_blank" rel="noopener" title="wcode 文档"><img src="/img/wcode/wcode-logo.svg" alt="wcode" width="320" height="96"></a></p>

<p class="project-links"><a href="https://github.com/francis-du/wcode" target="_blank" rel="noopener">GitHub ↗</a><a href="https://wcode.francis.run/zh/docs/" target="_blank" rel="noopener">文档 ↗</a></p>

我做 wcode 的起点，其实不是想再做一个 Coding Agent。

最开始的想法很简单：把网页里已经能直接用的模型拿来写代码，同时让它们能读到我电脑上的真实仓库。模型在浏览器里，代码却在本地。稍微复杂一点的问题，我就得复制文件、上传压缩包、解释目录结构；代码一改，前面传进去的内容马上又旧了。

所以第一版 wcode 更像一座桥。它把本地仓库通过工具接给网页端模型，让模型可以自己搜索文件、读代码、做修改、跑检查。后来 MCP 出现，这件事有了更标准的连接方式，但真正让我继续往下做的，并不是“终于能连上了”。

连接打通以后，另一个问题反而越来越明显：Agent 到底是怎么读代码的？

不少 Code CLI 在仓库发现阶段会大量使用 `grep`、`ripgrep`、文件列表和各种 shell 命令。这个做法本身没问题，我自己也一直在用。它很快，找一个字符串、文件名或者明显的符号时甚至就是最合适的办法。

问题在下一步。

搜索返回的是“这里命中了几段文本”。模型还得自己从这些片段里重新拼出：哪个才是真正的定义、两个同名符号是不是一回事、谁在调用谁、改这一处会波及哪里、对应测试在哪、某条关系到底只是文本上看起来像，还是语言服务器真的确认过。

模型越强，这种做法当然越能工作，但本质上还是把大量仓库理解工作重新丢回了 Context Window。仓库一大、同名符号一多、跨模块调用一复杂，误判就很容易从这里开始。

wcode 后来就是从这里开始变的。我不再只加命令，而是开始单独处理“模型怎么读一个仓库”这件事。

## 后来我开始管 Agent 怎么读仓库

现在的 wcode 仍然会用文本搜索，而且普通定位默认就应该走便宜的路径。问“`FooConfig` 在哪”，没必要为了显得高级就启动一整套语义分析。

但问题一旦变成“谁调用它”“这个实现有哪些引用”“改这里会影响什么”“哪个测试真正覆盖这条行为”，纯文本命中就不够了。wcode 会先用 Tree-sitter 建立稳定的语法结构，需要跨文件语义关系时再使用可用的 Warm LSP；同时把 Git 当前状态、Design State、测试入口和已经知道的软件图关系一起带进来。

最后交给模型的，不只是几段搜出来的源码，而是一份有边界的任务上下文：相关符号和精确范围、引用或调用关系、关联测试、当前修改、项目约束，以及这些信息来自哪里、是什么精度、对应哪个版本。

可以把两种读取方式粗略理解成：

- **常见文本发现链路**：任务 → `grep/ripgrep` / 文件切片 → 命中文本 → 模型自己重建代码关系。
- **wcode 的链路**：任务 → 便宜定位 → 按需解析语法/语义关系 → 整理成任务上下文 → 模型基于带来源和精度的证据继续推理。

<figure class="content-image">
  <img src="/img/wcode/wcode-intro-intelligence-stack.zh-CN.svg" alt="文本搜索式代码发现与 wcode 仓库读取方式的对比" width="1600" height="960" loading="lazy" decoding="async">
  <figcaption>wcode 不是为了淘汰 grep。精确定位时搜索通常就是正确工具；需要结构、调用、实现、影响或验证关系时，再增加更强的代码理解。</figcaption>
</figure>

拿一个很普通的例子：给列表接口增加“按状态筛选”。只搜接口名，很容易找到 Handler，却未必会顺着参数定义、查询构造、调用方和测试一路看完。`agent_context` 会先围绕当前任务整理相关实现、测试、项目约定和可用的检查入口；如果任务明确需要 Caller、Reference、Implementation 或 Impact，Readiness 再提示 Agent 使用语义导航。

这点对我很重要：**不是每个问题都做最重的分析，而是让模型知道什么时候搜索已经够了，什么时候必须继续确认代码关系。** 工具能证明到哪一层，就只说到哪一层。Tree-sitter 的语法事实不会包装成编译器语义；LSP 不可用时也不会假装已经找全了调用方。

## 接上仓库以后，还得防止改错

继续拿筛选接口这个例子。Agent 读完文件，正在生成修改时，我也可能在编辑同一个文件。

如果它直接把旧版本上的修改写回来，就可能覆盖我刚加的内容。所以 wcode 读文件时会返回一个 SHA，可以把它理解成文件内容的指纹。编辑时必须带上这个指纹；内容已经变了，旧编辑就会被拒绝，Agent 要重新读。

修改也需要控制范围。读几个互不相关的文件可以一起做；两次修改都要动同一个文件，就不能随便同时写。改完之后，用 `review_changes` 看实际差异，再用 `verify_project` 跑项目里已有的检查。

<figure class="content-image">
  <img src="/img/wcode/wcode-intro-engineering-loop.zh-CN.svg" alt="一次代码修改的流程：找依据、修改文件、检查结果，再继续下一步" width="1600" height="900" loading="lazy" decoding="async">
  <figcaption>我希望一次任务最后能回答：改了哪里，检查过什么，还有什么没确认。</figcaption>
</figure>

wcode 文档里把这一层叫作“工程控制面”。落到日常使用，就是把文件、操作记录和检查结果留清楚。换一个模型或者接着做下一轮，也能查到前面发生过什么。

## 测试通过，也得看是哪一次修改

给接口加了筛选条件，测试通过了。接着又调整参数解析，却没有再跑测试。这时，前面的通过记录只能说明前一个版本通过了。

wcode 会把检查结果和当时的代码、设计版本关联起来。界面里的几个状态也有区别：找到测试文件，只能算“有对应检查”；真正运行过、结果通过、结果仍适用于当前版本，是后面的几件事。

![wcode 验证页面：查看检查有没有执行、结果是否通过，以及是否对应当前版本](/img/wcode/wcode-intro-evidence.png)

检查本身也要选对。这个博客用 Hugo 生成网页，写完 Markdown 以后，至少要真正构建一次，确认中英文页面都生成了、图片能找到、原来的地址没有变。只看文字没有语法错误，证明不了这些事情。

对代码项目，则需要运行相应的编译、测试或其他项目检查。涉及更大风险的改动，可以按配置增加更深入的验证。下图列出了这些通道，并不是每次修改都要把它们全部跑一遍。

<figure class="content-image">
  <img src="/img/wcode/wcode-intro-verification-mesh.zh-CN.svg" alt="wcode 如何根据改动选择检查，并保存对应版本的执行结果" width="1600" height="940" loading="lazy" decoding="async">
  <figcaption>项目和验证计划决定哪些检查必须完成；缺少执行结果，不能靠一句“应该没问题”补上。</figcaption>
</figure>

历史上的成功修改可以帮助下一次任务找方向，但旧测试结果不能一直沿用。这是我希望 wcode 替我记住的一件事。

## 项目里的规矩，得有地方放

有些要求从一段代码里看不出来。

比如这个博客，中文页面一直在根路径，英文放在 `/en/`；摄影 Gallery 有自己的页面和脚本；改文章时要保留原来的公开地址。Agent 如果不知道这些约定，很容易在完成眼前任务时，顺手改掉别的行为。

wcode 可以把这类要求写进仓库的 `.wcode/` 目录。文档把它们称为 Design State，里面记录需求、组件、约束和验收条件。之后查项目、分析一次修改的影响时，可以把这些要求一起带出来。

工程观测台默认打开架构页面。从这里可以看组件对应哪些源码、关联哪些需求，以及分析工具发现了哪些依赖。

![wcode 工程架构页面：查看组件、源码归属、需求与依赖关系](/img/wcode/wcode-intro-architecture.png)

这些记录需要跟着项目维护。图画出来了，不代表架构就没有问题；它的用处是让原来散在文件和讨论里的信息，有一个可以一起核对的地方。

## 它能访问什么，由谁决定

wcode 围绕选定的 Workspace 工作，也就是这次允许访问的项目范围。文件操作会检查路径、受保护位置和不安全的链接，已有文件的修改还要检查内容指纹。

命令另有规则。常见、有明确边界的开发命令可以直接运行；需要额外信任的操作，会进入本地授权流程。访问页面可以查看具体请求，由操作者决定是否允许。更宽的会话授权或 Full Access，也需要操作者明确选择。

<figure class="content-image">
  <img src="/img/wcode/wcode-intro-security-boundary.zh-CN.svg" alt="AI 客户端到本地仓库之间的检查：连接认证、命令授权和文件访问范围" width="1600" height="920" loading="lazy" decoding="async">
  <figcaption>能连接到 wcode，不等于可以执行任意命令或访问任意文件。</figcaption>
</figure>

![wcode 访问管理页面：查看当前项目的权限和待处理授权请求](/img/wcode/wcode-intro-access.png)

本地客户端可以用 stdio 启动 wcode；远程客户端通过 OAuth 连接运行中的服务。这两种接法提供同一套仓库能力。文件操作发生在仓库所在机器，使用云端模型时，读出的代码仍会作为工具结果交给对应客户端。

wcode 的这些检查属于工具和仓库层，并不等同于操作系统沙箱。

## 界面里能看到什么

我主要用界面确认工作进行到哪里。

终端面板能看到连接、当前项目、任务和授权请求。按 `W` 打开工程观测台，按 `O` 打开设置页面。观测台里可以看架构、当前修改、需求和项目文件，也可以查看前面提到的验证记录。

任务慢下来时，**任务活动**页面会更有用。它把排队时间和实际执行时间分开，也显示子进程和资源使用情况。一个命令迟迟没结束，可能是在等运行机会，也可能是真的执行了很久，处理办法不一样。

![wcode 任务活动页面：查看任务在排队还是执行，以及工具调用和资源使用情况](/img/wcode/wcode-intro-activity.png)

wcode 也分别限制 CPU 工作、文件读写和子进程的并发量。互不依赖的事情可以一起做，机器也要留有余量。这部分仍然需要结合实际任务观察，不能只看一个并发数字。

## 怎么开始用

如果你已经有习惯使用的 AI 编程助手，可以拿一个自己熟悉的项目试试。先做一个小修改，比较容易判断工具找的代码对不对、修改有没有跑偏。

macOS 和 Linux 可以用发布版安装脚本：

```bash
curl -fsSL https://raw.githubusercontent.com/francis-du/wcode/main/install.sh | sh
```

Windows 的安装方法见[快速开始](https://wcode.francis.run/zh/docs/getting-started/)。装好后，在项目目录里运行：

```bash
wcode setup
```

按提示选择全局或当前项目配置，再重新连接 Agent。本地 stdio 模式由客户端启动进程；需要终端面板、网页界面或远程接入时，运行 `wcode`。远程接入使用程序显示的当前 MCP 地址，并完成 OAuth，详细步骤见[客户端集成文档](https://wcode.francis.run/zh/docs/code-agent-integrations/)。

第一轮不用把所有功能都配置好。先跑一个最小闭环：

1. 让 Agent 找到一处实现；
2. 改一个行为；
3. 跑对应检查；
4. 自己看一遍 diff。

接下来再把确实需要反复遵守的项目约定写进 `.wcode/`。

[源码在 GitHub](https://github.com/francis-du/wcode)，安装和接入说明放在[项目文档](https://wcode.francis.run/zh/docs/)里。模型仍然由你正在使用的服务提供，wcode 负责连接和处理仓库这一侧的工作。
