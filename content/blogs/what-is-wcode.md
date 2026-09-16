---
title: "wcode 是什么，以及我为什么做它"
date: 2026-09-12T05:40:00+08:00
lastmod: 2026-09-16
draft: false
url: /blog/what-is-wcode/
translationKey: what-is-wcode
image: /img/wcode/wcode-intro-architecture.png
description: "wcode 是我用 Rust 写的本地工具，让 AI 编程助手直接查代码、改文件、跑检查。这篇用一次接口修改，讲清它能做什么、怎样检查结果，以及如何开始使用。"
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

我最开始做 wcode，是想省掉一件反复在做的事：给 AI 搬代码。

项目就在电脑上，但在网页里聊一个问题，还是要复制文件、上传压缩包，告诉它目录怎么分、入口在哪里。聊到一半，代码又改了，前面传过去的内容也就旧了。

**wcode 做的第一件事，就是让 AI 编程助手直接在本地项目里查代码、改文件、跑检查。** 它是一个用 Rust 写的程序，运行在仓库所在的机器上，通过 MCP 和 AI 客户端连接。MCP 可以理解为一套让 AI 调用外部工具的协议。

接通以后，我发现“能改代码”只是开始。还要知道它根据什么改、有没有覆盖别人的修改、检查是不是真的跑过。现在的 wcode，也在处理这些事情。

## 先让 AI 看到正在用的那份代码

假设我要给一个列表接口增加“按状态筛选”。

只把接口那几十行代码贴给 AI，通常还不够。它需要知道参数在哪里定义、查询怎么拼、谁在调用这个接口、测试放在哪。有些限制也藏在项目约定里：参数可不可以为空，旧调用方要不要继续兼容。

wcode 提供读文件、搜索、查符号和调用关系等工具。`agent_context` 会围绕这次任务，先整理相关实现、测试、项目约定和后续检查入口。遇到不清楚的地方，Agent 再继续查。这样每次讨论都能回到实际仓库，而不是一直围着几段粘贴的代码猜。

下面这张图画的是这些信息从哪里来。上面是源码、Git 和项目约定，中间把它们联系起来，下面是 Agent 用来定位问题、分析影响和执行检查的工具。

<figure class="content-image">
  <img src="/img/wcode/wcode-intro-intelligence-stack.zh-CN.svg" alt="wcode 如何把源码、Git、项目约定和代码分析结果提供给 AI 编程助手" width="1600" height="960" loading="lazy" decoding="async">
  <figcaption>工具返回的信息会标明来源和版本。语法扫描与语言服务器分析的结果，精度也会区分。</figcaption>
</figure>

这里有个容易忽略的区别：搜到一个名字，不等于找到了全部调用方。Tree-sitter 主要看代码结构；可用的语言服务器能提供更深入的引用、实现和调用关系。工具能确认多少，就应该说多少。

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

终端面板能看到连接、当前项目、任务和授权请求。按 **W** 打开工程观测台，按 **O** 打开设置页面。观测台里可以看架构、当前修改、需求和项目文件，也可以查看前面提到的验证记录。

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

第一轮不用把所有功能都配置好。让 Agent 找到一处实现，改一个行为，跑对应检查，然后自己看一遍 diff。接下来再把确实需要反复遵守的项目约定写进 `.wcode/`。

[源码在 GitHub](https://github.com/francis-du/wcode)，安装和接入说明放在[项目文档](https://wcode.francis.run/zh/docs/)里。模型仍然由你正在使用的服务提供，wcode 负责连接和处理仓库这一侧的工作。
