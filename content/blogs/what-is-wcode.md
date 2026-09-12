---
title: "wcode 是什么：给 Coding Agent 一套本地代码运行时"
date: 2026-09-12T05:40:00+08:00
draft: false
url: /blog/what-is-wcode/
image: /img/wcode/wcode-architecture.png
description: "wcode 是我用 Rust 写的一套本地 Coding Agent 运行时：负责仓库访问、代码检索、语义导航、受控修改、验证证据和项目状态，而模型和对话界面可以自己选。"
tags:
  - wcode
  - Rust
  - MCP
  - Coding Agent
  - Developer Tools
images:
  - /img/wcode/wcode-architecture.png
---

<p class="project-logo"><a href="https://wcode.francis.run/" target="_blank" rel="noopener" title="wcode 文档"><img src="/img/wcode/wcode-logo.svg" alt="wcode" width="320" height="96"></a></p>

<p class="project-links"><a href="https://github.com/francis-du/wcode" target="_blank" rel="noopener">GitHub ↗</a><a href="https://wcode.francis.run/" target="_blank" rel="noopener">文档 ↗</a></p>

我最开始写 wcode 时没打算再做一个 Coding Agent。

ChatGPT、Claude、Grok 我都在用。麻烦的是本地仓库：Web 端聊得挺顺，一碰代码就要复制文件、上传压缩包，或者换客户端、再配一套 API Key。

所以第一版 wcode 很简单：把本地代码库通过 MCP 接给我已经在用的 AI。

桥接做好以后，问题很快从“把文件给模型看”变成了仓库状态：它读的是不是最新版本？这个符号到底在哪？搜索结果来自 Tree-sitter 还是 Language Server？两个修改能不能并行？测试跑完以后代码又变了怎么办？

现在的 wcode，主要就在解决这些问题。

## 我现在怎么理解 wcode

**wcode 是一套跑在本机的 Coding Agent runtime / harness。**

模型负责理解需求和做决策；wcode 负责把仓库变成一组有边界、可验证的工程能力。

```text
ChatGPT / Claude / Codex / 其他 Agent
                 │
                 │ MCP
                 ▼
┌──────────────────────────────────┐
│              wcode               │
│                                  │
│ Workspace / Auth / Permissions   │
│ Search / Tree-sitter / LSP       │
│ Safe edits / Git / Commands      │
│ Design State / Verification      │
│ Evidence / Observatory           │
└────────────────┬─────────────────┘
                 │
                 ▼
             本地仓库
```

它不绑定某个模型，也不要求聊天必须发生在 wcode 自己的 UI 里。能说 MCP 的客户端可以直接接；本地 Agent 也可以走 stdio。

我更想把 wcode 做成一层稳定的本地基础设施。模型换了，仓库访问、权限、索引和验证逻辑不用跟着重写。

## 我日常主要用它做这些事

### 先把当前仓库搞清楚

最基础的是读文件、搜代码、找符号，但 wcode 不只返回一坨文本。

Tree-sitter 负责便宜的结构化索引，比如定义、范围、文件 outline。需要跨文件引用、实现、调用关系时，再进入 Language Server。两种结果会明确标出来源和精度，不会把语法猜测包装成“精确语义”。

`agent_context` 会再往前走一步。它不是把整个仓库塞进上下文，而是根据当前任务整理出：

- 直接相关的文件和 SHA；
- 仓库自己的说明和约束；
- Design State；
- 当前语义能力是否就绪；
- 可以并行的工作 lane；
- 推荐的最小修改路径；
- 后面应该跑什么验证。

这样模型第一次动手时通常已经有目标文件、版本和验证入口，不用先从仓库根目录摸索。

### 编辑要带版本前置条件

Agent 最容易制造的一类事故，是拿旧上下文覆盖新代码。

wcode 读文件会返回 SHA。编辑已有文件时，这个 SHA 是前置条件。如果我在模型思考期间手动改过文件，旧编辑会直接失败，不会安静地把我的修改盖掉。

路径本身也不是权限。Workspace 会挡住父目录逃逸、Symlink、受保护文件和一些明显不该碰的位置。需要扩大权限时，由本地授权层决定，不能让模型自己说一句“这个命令没问题”就算批准。

### 并行按依赖走

我以前也很容易盯着 slots、peak 这些数字看性能。后来 0.6.x 重做了一轮以后，这个想法基本放下了。

现在的调度很朴素：互不依赖的读取和分析尽快一起跑；有依赖的任务等前置完成；两个会互相覆盖的写入排队。

wcode 现在把外层工具槽、CPU、文件 I/O、子进程、Git probe 分开控制。这样“并发 32”不会被误解成“同时跑 32 个编译任务”。

### 验证结果和代码版本绑在一起

Agent 世界里，“tests passed”这句话太便宜了。

我会看四件事：跑了哪些检查、对应哪个代码 revision、当时的 Design State 是什么、这份结果现在还有效没有。

wcode 的 verification 会记录这些东西。如果测试跑完以后代码又变了，旧证据不会自动算到新版本头上。Project Observatory 里也会把“这个测试和需求有映射”“它实际执行了”“它通过了”“证据仍然新鲜”分开显示。

长任务做到后半段时，这些信息比一句 `tests passed` 有用得多。

![wcode Project Observatory](/img/wcode/wcode-observatory-full.png)

## Design State 是后来加进去的一块

代码本身只能告诉 Agent“现在是什么样”，很难告诉它“本来应该是什么样”。

所以我后来把需求、组件、约束、验收条件也放进仓库里的 `.wcode/`。它们会直接参与上下文、影响分析、漂移检测和验证映射，不是另外维护一套长篇架构文档。

比如我现在这个博客也已经用 wcode 管了。里面会明确写：

- 中文 URL 保持在根路径，英文放 `/en/`；
- Gallery 有自己单独的脚本和渲染生命周期，不能被普通文章模板顺手改坏；
- 技术文章不能写成一眼 AI 生成的模板文；
- 改模板以后必须真的跑 Hugo build，不能只看 `git diff --check`。

这类东西靠聊天记忆很容易丢，放进仓库就清楚多了。

## wcode 适合什么场景

我自己主要拿它做三件事。

第一种是给 Web AI 接本地仓库。我可以继续用已经订阅的 Web 产品，让 wcode 只负责本地代码能力，不必因为“要读代码”再单独买一份模型 API Token。

第二种是给本地 Coding Agent 当 harness。Agent 不需要自己重复造搜索、权限、编辑事务、验证和项目状态这些东西。

第三种是长时间、跨很多文件的改动。任务越长，旧上下文、并发冲突、验证失效和“做到哪了”越容易出问题，这也是我现在花最多时间的方向。

## 它不负责什么

wcode 不提供模型，也不想替你决定哪个模型最好。

它没有自己的 Agent 人格，不保存你的聊天历史，也不会因为接了 MCP 就绕过模型提供商自己的套餐、速率和上下文限制。

它负责的是本机这一侧：仓库、工具、权限、状态和证据。

模型和客户端我会换，本地仓库的权限、验证和工程规则我不想跟着一起重写。

## 怎么开始

项目源码在 GitHub：

[github.com/francis-du/wcode](https://github.com/francis-du/wcode)

完整安装、客户端接入和命令说明放在：

[wcode.francis.run](https://wcode.francis.run/)

装好以后可以先跑：

```bash
wcode setup
```

想看所有普通和高级命令：

```bash
wcode help-all
```

如果只是想知道 wcode 值不值得折腾，我会建议先别看完所有文档。拿一个你熟悉的仓库接进去，让 Agent 做一次“找问题 → 改代码 → 跑验证”的完整任务，很快就能看出这层 runtime 对你有没有用。
