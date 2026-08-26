---
title: "wcode：测试通过以后，我还想留下什么"
date: 2026-08-26T03:14:00+08:00
draft: false
url: /blog/wcode-verification/
description: "一句 tests passed 对长期项目不够。我想留下跑了什么、针对哪个 revision、谁 review 过、还有什么 gate 没过。"
tags:
  - Rust
  - Testing
  - wcode
  - AI Agent
images: []
---

Coding Agent 很喜欢用一句话结束工作：

```text
Tests passed.
```

以前我也觉得差不多够了。

后来 wcode 自己改得越来越大，这句话开始经常让我不放心。

到底跑了哪几个测试？是 quick 还是 full？测试的时候源码是不是当前 revision？有没有 Static Check？有没有 Mutation / Fuzz？两个 Reviewer 意见不一样怎么办？代码虽然能跑，但这次是不是又把一个文件堆大了几百行？

所以最近我把 Verification 单独往前做了一层。

## 最基础的还是项目自己的检查

`verify_project` 没有想发明新的测试框架。

Harness 先看项目实际有什么，再推导检查。

Rust 项目大概是：

```text
quick
  git diff --check
  cargo fmt --check
  cargo check --locked

full
  cargo test --locked
  cargo clippy --locked -- -D warnings
  cargo build --release --locked
```

Node 就看 `package.json` 里真实存在的 script，Makefile 也只跑确实定义过的 target。

这块我一直比较克制，因为“猜一个应该存在的命令然后执行”在 Agent 场景里不是好习惯。

## Risk 决定要不要继续往下走

`verify_project` 只是确定性基础检查。

再往上是 Verification Plan。

Plan 会根据这次变更的 Risk 决定要不要要求更多东西，例如：

```text
property
mutation
fuzz
runtime canary
human approval
independent reviewer
```

这些不是写在 Prompt 里的“建议最好跑一下”。

如果 Plan 要求它，它就是 Gate。

## Executor Registry 是因为每个语言都不一样

Property、Mutation、Fuzz 在不同生态里完全不是一回事。

我不想在 Verification 里写一堆 `if rust ... else if python ...`，所以做了统一的 Executor Registry。

现在会识别一批常见工具，比如：

```text
Rust      proptest / quickcheck / cargo-fuzz / cargo-mutants
Python    Hypothesis / mutmut
JS / TS   fast-check / Stryker
Java      jqwik / PIT
C#        FsCheck / Stryker
```

项目自己的验证程序也可以放到 `.wcode/executors.yaml`。

例如：

```yaml
schema_version: 1
executors:
  - id: service-canary
    stage: runtime_canary
    languages: [go]
    program: ./tools/check-canary
    args: [--environment, staging]
    cwd: .
    timeout_seconds: 60
```

这里有个安全问题不能省：这些东西都会执行仓库控制的代码。

以前我只有 `--allow-risky-exec` 这个粗开关。现在仍然可以这么启动，适合我已经明确完全信任仓库的时候；但也可以让某个具体的 semantic refresh / runtime executor 先产生本地 Authorization Request，在 TUI 里批准这次 Session 里的精确操作，再重试。

我更常用后者。

只是跑一次工具，就没必要把整个进程后面的 risky execution 一起放开。

## Maintainability 现在也是 Gate

这一块是后面补的。

我见过不少改动，测试全绿，功能也对，但代码明显开始往难维护的方向长。比如一个本来已经很大的文件又塞进去几百行，或者为了兼容一个特殊情况一路加 wrapper / branch，最后谁都不敢删。

`review_changes` 现在会先提供一些很笨但有用的结构信号：

```text
文件这次跨过 1,000 行
新增代码高度集中在一个源码文件
一次大改横跨多个 Product Scope
```

这些信号本身不能判定“代码烂”。

所以 Medium 及以上 Risk 的 Plan 还会创建一个独立的 maintainability reviewer。

它和 correctness reviewer 是两件事。

Correctness Pass 不能替它签字。

Maintainability Review 更关心的是：有没有更简单的做法、有没有散落的 special case、有没有多余的抽象层、有没有重复已有 helper、边界是不是开始泄漏。

我不想用“测试通过”给这些问题盖章。

## Reviewer 第一轮看不到别人怎么说

Verification Plan 可以创建多个独立 Reviewer Job。

第一轮是 Blind Review。

Reviewer A 不会先看到 Reviewer B 的结论。

这个设计不是为了做什么复杂的多 Agent 社会实验，只是因为锚定效应太明显了。第二个 Reviewer 如果先看到第一个写着 Pass，经常会很自然地开始找理由支持它。

如果最后一个 Pass、一个 Fail，wcode 不会算票数。

会留下：

```text
Disagree
```

争议就是争议。

我宁愿停下来处理，也不想系统替我把它平均掉。

## 真正想留下的是 Evidence

Verification 最后要落成 Evidence。

不是一句文本，而是带上下文的记录：

```text
producer
model
code revision
design revision
verification policy
result
confidence
timestamp
```

代码 revision 变了，旧 Plan 会被 stale blocker 卡住。

不同 Stage Producer 也各自保留最新结果，一个 Runner 的 Pass 不会去覆盖另一个 Runner 的 Fail。

现在 Stage 聚合是偏保守的：

```text
Fail > Disagree > Inconclusive > Pass
```

验证系统如果非要选一个方向，我宁愿它烦一点，也别太乐观。

## 这些运行状态没有塞进 Git

Evidence、Verification Plan、Reviewer Job 这类状态会按 Workspace 持久化，但放在 wcode 自己的用户级 State 目录，不写进仓库。

原因也简单。

Git 里我想保留代码和 Design State。每跑一次测试都改仓库，只会制造一堆没必要的 Commit / Artifact 噪音。

模型断开或者 wcode 重启以后，这些状态还能重新加载。

这也是我后来开始做 Reconciliation 的前提：如果验证结果本身都只活在聊天里，那“换一个模型继续做”其实没有稳定交接面。

Evidence 能留下来以后，长任务才有可能真正跨 Session 继续。也就是从这里，我开始认真做 [Reconciliation](/blog/wcode-reconciliation/)。