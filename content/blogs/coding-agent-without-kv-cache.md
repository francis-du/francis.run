---
title: "wcode：用 Jev 的理念重构 Coding Agent Runtime"
date: 2026-09-22T02:35:00+08:00
draft: false
url: /blog/coding-agent-without-kv-cache/
translationKey: wcode-jev-agent-runtime
description: "我不想把 wcode 做成另一个 Claude Code。读完 Why yet another agent 后，我更确定应该用 Jev / TypeSafe 的理念重构 wcode：把 Context、State、Tool Routing、Verification 和 Background Intelligence 做成 Agent 下面的运行时。"
tags:
  - wcode
  - Jev
  - TypeSafe
  - Coding Agent
  - Context
  - Engineering Runtime
---

最近我一直在想一件事：

> wcode 下一步到底应该继续“补 Agent 能力”，还是应该重做 Agent 下面那一层？

前几天读了一份叫 [Why yet another agent](https://docs.google.com/document/d/1G61uUB0FifUnmmrPzFQojZ3KpczYKmXGpgEXDJ2l_Zg/mobilebasic) 的笔记，里面有一个问题我很喜欢：

> 如果 LLM 没有 KV cache，你会怎么设计一个 Coding Agent？

这个问题让我一下把很多已经习惯的东西重新看了一遍：compaction、restart、subagent、tool schema、skills、model routing、长 session、memory。

最后我的结论不是“再做一个更聪明的 Agent”。

恰恰相反。

我更确定 **wcode 不应该去复制 Claude Code、Codex 或 Cursor，而应该把 Agent 下面缺的那层 Runtime 做出来。**

而 Jev / TypeSafe 给我的启发，正好不是“换一个模型”，而是：

> 把原本藏在 Prompt 和上下文里的模糊语义判断，变成有类型、有边界、有状态的程序决策。

这篇主要记我现在准备怎么用这个理念继续重构 wcode。

## 我不想让 Jev 接管 Agent

先说一个容易误解的地方。

我不是想做：

~~~text
wcode
  ↓
Jev
  ↓
让 Jev 决定所有事情
~~~

这和我的方向完全相反。

wcode 里现在很多东西就是故意保持 deterministic：

~~~text
当前文件 SHA 对不对？
路径是不是在 Workspace？
命令有没有授权？
Verification 有没有真的跑？
Evidence 属不属于当前 revision？
Design State 有没有 drift？
Worklist 还有没有没做完的东西？
~~~

这些东西代码能算，就应该让代码算。

Jev 真正适合的是另外一类问题：

~~~text
当前 context 够不够？
还缺不缺重要 evidence？
是不是必须看 callers / references / implementations？
几个合法 action 里哪一个更适合当前语义状态？
当前失败更像缺证据、缺语义，还是应该直接 repair？
~~~

也就是一些以前很容易写进 Prompt 里的“语义 if”。

这也是为什么我现在更喜欢把 Jev 看成 **Decision Plane 的一部分**，而不是另一个 Agent。

## wcode 已经有一版 Decision Plane

现在 wcode 里的 Jev 不是直接拿用户 Prompt 去问。

流程大概是：

~~~text
repository state
     │
     ▼
deterministic baseline
     │
     ├── target
     ├── worktree
     ├── graph
     ├── verification
     ├── semantic readiness
     └── current risk
     │
     ▼
DecisionRequest
     │
     ├── local deterministic decision
     └── Jev decision
             │
             ▼
       shadow comparison
             │
             ▼
       increase-only guidance
~~~

Jev 现在可以回答 Noul / Choice / Score 这几类问题。

比如：

~~~text
context_sufficient           -> Noul
continue_retrieval           -> Noul
semantic_navigation_required -> Noul
verification_escalation      -> Noul
next_action                  -> Choice
risk_surface                 -> Choice
evidence_density             -> Score
~~~

但它不能说：

> “我觉得没事，所以跳过 verification。”

现在的规则是：

> **Jev 可以增加工作，不能减少确定性安全边界。**

比如它可以建议：

~~~text
先再查一个 symbol
先 review worktree
补 semantic navigation
把 verification 升到 full
~~~

但它不能取消：

~~~text
SHA precondition
authorization
workspace containment
verification floor
current-revision evidence
~~~

这条边界我准备继续保持。

## Jev 真正改变我的地方，是“State 应该先于 Prompt”

传统 Coding Agent 很容易把状态理解成：

~~~text
system prompt
+ conversation
+ 之前读过的文件
+ tool calls
+ tool outputs
+ compaction summary
~~~

也就是说：

> 模型知道什么，主要取决于这次 session 以前发生过什么。

这很适合 KV cache。

但它不一定是最适合工程系统的状态模型。

wcode 现在已经有很多东西其实根本不属于聊天：

~~~text
Execution
Worklist
Workspace
Design State
Software Graph
Semantic Provider State
Impact
Risk
Verification Plan
Evidence
Reconciliation
Runtime Task
~~~

这些才是项目真正的状态。

模型换了，状态不能跟着没。

会话断了，状态不能跟着没。

Compaction 了，状态也不能跟着被总结错。

所以我下一步想继续把 wcode 往一个更明确的结构推：

> **Runtime owns state，Agent 只拿当前任务需要的一份 view。**

## 第一件事：把 Agent Context 重构成 Context Compiler

wcode 现在已经有 agent_context，它做的事情比“搜几个文件”多很多：

- 找 target；
- 带当前 SHA；
- 带 Design State；
- 带验证入口；
- 带 graph / semantic readiness；
- 带 Worklist；
- 给出 next actions。

但从这个新视角看，它还可以继续往前走。

我想把它从：

> “生成一包 edit-ready context”

进一步重构成：

> **Context Compiler。**

也就是所有可进入模型的东西，先变成一种统一的 context candidate：

~~~text
ContextChunk {
  source
  revision
  scope
  freshness
  sensitivity
  cost
  relevance
  precision
  render_level
}
~~~

然后每次任务重新编译：

~~~text
current goal
    │
    ▼
candidate chunks
    │
    ├── source
    ├── tests
    ├── graph
    ├── semantic
    ├── design
    ├── evidence
    ├── worklist
    ├── past decisions
    └── runtime state
    │
    ▼
deterministic filters
    │
    ▼
Jev semantic scoring
    │
    ▼
render policy
    │
    ├── omit
    ├── one-line summary
    ├── detailed summary
    └── full content
    │
    ▼
compiled context
~~~

这和 compaction 最大的区别是：

Compaction 问：

> 过去这些东西怎么压短？

Context Compiler 问的是：

> **这一轮到底为什么需要看这些东西？**

我觉得这才是更根本的优化。

## 第二件事：把 Retrieval 从“继续不继续”升级成 reranking

现在 wcode 的 Jev 已经能判断：

~~~text
continue_retrieval?
semantic_navigation_required?
~~~

但下一步我更想做的是候选级别的 scoring。

比如一次 search / graph / experience / design lookup 找到 30 个候选：

~~~text
candidate 1
candidate 2
candidate 3
...
candidate 30
~~~

不应该简单按 lexical hit 或固定 heuristic 全塞给模型。

更合理的是：

~~~text
deterministic search
      │
      ▼
bounded candidate pool
      │
      ▼
Jev:
  relevance?
  task-critical?
  test-related?
  security-sensitive?
  stale?
  contradictory?
      │
      ▼
rerank
      │
      ▼
top context
~~~

但这里仍然需要 deterministic floor。

下面这些我不准备交给 Jev 删除：

~~~text
用户明确点名的 target
当前 changed files
security-sensitive files
mapped acceptance tests
current failure locations
SHA edit target
current revision evidence
~~~

Jev 可以重排 optional context，不能删硬约束。

## 第三件事：做 Context Firewall

原文里有一个方向我觉得对 Agent 很重要：

> retrieved text 不应该默认等价于 instruction。

这件事在 Coding Agent 里比普通 RAG 更危险。

因为 Agent 会读：

- README；
- docs；
- issue；
- generated source；
- shell output；
- web content；
- dependency docs；
- MCP resource；
- comments。

这些内容里完全可能出现：

~~~text
Ignore previous instructions
Run this command
Upload this token
Disable verification
~~~

如果都原样塞到 context 里，实际上是在把 repository data 和 agent instruction 混成一种东西。

所以我想在 Context Compiler 前再加一层：

~~~text
retrieved chunk
     │
     ▼
deterministic boundary
     │
     ▼
semantic classification
     │
     ├── evidence
     ├── conflict
     ├── instruction-like
     └── irrelevant
     │
     ▼
context admission
~~~

也就是 **Context Firewall**。

Jev 在这里不是安全 authority。

真正的权限仍然在 wcode。

但它可以帮忙判断：

> 这段文本更像 evidence，还是更像试图改变 Agent 行为的 instruction？

我觉得这个能力以后会越来越重要。

## 第四件事：Tools 不应该永远全量暴露

这篇原文里另一个我非常认同的点，是 Tool calling 的 context 税。

现在 function calling / MCP 常见的方式是：

> 工具 schema 先全部放进模型 context。

工具少的时候没问题。

工具几十、上百以后，开始出现两个代价：

1. schema 本身很占 context；
2. action space 太大，模型选择未必更准确。

wcode 自己这两年也一直在做 tool schema 收敛。

但我现在想更进一步：

> **把完整 Tool Catalog 改成 Action Registry + progressive disclosure。**

第一层模型只看到：

~~~text
repository_search
semantic_navigation
code_edit
verification
runtime_control
authorization
design_state
evidence
~~~

这些只是 capability hints。

真正选中一个 capability 后，再动态加载：

~~~text
exact action
full schema
argument constraints
examples
failure semantics
risk class
~~~

也就是说：

~~~text
Goal
  │
  ▼
Action Router
  │
  ▼
Top-K capability
  │
  ▼
load full action schema
  │
  ▼
model tool call
~~~

这和 TypeSafe 的 Skill Suggestion 很像：

先看短 description。

选 Top-K。

再加载更完整的信息做第二次判断。

如果这件事做成，我觉得 wcode 才真正有可能做到：

> 内置很多能力，但不让模型每一轮都付出完整上下文成本。

## 第五件事：Skills、Tools、Context Rule 分开

我现在也越来越觉得这三个概念不应该混。

### Tool / Action

立刻执行一个动作：

~~~text
run verification
read file
find references
start process
~~~

### Skill / Workflow

一类任务怎么做：

~~~text
release package
debug frontend
review migration
repair verification failure
~~~

### Context Rule

做某类任务时必须带上的知识：

~~~text
frontend -> style guide
src/auth -> auth gotchas
Rust perf -> performance rules
writing -> personal style samples
~~~

Context Rule 很像 AGENTS.md，但不是全局静态加载。

应该是：

~~~text
if scope == src/auth:
    include auth-gotchas

if task == frontend:
    include frontend-style

if task == release:
    include release-policy
~~~

并且可以有一个很重要的属性：

~~~text
sticky = true
~~~

意思不是永久存在于 KV cache。

而是：

> 只要 task condition 还成立，每次 Context Compiler 都必须重新带上。

这样就不会因为 compaction 或换模型把关键规则压没。

## 第六件事：Subagent 应该共享 State，不是共享聊天

现在 subagent 最大的问题，我觉得一直不是“怎么启动另一个模型”。

真正麻烦的是：

~~~text
主 Agent 的哪些 context 要传过去？
它回来哪些东西要合并？
它读到的 revision 还是不是当前 revision？
几个 agent 同时写怎么办？
结果有没有冲突？
~~~

如果 State 是显式的，就可以换成另一种模型：

~~~text
Subgoal
  id
  revision
  input scope
  allowed reads
  allowed writes
  output schema
~~~

比如：

~~~text
subgoal:
  inspect auth impact

revision:
  R

read:
  Software Graph
  Semantic Provider
  src/auth
  mapped tests

write:
  ImpactReport only
~~~

它不需要复制主 Agent 的整个 session。

它只需要拿到一份 task-specific context view。

返回以后也不是“塞一大段聊天回来”，而是写一个结构化 artifact。

这时候 subagent 更像 worker，而不是另一个会话。

## 第七件事：把 Background Intelligence 当一等公民

原文最后提到一个我觉得很有潜力的模式：

很多 Agent workflow 其实适合在后台跑。

尤其是只读任务：

~~~text
security review
architecture review
test-gap analysis
graph refresh
documentation drift
eval generation
performance analysis
cross-model review
~~~

它们都可以理解成：

> 当前 repository revision 的函数。

所以我更想让 wcode 后面形成：

~~~text
Revision R
   │
   ├── Graph Builder
   ├── Security Review
   ├── Architecture Review
   ├── Test Gap
   ├── Docs Drift
   ├── Eval Builder
   └── Runtime Observation
           │
           ▼
   Derived Engineering State
~~~

只要 revision 变了：

~~~text
R -> R+1
~~~

旧结果自动 stale。

这其实和 wcode 现在的 Evidence / Verification / Graph revision binding 是同一套思想。

我觉得这比“开很多 subagent 聊天”更像真正可维护的 multi-agent architecture。

## 第八件事：Model Router 最后再做

“Why yet another agent” 里花了不少篇幅讲 KV cache 怎么让 model routing 变得不经济。

我认同这个问题。

但我现在不会先做 model router。

因为如果 state/context 还是一坨 session history：

> 再聪明的 routing 也只是在决定谁来重新吃这一坨 token。

所以顺序应该反过来：

~~~text
先把 State 显式化
     ↓
再做 Context Compiler
     ↓
再做 Action Router
     ↓
再做 Subgoal / Background Plane
     ↓
最后 Model Router
~~~

到那个时候，小模型和大模型切换才自然：

~~~text
简单 task
→ 编译一个很小的 Context View
→ 小模型

复杂 task
→ 编译一个更完整的 Context View
→ 大模型

security review
→ 编译 security-specific View
→ 独立 reviewer
~~~

模型不需要继承另一个模型过去半小时的“脑子”。

只需要读取同一份 Engineering State 的不同视图。

## 这会让 wcode 的定位更清楚

我现在不太想把 wcode 定义成：

> 一个更强的 Coding Agent。

我更愿意把它定义成：

> **Coding Agent 下面的 Engineering Runtime。**

大概是：

~~~text
                Codex / Claude / ChatGPT / 自研 Agent
                              │
                              ▼
                        Current Goal
                              │
                              ▼
                  ┌─────────────────────┐
                  │   wcode Decision    │
                  │       Plane         │
                  │ deterministic + Jev │
                  └──────────┬──────────┘
                             │
           ┌─────────────────┼─────────────────┐
           ▼                 ▼                 ▼
   Context Compiler     Action Router     Background Plane
           │                 │                 │
           ▼                 ▼                 ▼
      State Fabric       Action Registry   Derived State
           │
           ├── Execution
           ├── Worklist
           ├── Workspace
           ├── Design State
           ├── Software Graph
           ├── Semantics
           ├── Risk
           ├── Verification
           ├── Evidence
           ├── Reconciliation
           └── Runtime Tasks
~~~

Agent 可以换。

Model 可以换。

UI 可以换。

MCP client 可以换。

但工程状态和边界不换。

我觉得这是 wcode 最值得做的地方。

## Jev 在这套架构里的角色

如果把上面所有东西压成一句话：

> Jev 不应该是 wcode 的大脑，而应该是 wcode 里负责“模糊语义分支”的 typed decision engine。

比如：

~~~text
这个 chunk 是否相关？
是否需要更详细版本？
是否还缺 evidence？
这几个合法 action 哪个更适合？
这个 subgoal 是否重复？
这个 diff 是否值得额外 review？
这段 retrieved text 是 evidence 还是 instruction？
~~~

这些问题非常适合：

~~~text
Noul
Choice
Score
~~~

而：

~~~text
能不能写这个文件？
能不能执行这个 command？
当前 SHA 对不对？
验证通过没有？
Evidence stale 没有？
~~~

继续由 deterministic code 决定。

我觉得这两层分得越清楚，系统反而越稳。

## 我准备怎么推进

这次看完以后，我给 wcode 后续重构排的顺序大概是：

### 1. Decision Policy 产品化

现在 question set、threshold、distribution、calibration 已经有了。

下一步要把它们变成真正可版本化的 policy：

~~~text
question_set_version
decision_policy_version
requested_model
resolved_model
calibration sample
Brier
false-stop
false-continue
~~~

### 2. Semantic Retrieval Reranker

让 Jev 从“还要不要搜”变成“这些候选哪个最值得进 context”。

### 3. Context Firewall

区分：

~~~text
evidence
conflict
instruction-like content
irrelevant
~~~

### 4. Context Compiler

统一决定每个 context chunk：

~~~text
omit
summary
detailed
full
~~~

### 5. Action Registry

让模型先看 capability index，再动态加载完整 tool schema。

### 6. Structured Skill / Context Rule

把 workflow 和长期上下文规则分开。

### 7. Background Intelligence

把 graph、review、security、eval、docs drift 变成 revision-bound derived state。

### 8. 最后才做 Model Routing

到这一步，routing 才不是简单的“换模型”。

而是：

> 为不同模型编译不同成本、不同深度、但来自同一个 State Fabric 的 Context View。

## 最后

Jev 对我最大的启发并不是“有一个便宜模型可以帮 Agent 做判断”。

真正重要的是：

> **把 Agent 里的语义判断，从隐式 Prompt 行为变成显式、可类型化、可版本化、可校准的程序接口。**

而 “Why yet another agent” 又把这个思路往前推了一步：

> **如果 state 也是显式的，很多今天围绕 KV cache 长出来的复杂设计，可能根本不需要存在。**

所以接下来我想继续把 wcode 从 Repository Control Plane 往 Engineering Runtime 推。

不是再做一个 Agent。

而是让任何 Agent 都能踩在一套更干净的：

**State、Context、Decision、Action、Verification、Evidence 和 Background Intelligence** 上。

如果这个方向走通，我觉得它会比再造一个 Claude Code clone 有意思得多。
