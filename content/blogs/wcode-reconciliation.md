---
title: "wcode：我为什么开始把 edit file 往后放"
date: 2026-08-26T03:15:00+08:00
draft: false
url: /blog/wcode-reconciliation/
description: "真正麻烦的不是怎么改文件，而是为什么改、先改什么、谁来验证，以及一个长任务中断以后还能不能继续。"
tags:
  - Rust
  - wcode
  - AI Agent
  - Software Design
images: []
---

写 Coding Agent 很容易最后都收敛到几个工具：

```text
read_file
search
edit_file
run_test
```

第一版 wcode 也差不多。

当时我花很多时间把这些工具做得安全一点：路径不能逃出 Workspace，写入有 SHA，命令不经过 Shell，验证有固定 Harness。

这些当然还重要。

但用久以后我发现，`edit_file` 其实不是最难的部分。

真正让我头疼的是一个稍微大一点的修改：为什么要改？这次到底影响什么？哪件事必须先做？什么时候算完成？如果一个模型做到一半退出了，第二个模型从哪里接？

所以我后来开始把 `edit file` 往后放，前面先补 Reconciliation。

## 我先想要的是一个能恢复的 Plan

现在一条链大概是：

```text
Design State
    ↓
Actual State / Git Change
    ↓
Drift
    ↓
Impact
    ↓
Risk
    ↓
Reconciliation Plan
    ↓
Verification / Human Approval
    ↓
Evidence
```

Plan 不是一句“修好这个问题”。

它会带上这次 Design Change、发现的 Drift、Impact、Risk、Change Intent 和 Verification Requirement，然后再拆成有依赖的 Task。

这听起来有点重，但我做它的原因其实很现实：**聊天记录不是工作状态。**

## Session 断掉比想象中常见

模型会换，工具会重连，Web Session 会过期，有时我自己也会中途停下来改别的东西。

如果任务做到一半，所有进度都只存在上一段 Conversation 里，下一次基本又得从头解释。

所以 Reconciliation Plan 和 Execution 都会持久化。

执行者面对的是：

```text
claim
submit
retry
status
```

Claim 只能拿当前依赖已经满足的 Task。

Submit 会留下执行结果和 Evidence。

失败就是失败，不会因为任务“差不多做完了”自动翻成成功。要继续就 Retry。

这套状态机没有多复杂，但它给不同模型之间提供了一个比聊天记录稳定得多的交接面。

## “代码写完”不等于“修改完成”

我后来很想把这两个状态拆开。

以前 Agent 写完最后一个 Patch，往往心理上任务就已经结束了，测试变成一个尾巴：

```text
TODO: run tests
```

Reconciliation 里 Verification 和 Human Approval 可以是实际的系统 Gate。

只有对应 Evidence 到了，Task 才继续往后走。

所以：

```text
Implementation complete
```

和：

```text
Change converged
```

不是同一个状态。

这个区别在安全相关修改里尤其明显。代码可能十分钟前已经写完，但 Security Review、Maintainability Review、Full Verification 还没结束，那我就不希望系统把它显示成“完成”。

## Plan 没有超级写权限

Reconciliation 做到这里，很容易给它加一条捷径：既然 Plan 已经知道要改什么，那直接让执行器 Patch 不就行了。

我没有这么做。

真正的文件修改仍然走 Workspace 原来的边界：

```text
Workspace root isolation
SHA-256 precondition
atomic write
symlink / hardlink safety
protected path policy
authorization
```

假设 Plan 是十分钟前生成的，这十分钟里我手动改了目标文件。

执行者拿旧 SHA 去写，照样失败。

Plan 不能因为“自己是计划”就压过现在的文件状态。

这条限制看起来会让自动化麻烦一点，但我觉得值得。

## 并行也没有直接全开

现在 `parallel_tools` 已经能处理不只是 Read/Discovery，也包括一部分独立的 Workspace Write。

但不是把一堆写操作扔进 Tokio 就结束了。

Scheduler 会先按路径做 Resource Model：哪些操作读同一个文件、哪些写同一个文件、Move / Delete / Create 有没有父子目录依赖。

独立的可以 fan out；冲突的先排序。

同一个文件上的 `apply_edits` 只有在 SHA 一样、Edit 本身不冲突时才会合并成一次原子提交。

这和 Reconciliation 的想法很接近：不是追求“看起来同时跑了很多东西”，而是先搞清楚哪些事情真的互相独立。

## Continuous Reconciliation 我现在还是很谨慎

“Reconciliation” 这个词很容易让人联想到 Kubernetes Controller：不停观察 Desired / Actual，然后自动把实际状态修回去。

wcode 确实有往这个方向走的设计，但我暂时不想让代码库也变成那种全自动 Controller。

软件修改和副本数不一样。

有些 Drift 很机械，可以自动发现；但“这里应该不应该改”“设计到底是不是变了”“这个抽象还值不值得留”，很多时候不适合无条件自动推进。

所以我目前更关心的是把：

```text
观察
计划
执行
验证
证据
```

这几段先做成可靠的状态。

自动化程度以后再加。

## 不同模型终于不用共享一段脑内上下文

这是我现在最喜欢 Reconciliation 的地方。

一个模型可以做 Implementation，另一个做 Security Review，再换一个看 Maintainability 或补 Test。

它们不需要彼此复述上一段 Chat。

只要都通过 wcode，看到的是同一个 Requirement、同一个 Plan、同一个 revision 和同一组 Evidence。

模型当然还是会有各自的判断差异，但至少“项目现在做到哪了”不必由模型自己记。

再往外一层，就是怎么把这些能力交给不同 Agent，而又不把权限和工作流混在一起。我把这部分写在 [MCP 负责能力，Skill 只负责工作习惯](/blog/wcode-mcp-agent/) 里。