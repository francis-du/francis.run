---
title: "wcode v0.3：从本地代码桥到 Software Intelligence Runtime"
date: 2026-08-26T23:30:00+08:00
draft: false
url: /blog/wcode-v0-3/
image: /img/wcode/wcode-tui.png
description: "v0.2 还是一个轻量的 Remote MCP 代码桥，v0.3 开始把 Design State、Software Graph、Risk、Verification、Evidence 和 Reconciliation 接成一套真正的软件控制面。"
tags:
  - wcode
  - Rust
  - MCP
  - Release
images:
  - /img/wcode/wcode-tui.png
---

wcode 的 v0.3 是一次比较明显的方向变化。

v0.2 发布时，我给它的定位还很简单：**一个轻量的 Code Agent plugin，把你已经在用的 AI Client 接到本地仓库。**

这个定位没有消失。Remote MCP、OAuth、Workspace、Tree-sitter、代码读写、Git Review 和 Verification 这些底层能力都还在。

但如果只看 v0.3 的代码和界面，它已经不太像一个“桥”了。

我现在更愿意把它叫做：

> **Software Intelligence Runtime for AI-native development.**

模型仍然负责写代码，wcode 开始负责另一件更难长期维护的事：软件到底应该是什么、现在是什么、哪里变了、风险在哪里、什么证据说明这次修改真的完成了。

![wcode 终端实时面板](/img/wcode/wcode-tui.png)

## v0.2 当时解决了什么

我重新看了一遍 `v0.2` Tag 里的 README。

当时的主线非常明确：

```text
AI Client
   │
   │ Remote MCP + OAuth
   ▼
wcode
   │
   ├─ search
   ├─ symbols
   ├─ read / edit
   ├─ project context
   ├─ git review
   └─ verification
   │
   ▼
configured workspace roots
```

一句话就是：**不要再造一个 Agent，把本地代码能力安全地提供给现有 Agent。**

v0.2 已经有不少我现在仍然很看重的基础：

- 一个 Rust 原生二进制；
- Remote MCP + OAuth 2.1 / PKCE；
- Cloudflare Quick Tunnel；
- 多客户端接入；
- Workspace Root 隔离；
- Tree-sitter Symbol Navigation；
- SHA-256 Guarded Edit；
- Git-aware Review；
- 有界并发和实时 TUI。

但它回答的主要还是：

> 模型怎么安全地碰本地代码？

v0.3 想回答的问题已经变成：

> 多个模型、人和工具不断修改一个项目以后，怎么还知道这个软件为什么是现在这样？

## 最大变化：Design State 进入了开发闭环

v0.3 里最重要的东西不是某个新 Tool，而是 `.wcode` Design State。

它把长期应该稳定存在的意图放进仓库：

```text
Requirement
Component
Constraint
Acceptance Criterion
Decision
```

这些东西不是 Markdown 里的描述，而是带稳定 ID 和关系的结构化 Desired State。

于是一个功能可以真的形成链路：

```text
Requirement
    ↓
Component responsibility
    ↓
File / Symbol
    ↓
Acceptance Criterion
    ↓
Test / Verification
```

这也是为什么 v0.3 之后，wcode 不再只是给模型提供 `read_file` / `apply_edits`。

Agent 可以先从需求和设计开始理解，再落到代码。

## Product Scope 把大仓库重新分区

只做 Design State 还不够。

仓库一大，Agent 还是很容易把整个项目看成一个平面目录。

所以 v0.3 有了 canonical Product Scope Registry：

```text
runtime
integrations
workspace
design
graph
semantics
traceability
risk
verification
evidence
reconciliation
experience
```

它同时参与源码架构分类、`scope_status`、`software_context`、MCP Tool Metadata 和 Agent Workflow。

我现在给 Agent 一个任务时，可以先确定它属于哪个 Product Scope，再缩小上下文。

这比“先 grep 全仓库再说”稳定很多。

## Software Graph 不再只是一个索引

Tree-sitter 仍然是 always-on 的语法底座，但 v0.3 把 Graph 扩成了可以混合多种 Provenance 的 Software Digital Twin。

基础事实仍明确标注：

```text
provider = tree-sitter
precision = syntax
```

如果真实 Language Server 返回 Document Symbol、Call Hierarchy 或 Implementation，才会进入 semantic precision。

外部 SCIP / Compiler / Runtime Provider 也可以进入同一张 Graph，但每条关系都保留自己的 Provider、Precision 和 Revision。

Graph 现在还会保留 meaningful revision history，可以看节点和关系到底怎么变，而不是只看当前快照。

## v0.3 的主界面不是 Graph 球图

我做过一版能拖、能缩放的 Graph Canvas。

后来删掉主视图了。

不是 Graph 没用了，而是“看一团节点”不是我真正想解决的问题。

现在 WebUI 是 requirement-first 的 **Project Observatory**：

```text
Desired State
    ↓
Actual State
    ↓
Change
    ↓
Proof
    ↓
Convergence
```

一个 Requirement 下面可以直接看到：

- 功能意图；
- Component 责任和声明依赖；
- 当前真实实现；
- Acceptance / Verification；
- Constraint / ADR；
- 当前 Git Change；
- Evidence；
- Convergence Blocker；
- Graph Revision。

TUI 按 `W` 会直接打开当前焦点 Workspace 的 Project Observatory。

## Verification 从“跑过测试”变成 Evidence

v0.2 已经有 `verify_project`。

v0.3 里 Verification 的变化，不是多跑几个命令，而是**结果开始有身份和 Revision**。

现在可以记录：

```text
谁产生的 Evidence
针对哪个 Code Revision
针对哪个 Design Revision
使用什么 Policy
结果是 Pass / Fail / Disagree / Inconclusive
```

Property、Mutation、Fuzz、Runtime Canary、Blind Reviewer 和 Human Approval 也进入同一套 Verification Mesh。

最重要的是：新的 Pass 不会把另一个 Producer 的 Fail 擦掉。

分歧就是 Evidence，而不是需要被 UI 平均掉的噪音。

## Reconciliation 把“一次聊天”变成可继续的状态

v0.2 的典型开发闭环更像：

```text
read → edit → test → done
```

v0.3 开始把“什么时候真的算 done”做成显式状态。

Reconciliation Plan 会把 Drift、Impact、Risk、Implementation 和 Verification Requirement 组织成有依赖的任务。

这些任务可以 Claim、Submit、Retry，并且持久化。

所以一个模型写代码、另一个模型 Review、第三个模型补测试，不需要共享同一个聊天上下文。

它们面对的是同一个软件状态和同一组 Evidence。

## Workspace 权限也比 v0.2 更细

v0.2 的安全模型已经强调：不给模型一个 Shell。

v0.3 继续保留这个原则，但授权粒度细了很多。

现在模型如果请求一个还没有授权的裸可执行程序，例如：

```text
hugo
flutter
deno
mvn
gradle
```

wcode 不会因为它不在默认列表里直接永久拒绝，而是生成一个当前 Workspace 的 `CommandAccess` Pending Request。

TUI 会显示待授权列表：

```text
↑/↓ 选择
Y    批准当前请求
N    拒绝当前请求
```

Project Observatory 的 Access Panel 也能处理同一批 Pending Request，并管理 Workspace 和已授权命令。

批准的是**这个 Workspace 的这个 Program**，不是开放一个 Shell。

`bash`、`sh`、`pwsh`、`cmd` 这类 Shell Interpreter，以及带路径的 Program Name，仍然是硬边界。

Repository-aware Argument 还可能再触发单独的 `RiskyExecution` 授权。

删除则仍然更严格：exact one-shot。

## 并发和写入也做了实际性能优化

v0.2 已经支持有界并发，但 v0.3 的 Scheduler 已经可以理解 Read / Write / Create / Move / Delete 的路径冲突。

当前默认全局并行度调整成：

```text
logical CPU × 12
clamp 96..192
hard max 256
```

同一个文件的多个 `apply_edits` 如果 SHA 相同、Range 不冲突，可以先合并再提交。

另外这次还专门处理了我在真实项目里感觉到的“写代码还是慢”：

- 交互式小文件写入保留同目录临时文件 + atomic replace，但不再每次都强制 data fsync + directory fsync；
- `project_context` 的 Convention Scan 和 Language Quality Scan 并行执行；
- `search_code/search_many` 改成目录遍历过程中直接进入并行搜索，不再先收集完整文件列表；
- 多 Edit 共享一次 Line Index；
- `read_file` 不再先给整个文件分配一份 Line Vector；
- Project Context 会明确让 Agent 优先用 `apply_file_edits` / `create_files` 做批量写入。

安全边界没有因为这些优化被拿掉：SHA、Atomic Replace、Path Isolation、Symlink / Hardlink、Protected Path 仍然存在。

## v0.2 → v0.3，我会怎么概括

如果只留一张表，大概是这样：

| | v0.2 | v0.3 |
| --- | --- | --- |
| 产品中心 | Local Code Bridge | Software Intelligence Runtime |
| 模型关系 | 给现有 Agent 本地工具 | 模型是可替换 Builder / Reviewer |
| Desired State | 无 | Design State |
| 源码边界 | Workspace | Workspace + Product Scope |
| Code Intelligence | Tree-sitter Symbol | Composite Software Graph + Provider Provenance |
| 改动理解 | Git Review | Drift + Impact + Risk |
| 验证 | Project-native checks | Verification Mesh + Revision-exact Evidence |
| 长任务 | 普通 Tool Call | MCP 2026 Durable Tasks |
| 完成状态 | 一次调用结束 | Reconciliation / Convergence |
| UI | TUI + Setup Hub | TUI + Setup Hub + Project Observatory |
| 授权 | 粗粒度 Trust Flag | Pending Request + TUI/WebUI selective approval |

v0.2 解决的是“把 AI 接进来”。

v0.3 更像是在回答：“接进来以后，怎么让这个项目长期不失控。”

我现在觉得这才是 wcode 真正有意思的方向。

相关实现细节可以继续看 [wcode 最近做成什么样了](/blog/wcode-2026/)、[Design State](/blog/wcode-design-state/)、[Verification](/blog/wcode-verification/) 和 [Security](/blog/wcode-security/)。
