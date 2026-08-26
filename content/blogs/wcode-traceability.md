---
title: "wcode：Git Diff 之外，我还想知道什么"
date: 2026-08-26T03:13:00+08:00
draft: false
url: /blog/wcode-traceability/
description: "Diff 能告诉我哪里改了，但 Review 时我真正想知道的是：这个改动碰到了什么功能、哪些约束、哪些调用方，以及设计有没有开始和代码分叉。"
tags:
  - Rust
  - wcode
  - Software Design
  - Code Review
images: []
---

我做 Code Review 时很少只看 Diff。

Diff 只是入口。

看到一个函数被改，我脑子里会自动继续问：谁在调用它？这个模块原来为什么这么写？有没有对应测试？它是不是安全边界？这次只是重构，还是已经改变了设计？

这些问题以前都靠人自己补。

Agent 也一样，只不过它能补多少，很看这一次上下文有没有给够。

所以做完 Design State 和 Software Graph 以后，我开始把其中一部分变成 wcode 可以直接算的东西。

## Traceability 先回答最笨的问题

`traceability_status` 主要看几条链有没有断：

```text
Requirement → Component
Component → Implementation
Acceptance Criterion → Verification
```

我一开始考虑过做一个总 Coverage。

比如：

```text
87%
```

后来觉得没什么用。

如果丢的是一个低优先级页面的 Acceptance，和丢的是 Workspace Root Isolation 的测试，显然不是同一件事。把它们平均成一个百分比，信息反而少了。

所以现在直接分开报。

我更想看到这种东西：

```text
Requirement 还在
Component 还在
但原来映射的 Symbol 已经搬走了
```

或者：

```text
Acceptance 还指着一个已经改名的 test
```

这种错误没有多高级，但特别常见。

## Product Scope 解决“别把整个仓库都拖进来”

wcode 后来又加了 Product Scope，因为只靠 Requirement 还不够。

项目一大，Context 很容易横跨一堆不相关目录。

现在我通常先跑 `scope_status`，看看源码是怎么落在各个 Scope 里的，还有没有没归类的文件。真正做任务时，`software_context(scopes=...)` 会把源码导航收窄到指定范围。

例如我只在 `workspace` / `risk` 一类 Scope 里查，就不会顺手把 UI、Connector、Release 相关东西一起塞进来。

这个功能对模型没有那么“惊艳”，但对长期项目很实用。Context 少一点，误判也少一点。

## Drift 不是报错，更像提醒

Traceability 看的是“关系还通不通”，Drift 看的是“变化之后，两边是不是开始不一致”。

现在大致有两类。

一种是 Implementation Drift。

Design 变了，代码没跟；或者原来声明的实现、验证链现在断了。

另一种是 Design Drift。

某个已经有 Design 身份的实现被改了，但这次 Design State 完全没动。

第二种不能理解成“改代码必须改 YAML”。

很多重构当然不需要改设计。

所以它更像一句提醒：

> 这个地方在 Design State 里是有名字的，现在代码变了，确认一下原来的描述还成立。

我不想把这种 heuristic 叫 formal verification。它没那么聪明。

## Impact 是我真正天天想看的东西

Git 能给 Changed Paths，但 Review 时我通常还想看：

```text
碰到了哪些 Component
关联哪些 Requirement
哪些 Acceptance 需要重新验证
调用方有哪些
有没有 Public API 信号
有没有 Security Boundary
```

`impact_analysis` 会从 Working Tree 开始，再沿 Composite Software Graph 往调用方扩。

现在主要看 `Calls` / `RuntimeCalls` 这类关系。

有 fresh LSP / Runtime Provider 就用更高精度的关系；没有就退到 Tree-sitter Syntax Edge。结果里会保留 Provider 和 Precision，不把不同来源混成一句“确定会影响”。

这也是为什么前面 Software Graph 那篇我一直强调 provenance。

没有 provenance，Impact 最后只剩一个很自信的列表，但没人知道它为什么这么判断。

## Transitive Analysis 一定得有刹车

调用图特别容易爆。

一个底层 helper 可能被几百个地方用。如果“所有调用方的调用方再递归展开”没有上限，最后返回的 Context 比直接把仓库读一遍还离谱。

所以 wcode 这类 Query 都是 bounded 的。

到上限就明确返回：

```text
truncated = true
```

我宁愿看到一个“这里没展开完”，也不要看到一份看起来完整、其实只是因为上下文被截断而少东西的结果。

## Review 里现在还会看代码是不是开始长歪

最近 `review_changes` 又加了一些结构信号。

例如：

```text
一个源码文件从 1,000 行以下跨到 1,000 行以上
大量净新增集中在一个文件
一次大改横跨多个 Product Scope
```

这些不会直接判“代码质量差”。

它们只是进入 Risk，让后面的 Verification 决定是不是要增加 Maintainability Review。

这个区别我觉得挺重要。

工具可以很容易数行数，但“抽象是不是多余”“是不是出现了重复的 canonical helper”“是不是为了兼容又堆了一层 wrapper”，这些还是要 Review。

所以确定性信号负责发现值得看一眼的地方，Reviewer 再判断是不是问题。

现在 Project Observatory 也会把 Requirement、实现、Verification、Git Change 和依赖关系放在一起。我平时打开它，基本就是为了回答这篇文章标题那个问题：

**Diff 之外，这次到底动了什么。**

Impact 算出来只是知道该看哪里，最后还是要落到“怎么证明这次改动真的可以”。Verification 和 Evidence 我放在 [测试通过以后，我还想留下什么](/blog/wcode-verification/) 里。