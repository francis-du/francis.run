---
title: "wcode v0.6：哪些工具调用可以一起跑"
date: 2026-09-12T05:30:00+08:00
draft: false
url: /blog/wcode-v0-6/
image: /img/wcode/wcode-architecture.png
description: "v0.6 让 agent_context 除了给上下文，也直接给依赖和并行信息，尽量少让模型自己猜哪些工具调用能一起跑。"
tags:
  - wcode
  - Rust
  - MCP
  - AI Agent
  - Parallelism
  - Release
images:
  - /img/wcode/wcode-architecture.png
---

[v0.5](/blog/wcode-v0-5/) 做完 Warm LSP Runtime 以后，我原本打算继续补 Semantic。

实际拿 wcode 连续写了几轮代码，先暴露出来的却是执行节奏：模型已经知道几件事互不依赖，还是经常按顺序一个个调用工具。

例如一个普通修改，前面经常同时存在几条工作：

```text
读目标文件
查相关测试
看项目约束
确认调用方
检查工作树
```

这些动作很多没有依赖关系。如果 Prompt 只写一句“可以并行”，模型仍然很容易串着做。

v0.6 就从这里开始改。我想让 Harness 少给模型一层猜测：当前任务有哪些入口，哪些可以一起做，哪些必须等前一步完成。

![wcode Architecture](/img/wcode/wcode-architecture.png)

## `agent_context` 不再只是一包上下文

最早的 `agent_context` 主要解决 Context 成本。

它把 Design State、Repo Map、目标源码、SHA、验证入口和项目约束压进一个有界包里，让模型不用每次从根目录重新理解一遍。

到了 v0.6，我给这份 Context 又加了一层执行信息：

```text
你现在应该做什么？
哪些动作可以一起做？
哪些动作有真实依赖？
哪些文件已经是可编辑目标？
哪些 Semantic Provider 已经可用？
这次修改应该控制在多大范围？
```

所以 Context 里开始明确带 Minimal-change Strategy、Complexity Budget、Active Worklist、Hot Source、Semantic Provider Readiness、绑定当前 Revision 的文件 SHA、候选 Dependency Lane，以及推荐并发数和立即并行的执行指引。

现在这份 Context 除了描述仓库，也会把这次任务已经确定的执行入口一起带出来。

## Parallel-first 不等于“把槽位占满”

并行最容易做成一个漂亮但没什么用的数字。多发几个 Tool Call 很简单，麻烦的是先确认它们之间到底有没有依赖：

```text
独立 Discovery     ─┐
独立 Read          ─┼─→ 同时开始
独立 Review        ─┤
独立 Check         ─┘

需要前置结果的 Edit ───→ 等依赖满足再开始
同一文件冲突写入     ───→ 串行
授权后才能执行的命令 ───→ 等批准
```

v0.6 的规则很直接：先看依赖，再决定哪些调用一起发。

v0.6 的 Skill 和 Agent 工作流也开始明确要求：Host 支持并行调用时，应该尽早把独立的 Discovery、Read、Review、Check，以及不重叠 Edit 发出去。

## 我不想让模型自己猜仓库结构

以前 Agent 虽然拿到了很多能力，但仍然可能自己脑补：

```text
这个项目大概是 Rust + Web？
这个目录看起来可能是 UI？
这里应该跑 cargo test？
那个 Language Server 应该已经能用了？
```

这种猜测单次看没什么，长任务里会不断累积。

所以 Task-ready Context 会更主动地把已经确定的东西摆出来。目标文件是谁，就把目标文件和 SHA 放前面；当前 Scope 是什么，就把相关源码和 Worklist Lane 放前面；Semantic Provider 还没准备好，就明确说没准备好。

我在 [Software Graph](/blog/wcode-software-graph/) 那篇里写过一次：Tree-sitter、LSP、Runtime 是不同精度的事实。

执行层也照这个规则。Provider 没准备好就明确标出来，不用一个模糊状态让模型自己猜。

## LSP 也开始按真实安全边界工作

v0.5 把 LSP 做成了 Warm Semantic Runtime。

v0.6 又补了一层：Server Discovery、Binary Identity、Bounded Warm Session、Source Revision Sync 和 Safety Profile。

Language Server 不是纯文本查询器。它可能读取项目配置、调用构建系统、加载插件，甚至间接触发仓库里的代码。

所以“机器上装了 rust-analyzer”不等于“Agent 可以无条件启动 rust-analyzer”。如果某个 Server 没有明确的 Automatic Safety Profile，wcode 会 Fail Closed，然后进入精确授权流程。

## 命令授权从“允许/禁止”变成精确指纹

v0.6 还有一块变化，我自己用起来很明显：本地探查命令少打断了，但真正可能执行仓库代码或者产生副作用的命令，也不再只有“永久拒绝”这一条路。

只要没有撞上硬安全边界，就可以生成一次精确的 `RiskyExecution` 请求。

批准绑定的是：

```text
Workspace
Program
Arguments
Working Directory
```

我批准一次 `cargo test --locked`，不代表顺便批准 `cargo publish`，更不代表给 Agent 无限 Full Access。

Shell、Workspace Escape、Protected Path、凭据或配置重定向、Host-wide Tool Mutation、Package Publication / Ownership，以及明显破坏性的基础设施操作，仍然是硬边界。

我最后留下了一段很实用的中间地带：动作本身允许，但这一次要执行的 Workspace、Program、Arguments 和 Working Directory 必须让我看清楚再批。

## 这版主要在收执行摩擦

`parallel`、`context`、`LSP`、`authorization` 这些改动看起来分散，实际都来自我自己使用时反复碰到的几类浪费：模型重复确认已经知道的事实、明明可以并行却串着查、语义服务状态不清楚、命令到了最后一步才发现权限不够。

v0.6 做的就是把这些信息提前放进 Runtime 能确定的位置，尽量少让模型靠 Prompt 猜。

我也不会给 v0.6 编一个“通用提速百分比”。真实收益取决于任务图、仓库、Host 是否支持并行调用，以及 Semantic Session 是否已经热起来。

后面的 v0.6.1，我又继续把 `parallel_tools` 调度器改了一轮。那次处理的是另一个更底层的问题：**并行任务不应该因为同一层里有一个慢分支，就集体等它。**
