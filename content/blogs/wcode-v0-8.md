---
title: "wcode v0.8：我开始把仓库当成一个 Engineering Digital Twin"
date: 2026-09-19T15:32:00+08:00
draft: false
url: /blog/wcode-v0-8/
translationKey: wcode-v0-8
image: /img/wcode/wcode-intro-intelligence-stack.zh-CN.svg
description: "0.8 我没继续堆更多 Agent 工具，而是把 Architecture、Code Graph、Decision Plane、Engineering Fitness 和 Verification 往同一份工程状态里收。现在最新是 0.8.1。"
tags:
  - wcode
  - Rust
  - Coding Agent
  - Engineering Digital Twin
  - Decision Plane
  - Release
images:
  - /img/share/wcode-v0-8.png
---

0.7 做完以后，wcode 已经能让 Agent 比较安全地读仓库、改文件、跑验证，也能把 Design State、Software Graph、Evidence 和 Reconciliation 留下来。

但我自己用它时还有一个很明显的问题：

> Agent 能操作这个仓库，不代表人能快速看懂这个仓库现在是什么状态。

很多时候我还是会回到 IDE：看目录、找调用方、翻测试、对照 Git Diff，再回 wcode 看验证。几套视图各自都对，但它们没有真正收成同一个工程模型。

所以 0.8 我想做的不是“再加几个 MCP Tool”，而是把这些东西往一个方向收：

**把仓库当成一个可以观测、查询、回看，而且知道自己证据精度的 Engineering Digital Twin。**

现在最新版本已经是 **v0.8.1**。0.8.0 把这个骨架搭起来，0.8.1 又把 Decision Plane 和 Jev 的边界收紧了一轮。

![wcode 的工程智能栈：从仓库事实、图关系到验证证据](/img/wcode/wcode-intro-intelligence-stack.zh-CN.svg)

## Code Graph 不再只是“把节点画出来”

我以前一直对“代码图谱”这件事有点警惕。

最容易做的是把函数、文件、模块全画成一个大球。看起来信息很多，实际用的时候还是不知道：

- 这个关系从哪里来的；
- 是 Tree-sitter 看出来的，还是 LSP 确认的；
- 是设计里声明的，还是 Runtime 真跑过；
- 这个调用关系属于当前代码，还是旧 Snapshot；
- 它和这次 Working Tree 改动到底有没有关系。

0.8 里我把 Code Graph 放进了 **Engineering Architecture**，而不是再加一个顶层页面。

架构还是主视图。Code Graph 只是继续往下钻的一层。

现在可以从一个符号看 callers、callees、references、dependencies、implementation ownership、tests、requirements，以及 verification / proof context。

但我不允许它无限扩张。Calls、Impact、All Evidence 都有 depth、node、edge 的硬上限，UI 也按“上游 → 当前节点 → 下游”来排，不做无限节点球。

更重要的是，每条关系都保留自己的 **provenance** 和 **precision**。

Declared、Syntax、Semantic/LSP、Runtime、Deterministic、Heuristic 不会最后被压成一句“confidence: high”。

我宁可界面告诉我“这条边只是 syntax 推断”，也不想让一个漂亮的图把不确定性藏掉。

### Graph History 也进来了

0.8 的 Code Graph 可以直接切历史 Snapshot。

这个功能我自己很喜欢，因为它解决的不是“现在代码怎么连”，而是：

> 这条关系以前是不是也存在？

切换 Snapshot 后只是只读时间旅行，不会重新扫描仓库，也不会改当前状态。

对 Agent 来说这能做 impact/context；对人来说它更像一个工程历史视图。

## Observatory 终于没那么吵了

0.7 时代的 Observatory 有一个很烦的问题：浏览器为了拿新状态，可能连续触发比较重的 Snapshot。

功能没错，但体感很差。

0.8 改成每个 Workspace 同时最多只有一个后台重快照。已经有缓存就先给缓存，同时带上 Revision Stamp，明确告诉前端 cached、current、refreshing。

浏览器自己只做轻量探测，不再 fan-out 一组重请求。

我顺便把 UI 的层级也重新整理了一次。

第一眼只看 Project Pulse 和状态；第二眼才看指标、关系、时间线；Evidence 和 Inspector 放到第三层。

Stale、Unknown、Inconclusive、Failed、Unverified 也不能再长得像绿色 Passing Proof。

这是个很小的规则，但对“工程控制面”很重要：**UI 不能比底层证据更自信。**

## 我开始真的把它叫 Engineering Digital Twin

这个名字以前我其实不太敢用。

如果只是把代码索引成图，我觉得叫 Digital Twin 有点虚。

0.8 以后我觉得它开始接近这个词了，因为看到的不再只有 Source：

    Design State
        ↓
    Implementation ownership
        ↓
    Syntax / Semantic / Runtime relations
        ↓
    Working Tree changes
        ↓
    Drift / Risk / Impact
        ↓
    Verification / Evidence

这些东西不是复制一份新的“项目数据库”出来。

源码、Git、Design State 和 Evidence 仍然各自是事实来源。Digital Twin 只是把它们组织成一个可查询的只读工程视图。

这点我刻意没有放松。否则最后很容易出现第二份 mutable project state，然后你开始不知道到底应该信代码，还是信“数字孪生”。

![wcode 的工程闭环：Context、Graph、Change、Verification 与 Evidence](/img/wcode/wcode-intro-engineering-loop.zh-CN.svg)

## Decision Plane 也在 0.8 里真正成形了

另一个我花时间很多的东西是 **Decision Plane**。

Coding Agent 有很多判断其实没必要直接交给大模型：

- Context 够不够；
- 要不要继续 Retrieval；
- 跨文件关系是不是安全修改前的必要证据；
- 是否应该增加 Verification；
- 当前状态是不是应该 abstain。

0.8 把这类判断收成了 provider-neutral 的结构化信号：Probability、Choice、Score。

但这里最重要的不是“可以接一个小模型”。

最重要的是 **Decision Plane 没有拿到安全边界的最终权限**。

Authorization、Workspace Boundary、SHA Precondition、Evidence、Risk-derived Verification、Human Approval 还是确定性的。

Decision Plane 可以说“我建议多查一点”，但不能说：

> 我有 0.93 confidence，所以这个 SHA 不用检查了。

这种路我一开始就不想走。

## Engineering Fitness 不再拿自己的 readiness 当答案

Decision Plane 如果没有独立评测，很容易变成自己给自己打分。

所以 0.8 的 Context Sufficiency 改成对照独立写的 **Engineering Fitness Gold**。

我关心的不只是“有没有找到文件”，而是：

1. Required Identity 有没有找到；
2. 完整 Source Body 有没有交给 Agent；
3. SHA 是不是新鲜；
4. 真要编辑时需要的 Edit Inputs 有没有齐。

0.8.0 发布时那组 60-case model-free diagnostic 里，1K cold / warm 的 Required Identity Recall、Complete Body Recall、Fresh SHA Recall 都是 **100%**；58 个可写 Eligible Case 里 **58/58** 都拿到了完整 Edit Inputs。

Decision baseline 的 Brier 是 **0.018846**，False Stop 和 False Continue 都是 **0**。

我不会把这组数写成“wcode 已经解决 Context Engineering”。

它只是一个比较有用的基线：以后我改 Retrieval、Ranking、Budget 或 Decision Plane 时，至少有一组不依赖主模型的东西可以告诉我是不是把基本能力改坏了。

## Jev 在 0.8.1 里被我又收窄了一次

0.8.0 已经能让 Decision Plane 比较 baseline 和 candidate provider。

到了 0.8.1，我把外部语义 Provider 的命名统一成了 **Jev**，本地无模型层就叫 **Decision Plane**，主模型继续叫 **Reasoning Model**。

更重要的是，问题本身也重新写了一轮。

比如我原来会问：

> semantic navigation 有没有帮助？

这个问题太宽了。

在 Coding Agent 里，看看更多关系几乎永远“有帮助”。于是 Provider 很容易一直建议继续查。

0.8.1 的问题变成更窄的边界：

> semantic relationships 是不是安全修改前的必要证据？

Choice 也不再只有“继续/不继续”，而是把正反 criteria 写清楚，并加入 other_review。

不完整、低集中度、边界不清楚的状态就 abstain，回去收集证据。

当前 Agent Context 的 Jev question set 是 wcode.agent_context@3。

### Jev 只能 increase-only

Jev 现在可以要求更多 Retrieval、Semantic Navigation、更多 Verification，或者继续 Reasoning。

但不能减少 deterministic baseline 要求的工作。

尤其是 edit_then_verify：只有 baseline 本来就允许同一动作时，Jev 才能同意；它自己不能把一个 Unknown 状态升级成“可以编辑”。

而且 Jev advisory 如果会把 Agent Context 撑过预算，先丢的是 advisory，不是 Source、SHA、Test 或 Risk Evidence。

这也是我现在比较满意的一点：

**外部 Provider 挂掉，wcode 少一层建议；它不会少一层安全。**

## Shadow A/B 比“换掉 baseline”更适合我现在的阶段

0.8 没有直接让 Jev 接管 Decision Plane。

同一个不可变 DecisionRequest 会同时给 baseline 和 candidate，然后记录 shared / missing signal、probability / score delta、Choice disagreement、shape mismatch 和 safety-policy violation。

这更像 Shadow A/B。

我先看它在哪些状态下和 baseline 不一样，再决定它有没有资格影响 Runtime。

这种做法慢一点，但比“API 接通了 → 默认启用 → 看线上有没有出事”靠谱很多。

## 仓库扫描也终于统一尊重 Ignore

这部分不太显眼，但实际体感提升很大。

以前 Source Scan、Search、Index、Status、Subspace Discovery 各自有自己的遍历路径，很容易出现一条链路避开 target，另一条链路又进去。

0.8 把这些统一到 Ignore-aware Walker。

默认遵守 .gitignore、.ignore、Git info exclude、global exclude 和 protected paths。target、node_modules、cache、常见 build output 也会在 traversal 前就剪掉。

但 explicit intent 还是优先：你明确指定一个 ignored path，Read/Search 仍然可以在边界内访问。

我不想为了性能把“用户明确叫我读这个文件”也一起吞掉。

## TUI 现在更像任务控制面

0.8 的 TUI 我也砍了一些东西。

宽终端现在是 70/30：Workspace Activity 占主画布，Engineering / connection state 放右侧。

右边只留四条主要状态：

    ARCH
    DRIFT
    PROOF
    MODEL

中等和窄终端干脆不常驻 Engineering Pulse，让任务本身优先。

我越来越觉得 TUI 的任务不是把所有指标都塞进去，而是回答三个问题：

- 现在 Agent 在干什么；
- 有没有卡在权限/验证/运行时；
- 我什么时候需要介入。

详细 Architecture 和 Proof 还是可以进 Engineering Console 看。

## 0.8.1 还修了两个“看起来正确”的 UI 问题

这两个问题很典型。

Code Graph 发请求时有 query / mode / depth / snapshot。旧响应晚回来时，只看“请求成功”是不够的；它必须和当前四个语义参数全部一致，才能发布到 UI。

Access 页面也类似。Workspace、Commands、Authorizations 三路状态要原子发布。只要其中一路 shape validation 失败，就整组保持 Unknown。

否则最危险的不是页面报错，而是页面展示一个**部分正确、看起来又很完整**的状态。

这和我前面说的其实是同一件事：

> 工程 UI 不能比证据更确定。

## 0.8 没有改变我最早那条边界

从 0.3 到 0.8，wcode 上层已经变了很多。

但几条底层原则我没有准备改：

- Workspace Root 仍然是边界；
- 修改仍然绑定 SHA；
- Full Access 只能由 Operator 明确选择；
- Decision Plane 不能授权；
- Jev 不能降低 Verification；
- Cancellation 不等于 Rollback；
- Verification Evidence 必须绑定具体 Revision。

Engineering Digital Twin 也是只读层。它不会因为“图里看起来应该这样”就去改项目。

![wcode 的验证网格：确定性检查、独立 Review 与证据绑定](/img/wcode/wcode-intro-verification-mesh.zh-CN.svg)

## 这次版本跨度其实挺大

从 v0.7.6 到 v0.8.0，Git Diff 跨了 **135 个文件，约 +7,364 / -775 行**。

我一开始也以为这会是一个“Code Graph + Observatory UI”的版本。

写到后面才发现，真正牵动的是整条链：

    Repository scan
        ↓
    Context
        ↓
    Graph / Digital Twin
        ↓
    Decision Plane
        ↓
    Edit boundary
        ↓
    Verification
        ↓
    Evidence
        ↓
    Human observability

所以最后我把 0.8 的主题定成了 **Engineering Digital Twin**，而不是 Code Graph。

Code Graph 只是其中一个入口。

## 现在是 0.8.1

v0.8.0 是 9 月 19 日发布的 Engineering Digital Twin 版本；同一天我又发了 v0.8.1，主要把 Jev Decision Plane、命名和 WebUI state truthfulness 收紧。

如果你只想看版本说明：

- [v0.8.0 — Engineering Digital Twin](https://wcode.francis.run/zh/docs/releases/v0.8.0/)
- [v0.8.1 — Jev Decision Plane 加固](https://wcode.francis.run/zh/docs/releases/v0.8.1/)

如果问我 0.8 最重要的变化是什么，我现在会说：

**以前 wcode 主要是在帮助 Agent 安全地操作仓库；0.8 开始，我希望 Agent 和人看到的是同一份、带证据来源和精度的工程状态。**

这件事还远没做完，但方向终于比较清楚了。
