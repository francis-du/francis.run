---
title: "wcode：重做 Coding Agent 下面那一层"
date: 2026-09-22T02:35:00+08:00
draft: false
url: /blog/coding-agent-without-kv-cache/
description: "读完 Why yet another agent 后，我更确定 wcode 不应该去复制 Claude Code，而应该重做 Coding Agent 下面那一层：State、Context、Action、Verification 和 Background Intelligence。"
tags:
  - Coding Agent
  - KV Cache
  - Context
  - TypeSafe
  - Jev
  - wcode
---

最近我在继续想 wcode 下一步到底应该往哪里长。

看了一份叫 [Why yet another agent](https://docs.google.com/document/d/1G61uUB0FifUnmmrPzFQojZ3KpczYKmXGpgEXDJ2l_Zg/mobilebasic) 的笔记以后，这件事反而更清楚了：**wcode 不应该去复制 Claude Code、Codex 或另一个 Coding Agent，而应该继续往它们下面那一层走。**

里面有个问题我很喜欢：

> 如果 LLM 完全没有 KV cache，你会怎么设计一个 Coding Agent？

这个问题看起来像在讨论推理性能，实际一下把很多现在已经习以为常的 Agent 设计掀开了。

我之前一直觉得，Coding Agent 真正复杂的地方不是那个 while loop。模型看任务、选工具、执行、读结果、继续，这层其实出奇地简单。真正越来越重的是围绕它长出来的上下文管理、工具定义、权限、subagent、compaction、restart、memory 和各种恢复机制。

这些东西当然都有现实价值。

但看完这份笔记以后，我开始怀疑：这里面有多少是在解决 Agent 本身的问题，又有多少只是在解决 **“我们必须尽量复用一份越来越大的 KV cache”** 这个问题。

所以这篇不是想重新发明一个 Agent，而是想回答一个更具体的问题：**如果把 KV cache 这个历史前提拿掉，wcode 应该为 Coding Agent 提供什么样的底层运行时？**

## Coding Agent 本身可能真的没那么复杂

先把 Agent 的外壳去掉，最小实现大概就是：

~~~text
while not done:
    context = current_state()
    response = model(context, tools)
    execute(response.tool_calls)
~~~

真正决定体验的东西不在 while，而在三个问题：

1. current_state() 到底是什么；
2. 当前这一轮模型到底能看见哪些 actions；
3. 执行完以后，什么状态应该保留下来。

现在大部分 Coding Agent 对第一个问题的默认答案，其实是：

~~~text
system prompt
+ conversation
+ files read before
+ tool calls
+ tool outputs
+ summaries
+ subagent results
+ maybe memory
~~~

然后尽可能复用上一轮已经算好的 KV cache。

这很合理，也很划算。

但它同时把很多架构决策偷偷固定住了。

## KV cache 让 model routing 变得很奇怪

原文里先算了一笔旧模型价格下的账。

假设有大模型 Opus 和便宜一点的 Sonnet。直觉上，一个简单阶段先给 Sonnet，复杂阶段再切回 Opus，应该更便宜。

问题是切回来以后，Opus 要重新吃一遍 Sonnet 期间积累的上下文。

原文用一个简化公式表示：

~~~text
Pure Opus:
25Y + 5Z

Opus -> Sonnet -> Opus:
3X + 20Y + 8Z
~~~

这里：

- X 是已有 context；
- Y 是模型生成内容；
- Z 是生成过程中新增的工具/文件等上下文。

在它举的那组比例里，第二条路径反而更贵。

这个例子里的价格当然会变，具体比例也不是重点。

重点是：

> **现在的 routing 不只是“哪一步用哪个模型”，而是“切模型以后谁来重新支付状态加载成本”。**

所以一个非常自然的系统设计——把简单任务交给便宜模型——在长 session 里可能因为 context replay 变得不自然。

这也是为什么我现在觉得，真正需要一等公民化的不是 model router，而是 **state/context 本身**。

## Tool calling 也在交 context 税

现在 MCP / function calling 的典型做法，是模型开始这一轮之前就看见完整工具定义。

工具不多时没什么问题。

几十个以后就开始别扭：

~~~text
tool name
description
JSON schema
arguments
enum
nested object
...
~~~

很多工具这一轮根本不会用，但 schema 还是进了 context。

更麻烦的是，工具数量越多，模型不一定越聪明。

高 cardinality 的 action space，加上很多模型训练时没见过的自定义工具，本身就会让选择变难。

这也是为什么 Skills 经常比 Tool 更顺手：Skill 的短描述比较像一种方向提示，而 Tool schema 更像执行阶段才需要的精确定义。

我现在越来越觉得中间应该有一层：

~~~text
Agent 只先知道：

- semantic navigation
- repository search
- verification
- runtime control
- browser
- deploy
- database inspection

真正决定要用某类能力以后
才加载具体 action 和完整 schema
~~~

不是把所有东西永久塞在 system prompt 里。

如果这层做得好，理论上一个 Agent 有几百个 tool、几千份 docs，并不意味着每一轮都要为它们交 context 成本。

## Compaction 可能是在压错东西

Compaction 的逻辑也很好理解。

上下文越来越长，于是把前面的 conversation 压成 summary，再接着跑。

但这里其实隐含了一个很强的假设：

> **未来所有请求都需要同一份“共享摘要状态”。**

这不一定成立。

假设刚才做了一个 OAuth 修复，context 里有：

- callback；
- token；
- origin；
- tests；
- logs；
- design；
- reviewer feedback。

下一条用户消息突然变成：

> 帮我改博客首页字体。

这时候最好的压缩算法不是“把 OAuth 那一大坨压得特别好”。

而是：

> 大部分根本不用加载。

一旦知道当前 query 是什么，compression 会简单很多。

所以比 global compaction 更自然的东西可能是：

**query-aware context construction。**

## 我更喜欢把它叫 Context Compiler

原文里用了一个词：**Meta-attention**。

我觉得这个词挺准确。

不是只让 Transformer 在已经塞进去的 token 上做 attention，而是在进模型之前，系统自己先决定这一轮“什么值得被 attention”。

比如仓库里现在有 500 个 context chunks：

~~~text
用户历史
源文件
测试
tool output
编译日志
Design State
Git diff
Graph
LSP
AGENTS.md
以前的 Evidence
以前的 reviewer 结论
...
~~~

每一个 chunk 都可以先有一个 rendering level：

~~~text
0 = 不加载
1 = 一行摘要
2 = 较长摘要
3 = 原文
~~~

于是每一轮真正发生的是：

~~~text
query
  │
  ▼
candidate state
  │
  ▼
relevance / risk / freshness / cost
  │
  ▼
render level
  │
  ▼
compiled context
  │
  ▼
model
~~~

这和 compaction 是完全不同的思路。

Compaction 是：

> “这段历史怎么压短？”

Context Compiler 问的是：

> “这一轮为什么要看这段历史？”

对我来说，这是这份笔记最重要的一点。

## 状态如果显式，很多奇怪机制都会变简单

现在主流 Agent 很多状态其实藏在 transcript 里。

“模型知道什么”，很大程度等于“它前面读过什么”。

这会带来几个问题。

### Subagent 为什么一直有点别扭

派一个 subagent 本身并不难。

真正难的是：

~~~text
主 Agent 的哪些 context 要复制过去？
subagent 自己新读了什么？
结果回来以后要保留哪一段？
要不要把它的 reasoning / tool output merge 回去？
多个 subagent 同时改状态怎么办？
~~~

所以很多 subagent 最后还是表现成：

> 主 Agent 给一大段 prompt → subagent 干活 → 返回一大段文字。

如果状态是显式的，它可以更像：

~~~text
Subgoal:
find callers affected by API change

Input:
revision R
symbol X

Allowed reads:
graph
semantic provider
source

Output:
ImpactReport

No repository writes
~~~

它读的是共享 state，不需要复制主聊天。

返回的也是一个结构化结果，不需要把自己的 session 拼回主 session。

我觉得这才是 subagent 真正应该长成的样子。

### Restart 也没那么特殊了

现在长 session 用坏了，经常有一种解决办法：

> restart。

换个新 session，把当前问题重新讲一下。

本质上是在清掉被污染的 implicit state。

如果仓库状态、任务状态、验证证据、当前 goal、本轮 relevant history 都可以按需重新构造，那么“新 session”就不应该意味着“重新从零理解项目”。

它只是：

> 新建一个 model context，然后重新 compile 当前需要的 state。

这两个概念区别很大。

## Skills、AGENTS.md 和 Tools 其实混了三种东西

现在这几个东西经常被揉在一起。

但我觉得可以拆开：

### Action

现在就要执行的能力：

~~~text
run test
rename symbol
search references
deploy
~~~

### Skill

完成一类任务的工作流：

~~~text
release package
debug frontend
review migration
~~~

### Conditional Context

这一类任务里应该一直知道的规则：

~~~text
frontend -> style guide
src/auth -> auth gotchas
Rust perf -> perf conventions
writing -> personal style samples
~~~

第三种尤其容易被忽略。

AGENTS.md 现在通常是全局读进去，或者随着目录递归加载。

但如果 Context Compiler 存在，就可以变成：

~~~text
if task.frontend:
    include frontend-style

if path under src/auth:
    include auth-gotchas

if task.writing:
    include writing-style
~~~

而且这些 context 可以声明：

~~~text
sticky = true
~~~

意思不是“永久塞进 session”，而是：

> 只要当前 task 条件还成立，每次重新编译 context 都必须重新带上。

这样也不怕 compaction 把重要规则压没。

## Batteries included 可能不再和 power user 冲突

Agent 产品一直有一个很现实的矛盾。

内置东西越多，新用户越方便。

但 tool、rules、plugins、skills、docs 越多，system prompt 和选择空间也越来越重。

所以一边是 OpenClaw 这种“什么都给你”，另一边是很多 power user 更喜欢一个小而可控的核心。

如果 action/schema/docs 都可以动态发现，这个矛盾会弱很多。

你完全可以内置：

~~~text
100+ tools
1000+ docs
几十种 workflow
各种热门 repo 工具
~~~

但默认只暴露非常小的 capability index。

等模型判断“这里可能需要 AST search”，再加载 ast-grep 的详细说明和 action schema。

这时候“内置很多东西”的边际 context 成本接近于零。

这个方向我很感兴趣，因为它不只是省 token。

它会改变 Agent 产品到底该不该 batteries included 这个问题。

## Background processing 可能比 Subagent 更值得先做

原文后面的一个 Appendix 也让我印象很深。

最近很多看起来很有用的 Agent workflow 有一个共同点：

**它们其实适合在后台跑。**

比如：

- 生成/刷新 UI 页面；
- 构建理解代码库的 artifacts；
- 后台生成 eval；
- cross-model review；
- security review；
- documentation drift；
- graph refresh。

而且很多任务都是当前 codebase revision 的只读函数。

也就是说：

~~~text
Revision R
   │
   ├── architecture review
   ├── security review
   ├── test-gap analysis
   ├── graph refresh
   ├── docs drift
   └── eval generation
~~~

它们完全可以并行。

只要 revision 变成 R+1：

~~~text
旧结果 -> stale
~~~

这和“启动 N 个聊天 subagent，然后把聊天合回来”不一样。

它更像一个 build system 或 dataflow。

我现在越来越觉得，很多所谓 Multi-Agent 问题最后会长成：

> structured state + scheduler + read/write set + revision。

而不是很多人格不同的小模型互相聊天。

## 这也是为什么我不太想让 wcode 变成另一个 Claude Code

我之前给 wcode 的定位一直是 Repository / Engineering Control Plane。

读完这份笔记后，我反而更确定这一点。

如果真的从 KV-cache-free 的角度重新设计，最值得造的不一定是：

> 又一个 Coding Agent UI。

而是 Agent 下面那层本来就应该存在的 runtime。

现在 wcode 已经有很多适合放在这层的东西：

~~~text
Execution
Worklist
Workspace
Design State
Software Graph
Semantic / LSP
Impact
Risk
Verification
Evidence
Reconciliation
Runtime Tasks
~~~

这些状态都不应该只存在于某个聊天 session。

模型可以换。

Codex、Claude Code、ChatGPT、自研 Agent 都可以换。

仓库当前发生了什么、什么已经验证、什么还没做，不应该跟着换。

## 下一步我更想做 Context Fabric

我现在脑子里的结构大概是：

~~~text
                         Agent
                           │
                      current goal
                           │
                           ▼
                 ┌──────────────────┐
                 │  Decision Plane  │
                 └────────┬─────────┘
                          │
         ┌────────────────┼────────────────┐
         ▼                ▼                ▼
 Context Compiler    Action Router     Model Router
         │                │                │
         ▼                ▼                ▼
    State Fabric      Action Registry     Models
         │
         ├── repository
         ├── execution
         ├── worklist
         ├── graph
         ├── semantics
         ├── evidence
         ├── verification
         ├── runtime
         └── background artifacts
~~~

其中我现在最想先做的不是 Model Router。

反而是前两个。

### Context Compiler / Fabric

给所有可加载信息统一描述：

~~~text
source
revision
freshness
scope
sensitivity
cost
relevance
render level
~~~

然后根据当前 task 动态编译。

### Action Registry

不让模型默认看完整 tool catalog。

先暴露轻量 capability index，需要时再加载完整 schema。

如果这两个成立，routing、subagent、skills 和 batteries included 后面都会好做很多。

## TypeSafe / Jev 在这里应该做什么

这里我也不想把 Jev 神化。

很多事情根本不需要模型：

~~~text
文件 SHA 对不对？
当前 revision 是什么？
路径在不在 Workspace？
这个 Evidence stale 了吗？
这个 command 被 policy 允许吗？
~~~

代码能算就让代码算。

TypeSafe / Jev 真正适合的是这种边界：

~~~text
这个 chunk 对当前 query 有多相关？
需要原文还是摘要？
还缺不缺某类 repository evidence？
这几个 actions 哪个方向最合理？
这个 subgoal 和已有 subgoal 是不是重复？
这段 retrieved text 是 evidence、冲突还是 instruction？
~~~

也就是把一些原本藏在 Agent prompt 里的“语义 if”结构化。

我还是会坚持现在 wcode 里那条边界：

> Learned decision 可以增加工作，不能绕过 deterministic safety。

## 一个更激进的想法：Agent 不再拥有状态

传统 Agent 很像：

~~~text
Agent session
    owns
context/history/state
~~~

我现在更喜欢：

~~~text
Engineering Runtime
    owns
state

Agent
    leases
a task-specific view
~~~

Agent 只是当前这个任务的计算器。

它拿到一份 Context View，做一轮判断，调用 action，把结果写回 runtime。

下一轮甚至可以是另一个模型。

只要 state contract 没变，就不用把整个“脑子”搬过去。

如果最后能做到这一点，所谓 model routing 才会真正自然：

~~~text
任务简单
→ 小模型拿一份小 context

任务复杂
→ 大模型拿一份更丰富 context

需要 review
→ 另一个模型读取同一 revision 的 review view
~~~

不需要把一个模型过去半小时的 session 全部 replay 给另一个模型。

我觉得这才是 routing 真正应该解决的问题。

## 最后

“Why yet another agent” 这个标题一开始会让人以为答案是：

> 因为我们能做一个更好的 Agent。

我读完以后得到的答案反而是：

> **也许根本不应该先做 another agent。**

现在很多 Coding Agent 的奇怪结构，并不一定是 Agent 的本质。

它们可能只是我们为了维护一个巨大、昂贵、不断增长的 KV cache，而逐渐长出来的工程妥协。

如果把 state 和 context 拆开，把 context 看成每轮动态编译的视图，把 tools/skills 看成可检索的 action space，把 subagent 看成共享 revision 上的结构化 worker，很多今天很难的问题会换一种样子。

所以对 wcode 来说，我现在更想做的不是一个新的聊天界面。

而是继续往下面走：

**State Fabric、Context Compiler、Action Registry、Background Intelligence。**

Agent 本身可以很薄。

如果未来所有 Coding Agent 都能踩在这层上面，那比再做一个 Claude Code clone 有意思得多。
