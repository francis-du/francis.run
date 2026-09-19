---
title: "wcode 0.6.2: What 32 Tool Slots Were Hiding"
date: 2026-09-12T05:35:00+08:00
draft: false
url: blog/wcode-v0-6-2/
image: /img/wcode/wcode-observatory-full.png
description: "I split tool slots, CPU, file I/O, and child processes into separate budgets, then fixed a few places where wcode looked healthier or busier than it really was."
tags:
  - wcode
  - Coding Agents
  - Rust
  - Performance
  - Observability
  - Release
images:
  - /img/wcode/wcode-observatory-full.png
---

I spent several days watching wcode sit at 32 tool slots with decent peak occupancy while a few real tasks still felt slow.

After tracing the queues underneath that number, I stopped treating slot utilization as a performance signal. A slot only says the request got in. CPU work, file I/O, compilers, Git probes, and language servers can still be waiting somewhere deeper.

0.6.2 grew out of that debugging pass. I changed the resource model, then fixed a few other places where the runtime was reporting something cleaner than the underlying state really was.

![wcode Project Observatory](/img/wcode/wcode-observatory-full.png)

## Tool slots are not CPU cores

The outer `SLOTS` counter only means a tool request has been admitted. It does not tell you whether a CPU worker is executing useful code, a filesystem operation is waiting on storage, or a child process is queued behind another compiler.

0.6.2 makes those layers more explicit:

```text
Tool admission
      ↓
Foreground CPU budget
      ↓
Bounded file-I/O workers
      ↓
Child-process / Git probe queues
```

Foreground CPU parallelism is bounded by hardware, memory-derived limits, a small runtime ceiling, and request concurrency. Blocking work has its own bounded capacity. Independent file modifications use a shared I/O pool. Fixed, read-oriented Git probes have a separate queue from heavier repository processes.

Starting twenty compilers at once is usually a good way to make one workstation slower, so those inner limits stay deliberately small.

## I removed an optimization that benchmarked worse

One experiment moved more read work onto a wider thread pool. It looked like the kind of change that should increase throughput.

In the local paired workload it was slower, so I reverted it.

I kept the revert. A wider pool is only an optimization if the paired workload actually improves.

I also avoided putting an “X% faster” number on the release. Repository size, storage, dependency shape, language servers, and compiler behavior move the result too much for one number to mean much.

## Keep lightweight tools alive under command pressure

There is another failure mode in agent runtimes: a queue of expensive commands consumes every outer tool slot, then the agent cannot even perform a lightweight read or status query needed to understand the queue.

Execution-class requests in 0.6.2 pass through an additional admission layer before taking the global tool capacity. With the normal 32-slot configuration, command-like work cannot consume all 32 slots; a small amount of capacity remains available for non-execution tools.

This does not guarantee fixed latency under every kind of saturation. It does prevent one very avoidable form of self-starvation.

## A compiler location should beat a repository-wide search

Performance is also about doing less work.

Suppose the model already has this diagnostic:

```text
error[E0308] at src/runtime/harness/context_budget.rs:33:9
```

Older retrieval paths could still begin with broad repository symbol discovery and only later prioritize the explicit location.

That ordering is backwards.

`agent_context` now recognizes bounded file-and-line anchors first. It resolves them through the workspace safety boundary, preserves the source text and file SHA needed for safe editing, and can defer unnecessary repository-graph expansion for simple location-driven tasks.

Cross-file callers, impact analysis, architecture questions, and explicit product-scope queries still use the deeper graph and semantic paths.

So a file-and-line diagnostic now wins the first retrieval step. The broader graph only comes in when the task actually needs it.

## Concurrent cold queries should share index construction

Multiple agent branches can ask about the same uncached file at nearly the same time.

Without coordination they can all notice the cache miss and independently build the same index.

0.6.2 shares an in-flight index build for the same workspace and file. Different files can still build independently. Invalidation updates the build generation so an old result that finishes late cannot quietly repopulate stale state.

I did not add incremental parsing here. This change only deduplicates the same cold index build.

## `symbol_context` now checks that its own pieces agree

A more serious version of the same problem appears when a symbol index and the source text come from different file revisions.

A response can look perfectly structured while combining an old signature with new source lines.

`symbol_context` now checks the source identity used by the symbol fact against the content it is about to return. If the index is stale it can refresh once. If the file keeps changing and a stable answer cannot be produced, the operation fails explicitly.

I would rather return “unstable source” than a polished contradiction.

## Complete verification plans or no verification plan

A mixed-language repository can derive a surprisingly large set of checks.

One older path silently limited a plan to the first eight checks. That is dangerous because the executed prefix can still look like a complete verification report to a higher layer.

0.6.2 constructs and sorts the complete plan first, with a bounded maximum of 32 checks. If the plan exceeds that bound, the request fails before dispatch. It does not execute a partial prefix and call it full verification.

Within a request, verification history also shares a source/design revision snapshot instead of repeatedly rescanning the same state for every planned check.

Evidence remains scope-aware: a narrow success cannot erase a broader failure, and missing or truncated evidence is not interpreted as a pass.

## Verification can be a durable MCP task

`verify_project` now reuses the existing persistent Tasks runtime when the client advertises the MCP Tasks extension.

The server can persist the task and return a `taskId` before waiting for the full verification workload. The authenticated owner can query that same task later, even after the creating request has ended.

A dropped connection does not cause automatic replay. A restarted runtime does not pretend an interrupted operation completed. Already-started blocking work is not advertised as transactionally rollbackable.

That distinction matters once commands can have side effects. A missing response tells me nothing about whether the command already started or finished.

## Configuration needed to become smaller again

As wcode accumulated resource controls, the advanced CLI became useful for debugging but unfriendly as a default setup surface.

0.6.2 introduces three practical performance profiles:

```text
balanced
fast
light
```

You can preview before writing configuration:

```bash
wcode setup --performance fast --dry-run
wcode --show-config
```

Advanced overrides still exist, but a normal user no longer needs to understand every internal queue before choosing a sensible starting point.

The release also adds:

```bash
wcode help-all
wcode help-all setup
wcode help-all --json
```

This catalog is generated from the real CLI parser, including advanced options, aliases, defaults, and enumerated values. Normal help stays compact; complete discoverability has a separate entry point.

## I cleaned up the Observatory first screen

The Project Observatory received another structural pass.

The first screen now separates active execution, pending approvals, worktree changes, and verification evidence that is valid for the current revision. Architecture navigation starts from searchable component cards and a detail inspector, while Design / Implementation / Overlay graphs remain available for deeper inspection.

Fast activity refreshes are separated from slower project refreshes. Hidden pages stop polling. Shared process resources are labeled separately from work that belongs to the selected project. An unavailable sample is not rendered as zero.

The main rule for the UI is boring: if wcode did not sample something, it should say unknown instead of drawing a zero.

## What I kept from this release

I now check a few distinctions explicitly when changing the runtime:

- slot count is not throughput;
- a mapped test is not an executed test;
- task completion is not a passing verification result;
- a missing response is not proof that nothing happened.

0.6.2 is mostly a pile of fixes around those details. None of them is a headline feature, but they make the runtime easier to trust when a coding session gets long.

The code is at [github.com/francis-du/wcode](https://github.com/francis-du/wcode), and the current documentation is at [wcode.francis.run](https://wcode.francis.run/).
