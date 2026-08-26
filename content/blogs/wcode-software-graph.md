---
title: "wcode 的 Software Graph：先承认自己不知道"
date: 2026-08-26T03:12:00+08:00
draft: false
url: /blog/wcode-software-graph/
description: "Tree-sitter、LSP、Runtime 都能提供关系，但它们不是同一种事实。我更在意把来源、精度和版本留下来。"
tags:
  - Rust
  - Tree-sitter
  - LSP
  - wcode
images: []
---

最早写 wcode 的代码索引时，我没想过要做什么 Software Graph。

当时的问题很直接：模型一进大文件就喜欢整份读，几百上千行源码一股脑塞进上下文。于是我先做了 Tree-sitter，给它几个更小的入口：

```text
file_outline
find_symbol
symbol_context
```

这套东西到现在都还在，而且是我最喜欢的一层。便宜、稳定，不用启动项目。

后来开始做 Impact，我才发现“临时查一下 Symbol”不够了。

我需要知道 A 和 B 的关系，还需要知道这条关系是谁告诉我的、什么时候算出来的、源码变了以后还能不能信。

这才有了 Software Graph。

## Tree-sitter 知道的没有想象中那么多

Tree-sitter 很适合做结构分析。

定义在哪里、Range 是多少、Qualified Name 是什么，这些都比较稳。一些语法上能明确判断的调用关系，也可以抽出来。

但它没有编译器的类型系统，也不会替我做宏展开、重载选择和动态分派。

所以 Tree-sitter 产生的关系一直带着：

```text
provider = tree-sitter
precision = syntax
```

我后来越来越在意 `precision` 这个词。

做 Agent 工具时，很容易为了让返回结果“看起来更聪明”，把一个启发式结果包装得像确定事实。短期体验会很好，后面做 Impact、Risk 时却很危险，因为上层已经不知道底下到底有多靠谱。

所以这里干脆先承认自己不知道。

## LSP 也不是装了就算 semantic

现在 wcode 有一套第一方 Semantic Provider，会探测 rust-analyzer、gopls、clangd、typescript-language-server、pyright 这些 Language Server。

但“机器上有这个二进制”和“当前结果是 semantic”是两回事。

只有 Language Server 真正启动、返回 Document Symbol / Call Hierarchy / Implementation，这些结果才进入 Graph，并标成：

```text
precision = semantic
```

Repository-aware Language Server 也不是默认无条件执行。

它可能加载项目配置、Build Metadata、插件，甚至间接执行仓库里的东西。现在有两种授权方式：启动 wcode 时直接用 `--allow-risky-exec` 做进程级放行；或者让具体 Refresh 先触发本地 Authorization Request，我在 TUI 里批准这个操作后再重试。

后者是我后来补的，因为很多时候我只想临时跑一次 rust-analyzer，不想顺便把整个 Runtime 后面的高风险执行都放开。

## stale semantic 比没有 semantic 更糟

这里有个很容易忽略的问题。

假设上午跑过 rust-analyzer，拿到一组 Call Hierarchy；下午我已经把源码改了一大轮。如果 Impact 还拿上午的结果继续推导，它会表现得很“精准”，实际上精准地错了。

所以第一方 LSP Fact 会带 `source_sha256`。

源码对不上，这个 Provider Revision 就会 stale。stale 的关系不会再进新的 Software Graph，也不会继续参与 `software_context` 和 Impact。

要用就重新 Refresh。

这点比“自动保持 semantic 数据永远最新”笨一点，但边界清楚。

## 同一条关系可以有几个答案

Software Graph 没有试图把所有来源揉成一个最终真相。

一条 Edge 会保留自己的：

```text
provider
precision
revision
attributes
```

所以同一个 `A -> B` 完全可能同时有：

```text
Tree-sitter syntax call
LSP semantic call
Runtime observed call
```

它们不互相覆盖。

如果以后接 SCIP、Compiler Index 或 Runtime Trace，也还是走同一个 provider-neutral contract。

这样做的好处是，上层可以自己决定信谁。

Impact 遇到真实 Runtime Edge，可以用真实运行关系；只有 Syntax Edge 也能继续工作，只是结果需要更保守。

## Graph History 解决的是另一个问题

当 Graph 开始被拿来做分析以后，我还想看结构到底怎么变的。

于是加了：

```text
graph_history
graph_query
graph_diff
```

这里没有每查询一次就存一份快照。图内容没变，就不制造历史噪音。

Node 用稳定 ID 对齐。Edge 则按：

```text
from + to + kind + provider + precision
```

先找身份。

如果只是 Revision 或 Attributes 变了，就算 `changed`，而不是先删一条再新增一条。

这类实现细节平时没什么存在感，但图一旦有几十版历史，没有稳定身份很快就看不下去了。

## 我后来把 WebUI 的球图降级了

Software Graph 做完后，我也走过一个很自然的弯路：既然已经有图，那就在 WebUI 里画出来。

于是有过一个能缩放、拖拽、点 Node 看 provenance 的 Graph Canvas。

我自己打开几次以后发现，它更像 Debug Tool，不像项目管理页面。

我真正想查的是某个 Requirement 现在由谁实现、Acceptance 在哪、设计依赖和代码依赖有没有分叉、最近改动碰到什么，而不是盯着几十个圆点猜哪条线比较重要。

所以现在主 UI 已经改成 Project Observatory，按 Requirement 往下看 Feature、Component、Implementation、Verification 和 Git Change。

低层 Graph 没消失。

它仍然是 Context、Impact、历史 Diff 的数据来源，只是不再承担“解释整个项目”的视觉任务。

这可能是我做这块以后最大的一个认识：**有 Graph，不代表产品就应该长成 Graph。**

Graph 到这里还只是底层事实。真正拿它去做 Review 时，问题会变成另一句：Diff 之外，这次到底动了什么。那部分我放在 [Git Diff 之外，我还想知道什么](/blog/wcode-traceability/) 里。