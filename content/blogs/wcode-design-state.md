---
title: "wcode 的 Design State：我为什么把需求写进仓库"
date: 2026-08-26T03:11:00+08:00
draft: false
url: /blog/wcode-design-state/
description: "我想留住的不是一套漂亮文档，而是 Requirement、Component、实现和测试之间那条会随着代码一起被检查的链。"
tags:
  - Rust
  - wcode
  - Software Design
  - AI Agent
images: []
---

做 wcode 一段时间以后，我越来越不喜欢一种状态：代码里明明有很多约束，但这些约束只活在人脑里。

比如 Workspace Root 为什么不能随便放宽，为什么 Symlink 要单独挡，为什么一个旧 SHA 不能继续写文件。代码看得出来“怎么做”，但不一定看得出来“为什么不能改成别的样子”。

人长期待在项目里还好，换一个 Agent 进来，它看到的通常只有当前源码。

于是我开始把一部分“为什么”写进仓库。

不是 README，也不是另起一个 Wiki，而是一份机器也能读的 Design State。

## 其实就是几份 YAML

现在结构很普通：

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

关键不在 YAML，而在稳定 ID。

例如 Workspace Root Isolation 可以有一个 Requirement：

```yaml
- schema_version: 1
  id: REQ-SEC-001
  title: Workspace root isolation
  intent: Remote models must never escape the configured workspace root.
  priority: critical
  implemented_by:
    - component:workspace-security
  acceptance:
    - AC-SEC-001
  constraints:
    - CONSTRAINT-ROOT-ISOLATION
```

Component 再指到真实实现。现在 wcode 的目录已经拆过几轮，Workspace Root 相关实现就在：

```yaml
- schema_version: 1
  id: component:workspace-security
  name: Workspace Security
  implementation:
    - kind: symbol
      path: src/workspace/roots.rs
      symbol: Workspace::existing_path
```

Acceptance 最后落到测试：

```yaml
- schema_version: 1
  id: AC-SEC-001
  title: Workspace traversal is blocked
  verification:
    - kind: test
      path: src/workspace/mod.rs
      symbol: tests::blocks_path_traversal_and_stale_writes
```

最后能顺着一条真实链走下去：

```text
REQ-SEC-001
    ↓
component:workspace-security
    ↓
src/workspace/roots.rs::Workspace::existing_path
    ↓
AC-SEC-001
    ↓
src/workspace/mod.rs::tests::blocks_path_traversal_and_stale_writes
```

这件事看起来很朴素，但它改变了我给 Agent 下任务的方式。

以前会说：

> 去看一下 workspace 相关代码，路径安全这里改一下。

现在可以先从 Requirement 开始：

> 看一下 workspace root isolation 现在的实现、约束和验证。

文件名反而是后面的事情。

## 我不想维护第二份源码

Design State 最容易做过头。

如果每个函数、每个类型、每条调用关系都要手工抄进 YAML，那这东西一定会烂掉。代码一重构，Design State 马上过期，最后大家只能一起假装它还可信。

所以我现在只放那些值得稳定命名的东西：

```text
Requirement
Component responsibility
Constraint
Acceptance Criterion
重要 Decision
```

至于“这个函数现在调用谁”“某个模块里有哪些 Symbol”，让代码索引和 Software Graph 自己算。

Design State 负责的是“应该是什么”，不是给源码做一份手写镜像。

## Product Scope 是后来补的一层

项目拆大以后，我还遇到过另一个问题。

Design State 能告诉我 Requirement 属于什么能力，但 Agent 做源码导航时仍然可能在整个仓库里乱跑。

所以后来 wcode 又有了 Product Scope。

它和 Design State 不是一回事。

Design State 管稳定的产品意图，Product Scope 更像源码架构上的边界。现在 `scope_status` 会检查源码落在哪些 Scope，还有没有没归类的文件；`software_context(scopes=...)` 可以真的只在选定 Scope 里找相关源码。

我自己用下来，两个东西刚好互补：

```text
Design State：为什么有这个能力
Product Scope：这类能力大致落在哪块源码
Software Graph：代码现在实际怎么连
```

比起把所有东西都塞进一张图里，这样更容易维护。

## Tree-sitter 解析到了，也只能说明解析到了

Component 和 Acceptance 可以引用 Symbol，但基础解析还是 Tree-sitter。

所以结果会明确带：

```text
provider = tree-sitter
precision = syntax
```

这表示“这里有这个语法定义”，不是“编译器已经证明这就是最终绑定到的实现”。

这种区别有时候很烦，尤其写展示页面时，直接写成“已解析”会好看很多。

但我宁愿页面上多一个 `syntax`，也不想让 Design State 借着结构化格式显得比底层事实更可靠。

## 我最后还是让 wcode 管自己

Design State 真正变得有用，是我开始拿它 Dogfood wcode 自己以后。

源码一移动，Traceability 会暴露旧路径；Requirement 加了 Acceptance 但测试没接上，也会直接出现 Gap。现在 Project Observatory 里还能从 Requirement 一路看到 Component、当前实现、Verification 和这次 Git Change。

这时候 `.wcode/design` 才不是“又多了几份文档”。

它真的进入了开发流程。

当然它也会带来维护成本。改架构时，有时候代码改完还得回来修 Design mapping。这个成本我现在愿意付，因为不付的代价通常是几个月以后重新猜一遍为什么当初这么设计。

下一篇是 [Software Graph](/blog/wcode-software-graph/)。Design State 解决“应该是什么”，Graph 解决的是另一个更麻烦的问题：代码现在到底是什么，而且我们对这个答案有多大把握。