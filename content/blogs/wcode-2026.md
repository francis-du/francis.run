---
title: "wcode 最近做成什么样了"
date: 2026-08-26T03:10:00+08:00
draft: false
url: /blog/wcode-2026/
image: /img/wcode/wcode-tui.png
description: "第一版 wcode 只是想把 Web AI 接到本地代码。后来我开始关心另一件事：代码被人和模型反复修改以后，项目还能不能说清楚自己为什么是现在这样。"
tags:
  - Rust
  - MCP
  - AI Agent
  - wcode
images:
  - /img/wcode/wcode-tui.png
---

我前几天写过一篇 [wcode 的第一版介绍](/blog/wcode/)。

那篇写的是最早的 wcode：我想在 Web 端继续用自己喜欢的模型，又想让它们安全地碰到本地代码，所以做了 Remote MCP、OAuth、Workspace、Tree-sitter、文件修改和命令执行。

这些东西现在都还在。

但写完第一版没多久，我发现项目已经不是那篇文章里的样子了。

不是底层推翻了。恰恰相反，底层越来越像基础设施，平时不太需要想它。真正让我反复改的是另一件事：**一次代码修改结束以后，到底留下了什么。**

模型把代码改出来已经不算很难。难的是一个仓库被我、不同模型、不同工具来回改几十次以后，我还能不能回答这些问题：

```text
这段代码为什么必须这样？
它对应哪个需求？
这次修改实际碰到了哪些功能？
原来的约束还成立吗？
测试绿了，绿的是哪个 revision？
谁 review 过？
还有没有没处理完的东西？
```

Git 很擅长告诉我“哪里变了”，但它不会替我保存“为什么这么设计”。聊天记录更不适合做这个事情，换个模型基本就断了。

所以最近 wcode 的重心慢慢从“给模型一套本地工具”，变成了“把软件本身的状态留下来”。

现在粗略可以画成这样：

```text
.wcode Design State
        │
        ├── Requirement / Constraint / Acceptance
        │
Product Scope ───── Source Code
        │              │
        └──── Software Graph
                    │
               Git Actual State
                    │
          Drift / Impact / Risk
                    │
          Reconciliation Plan
                    │
              Verification
                    │
                Evidence
```

这张图看起来比第一版复杂不少，但实际使用时反而更简单了：模型还是写代码，wcode 主要负责把它写代码前后那些容易丢掉的状态接起来。

![wcode 终端实时面板](/img/wcode/wcode-tui.png)

## 我先把“为什么”放进仓库

最先加的是 Design State。

现在项目可以有一份 `.wcode`：

```text
.wcode/
├── project.yaml
└── design/
    ├── product.yaml
    ├── requirements.yaml
    ├── components.yaml
    ├── constraints.yaml
    ├── acceptance.yaml
    └── decisions.yaml
```

我没有想把它做成另一种编程语言。里面主要是稳定 ID 和关系：Requirement 由哪个 Component 实现，Component 落在哪些代码上，Acceptance 最后由什么测试或检查来验证。

这样我再改 Workspace Security 时，入口不一定非得是“先打开哪个 Rust 文件”。可以先问：这个 Requirement 现在的实现和验证在哪里。

wcode 自己也在用这套 Design State。这个 Dogfood 很重要，因为只设计格式不用，很容易最后做出一堆看起来完整、实际没人愿意维护的 YAML。

## 仓库大了以后，我又加了 Product Scope

后来代码继续长，另一个问题出来了。

即使已经有 `software_context`，一个任务如果每次都在整个仓库里找，返回的东西还是会越来越杂。尤其 wcode 自己同时有 Runtime、MCP、Workspace、Graph、Verification、UI，一句“看看安全问题”很容易把几个完全不同的模块一起捞回来。

所以现在有一套固定的 Product Scope。

它不是业务标签系统，更像 wcode 自己的能力分区。`scope_status` 会告诉我源码现在落在哪些 Scope，还有哪些文件没有被归类；`software_context(scopes=...)` 则可以真的把源码导航缩到选中的范围。

这个功能的起因很朴素：我不想项目目录已经拆得很清楚了，Agent 进来以后又把它当成一个巨大的平面文件夹。

## Software Graph 还在，但我不再拿一团球当 UI

Tree-sitter 仍然是底座。

它不需要启动项目，也不需要信任仓库配置，就能拿到定义、Range、Qualified Name 和一部分语法级调用关系。这些关系进入 Software Graph 时会老老实实写：

```text
provider = tree-sitter
precision = syntax
```

如果本机有对应 Language Server，而且我允许它运行，wcode 才会把真实返回的 Document Symbol、Call Hierarchy、Implementation 作为 semantic fact 加进去。

源码变了以后，旧 LSP 结果会因为 Source Hash 不一致变成 stale，不再混进新的分析。

Graph 也会留 meaningful history，可以看版本之间 Node / Edge 到底怎么变了。

一开始我给 WebUI 做过一个可以拖拽、缩放、筛选的 Graph Canvas。技术上没什么问题，但我自己用几次就觉得没意思。

我打开页面不是为了看一团会动的球。

我想看的是：

```text
这个 Requirement 是什么
谁实现它
现在代码落在哪里
Acceptance 怎么验证
这次 Git 改动碰了什么
设计依赖和代码依赖有没有对上
```

所以现在主界面已经换成 requirement-first 的 **Project Observatory**。低层 Software Graph 还在，而且仍然参与 Impact、Context 和历史 Diff，只是不再被当成“产品首页”。

这个改动我自己很喜欢。图是手段，不是目的。

## Risk 终于不用靠一句“这里比较重要”

以前让 Agent 改安全相关代码时，我经常会顺手补一句：

> 这个地方比较重要，多检查一下。

现在回头看，这句话几乎没约束力。

wcode 会把 Git Change、Traceability Gap、Drift、Design 里声明的风险以及一些结构性变化合起来，再决定 Verification 要走多深。

最近还补了 Maintainability Review。

例如一个文件这次改动后从 1,000 行以下跨到 1,000 行以上，或者大量代码集中长在一个文件里，或者一次变更横跨多个 Product Scope，`review_changes` 会把它们作为结构信号提出来。

这不是在声称“超过 1,000 行就一定烂”。它只是提醒：代码在往一个值得单独看一眼的方向长。

Medium 及以上风险的 Verification Plan 还会有独立的 maintainability reviewer。Correctness 过了，不代表结构就可以不看。

## Verification 现在会留下证据

`verify_project` 还在做最普通的工程检查。

Rust 项目仍然是这些：

```text
quick
  git diff --check
  cargo fmt --check
  cargo check --locked

full
  cargo test --locked
  cargo clippy --locked -- -D warnings
  cargo build --release --locked
```

更深一层的 Verification Plan 可以要求 Property、Mutation、Fuzz、Runtime Canary、独立 Reviewer 或 Human Approval。

我以前最不喜欢 Agent 最后只留一句：

```text
Tests passed.
```

现在 Verification 会形成 Evidence，至少能知道是谁产生的、针对哪个 code revision、哪个 design revision、什么 policy、结果是什么。

Reviewer 结论冲突也不会被后来的 Pass 冲掉。冲突就是 `Disagree`。

“有争议”本身比“系统帮我平均成通过”更有用。

## Reconciliation 是我最近改得最多的一块

早期 Coding Agent 的流程基本是：

```text
读 → 改 → 测 → 结束
```

现在我更关心“这个修改什么时候真的算结束”。

Reconciliation Plan 会把 Drift、Impact、Risk、Change Intent 和 Verification Requirement 组织成有依赖的任务。执行状态可以 Claim、Submit、Retry，而且会持久化。

所以一个模型做 Implementation，另一个模型来做 Security Review，再换一个补测试，不需要共享同一段聊天历史。

它们面对的是同一个 Plan、同一个 revision、同一组 Evidence。

不过 Reconciliation 没有一套隐藏的超级权限。真正改文件还是走 Workspace 的 Root、SHA、原子写入、Symlink/Hardlink 防护和授权逻辑。

Plan 不能覆盖现实里的文件状态。

## 有些权限我后来做得更细了

第一版只有比较粗的 `--allow-risky-exec`：启动时显式告诉 wcode，这个进程可以跑 repository-aware 的高风险执行。

现在这条路径还在，但不是唯一方式。

Language Server、Runtime Executor 这类操作，如果当前没有进程级授权，也可以先生成一个本地 Authorization Request。我在 TUI 或受保护 WebUI 里批准这个具体操作，再重试。

现在还多了一层 `CommandAccess`：模型请求一个当前 Workspace 尚未授权的裸可执行程序名时，会自动进入 Pending 列表。TUI 用 ↑/↓ 选择，`Y` / `N` 只处理当前选中请求；Project Observatory 也能逐条批准或拒绝，同时管理项目和已授权命令。批准某个 Program 不会开放 Shell，Shell Interpreter、路径逃逸和受保护资源仍是硬边界。

删除更严格：`delete_path` 只能删普通文件或空目录，文件还要带当前 SHA，而且授权是 exact one-shot，用完就没了。

我更喜欢现在这个粒度。不是为了省一次确认，就把整个进程后面的高风险操作全部放开。

## MCP 反而退到了后面

第一版文章里 MCP 是主角，现在它更像接口层。

本地 Agent 直接走：

```bash
wcode --workspace /absolute/path/to/repo mcp-stdio
```

Web / Cloud 端走 Streamable HTTP + OAuth。

后面还是同一个 Workspace、Harness、Software Intelligence 和 Evidence Runtime。

需要把工作习惯带到不同 Agent 时，可以导出一个很小的 Skill：

```bash
wcode --workspace "$PWD" agent-plugin --output wcode-agent-plugin
```

它只有 Metadata 和 `SKILL.md`，不会顺手塞 Hook、脚本、Credential，也不会替我猜 Workspace。

Skill 告诉 Agent 怎么工作，MCP 决定它到底能做什么。我还是想把这两件事分开。

## 现在我怎么用

平时还是：

```bash
wcode --workspace "$PWD"
```

进入一个不熟的仓库，我现在更习惯先看：

```text
workspace_info
scope_status
design_status
project_context
```

再根据任务选 Scope，用 `software_context` 找代码。

改完后才是：

```text
review_changes
→ drift_status / impact_analysis / risk_status
→ reconciliation / verification
→ evidence_status
```

TUI 里 `I` 看 Intelligence，`W` 打开 Project Observatory。

这一套还在继续变，但方向已经和第一版很不一样了。第一版解决“怎么让模型安全地进仓库”，最近这些东西解决的是“它进来以后，项目怎么别越改越说不清楚”。

后面几篇我分开写：

- [Design State：我为什么把需求写进仓库](/blog/wcode-design-state/)
- [Software Graph：先承认自己不知道](/blog/wcode-software-graph/)
- [Git Diff 之外，我还想知道什么](/blog/wcode-traceability/)
- [测试通过以后，我还想留下什么](/blog/wcode-verification/)
- [我为什么开始把 edit file 往后放](/blog/wcode-reconciliation/)
- [MCP 负责能力，Skill 只负责工作习惯](/blog/wcode-mcp-agent/)
- [我还是不想给 Agent 一个 Shell](/blog/wcode-security/)
- [wcode v0.3：从本地代码桥到 Software Intelligence Runtime](/blog/wcode-v0-3/)
- [我把 wcode 写代码这条链又压快了一轮](/blog/wcode-performance/)

代码在 <https://github.com/francis-du/wcode>。