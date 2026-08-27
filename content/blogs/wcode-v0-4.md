---
title: "wcode v0.4：开始为 Agent 的上下文成本负责"
date: 2026-08-27T23:55:00+08:00
draft: false
url: /blog/wcode-v0-4/
image: https://wcode.francis.run/assets/img.png
description: "v0.3 把 wcode 变成了 Software Intelligence Runtime，v0.4 没继续堆大功能，而是重新压了一遍 Agent 真正写代码的热路径：更少 Context、更少 Tool Round-trip、更清楚的架构和更精确的执行边界。"
tags:
  - wcode
  - Rust
  - MCP
  - AI Agent
  - Release
images:
  - https://wcode.francis.run/assets/img.png
---

v0.3 做完以后，wcode 已经有 Design State、Software Graph、Traceability、Risk、Verification、Evidence、Reconciliation 和 Project Observatory。

从“能力列表”看，其实已经很多了。

但我拿它真的去写几个项目以后，最明显的问题反而变得很朴素：

> **Agent 明明已经能做这件事了，为什么还要花这么多 Context 和 Tool Call 才开始改代码？**

所以 v0.4 没有再把重点放在“再加一个 Intelligence Tool”。

这一版主要做的是另一件事：**把 Agent 真正写代码的主路径重新压一遍。**

![wcode 最新终端实时面板](https://wcode.francis.run/assets/img.png)

## v0.3 和 v0.4 的差别，不是能力多少

v0.3 我最关心的是“软件状态能不能留下来”。

所以那一版的主线是：

```text
Design State
   ↓
Software Graph
   ↓
Drift / Impact / Risk
   ↓
Verification / Evidence
   ↓
Reconciliation
```

这些东西 v0.4 都还在。

但如果一个 Agent 每次只是改两行代码，也要先完整走一遍 Design、Graph、Traceability、Risk，再查 Symbol、再读文件，那这套系统会越来越像“为了完整而完整”。

我不想让 Intelligence 本身变成新的 Context Tax。

所以 v0.4 的默认 Coding Path 变成了：

```text
agent_context
    ↓
必要时补 symbol_context
    ↓
apply_edits / apply_file_edits
    ↓
review_changes
    ↓
verify_project
```

更深的 Design、Graph、Risk、Reconciliation 还在，但变成按任务需要进入，而不是每次启动都强制付费。

## `agent_context` 成了真正的 Coding Entry Point

这一版我加了一个 Agent Context Compiler。

它不是简单把几个 Tool Result 拼起来，而是尝试一次返回“现在就可以开始修改”的最小上下文。

一个典型结果里会有：

```text
任务相关 Design / Constraint
Direct Target
Exact SHA
Scoped Repo Map
Related Symbol / Test
Working-tree Advisory
Readiness
Next Actions
必要时的 Hot Source
```

我最在意的是最后几个东西。

以前 Agent 经常出现这种链：

```text
project_context
→ search
→ find_symbol
→ read_file
→ 再 search
→ 再 read_file
→ edit
```

每一步都合理，但累计起来 Tool Round-trip 很多，而且每次响应都会重新占一部分 Context。

现在如果任务足够明确，`agent_context` 可以直接把最强目标连同 SHA 和一小段 Hot Source 带回来。

常见的小修改就能变成：

```text
agent_context → edit
```

这对我来说比“又多支持一个 Tool”有意义得多。

## Context Budget 不应该永远是一个固定数字

以前 `software_context` 更像一个固定预算的 Query。

但真实 Coding Task 差别很大。

改一个错误文案和改一个跨 Runtime / MCP / Workspace 的安全问题，不应该拿同样大的上下文。

所以 v0.4 里，`agent_context` 在不显式传 Budget 时会做 Adaptive Budget。

大致思路是：

```text
明确单点任务
  → 小 Context

目标不确定 / 跨模块
  → 给更多 Context

始终有 Hard Bound
```

这个优化看起来不如 Graph 或 Verification “大”，但 Agent 每一次调用都会碰到它。

我现在越来越觉得，做 Agent Runtime 不能只优化模型能不能完成任务，还要开始对**每次完成任务花了多少上下文**负责。

## Repo Map 也不能每次扫完整仓库

Agent Context 里最容易膨胀的是 Repo Map。

如果一句任务已经明确属于 `workspace` Scope，而且目标文件也很直接，再把 Runtime、UI、Graph、Verification 全仓库结构都送进去没有意义。

所以现在 Repo Map 有几层变化：

- Scope-aware；
- Cold Build 时尽量只构造相关区域；
- Structure 按 Revision Cache；
- 每个 Query 只重算 Ranking；
- 多 Query Symbol Search 对一个 Source Root 只扫描一次；
- Fresh Semantic / Runtime Evidence 可以提高相关 Caller / Dependency 排名；
- Semantic Revision 过期以后自动退回 Syntax，不继续拿旧事实指导 Agent。

我还把这些东西做了 Telemetry。

TUI 现在可以看到 Agent Context Calls、平均 Model-visible Token、Repo-map Cache Hit，以及大概省掉了多少 Context。

不是为了做一个漂亮数字，而是我想以后优化时至少知道自己到底有没有真的减少模型负担。

## Project Observatory 终于先讲架构，而不是先讲需求列表

v0.3 的 Project Observatory 已经从“Graph 球图”改成了 Requirement-first。

到 v0.4 我又改了一次。

现在进去先看到的是**整体 Component Architecture**。

原因也很简单：

当我要理解一个陌生项目时，我通常第一句不是：

> 这个 Requirement 现在状态怎么样？

而是：

> 这个项目到底分成哪几块，它们怎么依赖？

所以现在 Observatory 会先把 Design 里声明的 Dependency 和代码里真实观测到的 Relationship 叠在一起。

```text
Design Architecture
        +
Observed Implementation
        ↓
Overlay
```

并且继续保留 Provider / Precision。

这点我没有妥协：Tree-sitter 没看到某个关系，不等于关系不存在；只有真实 Semantic / Runtime / Deterministic Evidence 才能把某些 Observed Drift 升级成更强的判断。

UI 里也不再给一个模糊的“Health Score”，而是拆成可以解释的：

- Observed Drift；
- Evidence Coverage；
- Implementation Coverage。

我更愿意看到几个不完美但能解释的指标，也不想看到一个 87 分却不知道为什么是 87。

## 我还是不想给 Agent 一个 Shell，但开发命令不能太残废

wcode 一直坚持 No-shell Boundary。

但 v0.3 之后我自己使用时也碰到一个现实问题：真正开发不可能永远只有 `cargo test` 和 `git status`。

所以 v0.4 扩了很多 Command Policy，不过方向不是“放开命令”，而是**给具体工具写具体策略**。

Git 现在可以在精确授权后执行：

```text
git add <explicit paths>
git commit -m <message>
git push <remote> <ref>
```

但 Force Push、Delete Ref、Mirror、Reset/Restore 这类形态仍然直接挡掉。

Push 如果被批准，也只允许通过固定的非交互 SSH 方式使用当前 SSH Agent，不会顺手把 Credential Helper 或 HTTPS Token 暴露给模型。

`gh` 也不是整个二进制一次性放开。

PR、Issue、Workflow、Release、Merge、Run 都有自己的 bounded shape；`gh auth`、`gh api`、Secret、Variable、Extension 这些边界仍然封死。

另外补了不少真实开发里常见的 CLI：

```text
fd / jq
cmake / ninja
dotnet / mvn / gradle
swift / zig
pre-commit / act
cargo-nextest
Git LFS
uv / ruff / biome / deno
docker / kubectl / terraform
```

我希望最终状态是：**Agent 能正常开发，但“能正常开发”不等于“给它一个 Terminal”。**

## Tunnel 也不应该因为一个 Provider 挂了就不能用

wcode 最早的 Remote MCP 默认依赖 Cloudflare Quick Tunnel。

它很好用，但单 Provider 依赖太脆。

v0.4 现在的 Auto Path 是：

```text
Cloudflare
   ↓ fail / missing
localhost.run
   ↓ fail
Pinggy
```

后两个直接走 OpenSSH Reverse Forwarding，不需要为了启动 wcode 再自动安装一个 Tunnel Client。

而且拿到 Public URL 还不算成功。

Candidate URL 必须真的访问到**当前这个 wcode Runtime 的 instance-matched `/healthz`**，否则不会被当作可用 Tunnel。

这解决的是一个很现实的问题：

> Remote MCP 的网络入口应该是可恢复的基础设施，而不是“某个第三方命令今天能不能跑”。

## 这次顺手把几个越来越大的文件拆掉了

做性能和 Agent Context 的过程中，有几个文件又开始长得不太舒服：

- `main.rs`；
- `harness.rs`；
- Monitor；
- `command_policy.rs`。

所以 v0.4 也做了一轮责任拆分。

现在 Tunnel、Harness Profile、Agent Context、Repo Map、Monitor State 都已经单独落文件。

发版前最后又把 Command Policy 拆成：

```text
command_policy/
├── git.rs
├── github.rs
├── infrastructure.rs
└── dev_tools.rs
```

我没有为了“模块化”去造新的抽象层，主要目的是别让安全策略继续堆在一个 1500 行文件里。

这类代码最怕两件事：模型每次要读一大坨上下文，以及多人/多 Agent 修改时冲突越来越集中。

## MCP 自己也补了一次异常隔离

发版前我碰到过一次很典型的问题：多个 Tool 突然一起报 `ExceptionGroup: unhandled errors in a TaskGroup`。

受影响的不只是某一个业务 Tool，`workspace_info`、`read_file`、`run_command`、`review_changes` 都会一起失效。

这个现象说明问题已经不是 Tool 业务逻辑，而是请求隔离边界。

v0.4 最后补了一层统一的 Request Task Isolation：

- HTTP 单请求独立 Task；
- stdio 单请求独立 Task；
- Child Panic / Cancellation / JoinError 转成正常 JSON-RPC Error；
- Durable MCP Task Worker 的 Child Failure 也落成 Task Failure；
- 一个 Child 失败以后，后续独立 Tool 仍然可以继续工作。

Release Profile 也不再使用 `panic=abort`，否则“捕获一个 Child Panic 并保持 Session 可用”在 Release Binary 里根本做不到。

这个修复对正常路径没有什么新 UI，但我觉得它很重要：**Tool Failure 应该是一次调用失败，不应该升级成整个 Agent Session 坏掉。**

## v0.4 我会怎么概括

如果 v0.3 是“把软件状态接起来”，v0.4 更像是“让这套状态真正适合每天写代码”。

| | v0.3 | v0.4 |
| --- | --- | --- |
| Coding Entry | 多 Tool 组合 | `agent_context` |
| Context | 固定/通用 | Adaptive + Scope-aware |
| Repo Map | 任务时构建 | Revision Cache + Query Ranking |
| Source Read | 多一步读取 | Direct Match 可带 Hot Source |
| Observatory | Requirement-first | Architecture-first → Requirement Drill-down |
| Command Policy | 基础安全命令 + Selective Approval | Git/GitHub/Dev CLI 的精确 bounded policy |
| Tunnel | Cloudflare 为主 | Cloudflare → localhost.run → Pinggy |
| Runtime Failure | 各路径自行处理 | MCP Request / Child Task Isolation |
| Maintainability | 拆主 Runtime Cluster | 继续拆 Agent Context / Tunnel / Monitor / Command Policy |
| Verification | Full Gate | Full Gate + 文档 EN/ZH parity regression |

发版前最后一次本地 Full Gate 是：

```text
git diff --check                       ✅
cargo check --locked                   ✅
cargo fmt --check                      ✅
cargo test --locked                    ✅ 210 passed
cargo clippy --locked -- -D warnings   ✅
cargo build --release --locked         ✅
```

Design / Traceability 也还是完整的：Requirement → Component、Design → Implementation、Acceptance → Verification 都是 100%。

当然，本地绿色只是发版准备；真正的 Release 还是要以 Tagged Revision 和 CI / Release Artifact 为准。

## 最后

v0.3 的时候我觉得 wcode 真正有意思的地方，是它开始不只关心“代码能不能被 Agent 改”，而是开始关心“软件为什么变成现在这样”。

v0.4 又让我多了一层判断：

> **如果这些 Intelligence 每次都让 Agent 付出很高的上下文和工具往返成本，它最终也不会成为默认工作流。**

所以这一版看起来没有 v0.3 那么像一次产品方向转弯。

但对我自己每天用它写代码的体验来说，变化反而更直接。

现在我希望大部分任务都从一句 Goal 开始，拿到一个足够小但能动手的 Context，然后尽快 Edit、Review、Verify。

复杂任务再把 Graph、Risk、Reconciliation 拉进来。

不是让 Agent 每次都理解整个软件世界，而是让它**在需要的时候，拿到刚好足够可靠的那部分。**

代码：<https://github.com/francis-du/wcode>

文档：<https://wcode.francis.run/>
