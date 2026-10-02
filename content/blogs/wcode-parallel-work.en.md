---
title: "Running wcode in parallel exposed a few small problems"
date: 2026-10-02T21:45:00+08:00
draft: false
url: blog/wcode-parallel-work/
images: ["/img/share/wcode-parallel-work.en.png"]
translationKey: wcode-parallel-work
image: /img/wcode/wcode-logo.svg
description: "A round of parallel agent work led me back to validation waits, framework discovery, and repeated root scans in wcode. Small details, with a noticeable effect on everyday use."
tags:
  - wcode
  - Rust
  - Coding Agent
  - Concurrency
---

[![wcode](/img/wcode/wcode-logo.svg)](https://wcode.francis.run/)

[Website](https://wcode.francis.run/) · [GitHub](https://github.com/francis-du/wcode)

Recently I put several Rust projects through a round of parallel agent work. Each agent took a project, repaired existing PRs, added regressions and negative controls, and worked through the unfinished pieces.

It was a useful workout for wcode. It was also fairly unforgiving.

A request that completes on its own tells you little about what happens when several agents ask for context, discover checks, and validate caches at once. The user sees a loading indicator. Underneath it, several layers may be waiting on each other.

Three changes from that round are worth recording. The implementation is in [PR #4](https://github.com/francis-du/wcode/pull/4).

## A waiting caller can still occupy a slot

wcode coalesces some validation work for the same project. Rebuilding the same thing for several callers would be wasteful.

The awkward case is a follower that already holds a tool slot while it waits for the validation owner. The owner may itself be suspended behind work in another pool. Each local piece looks reasonable; the combination can stop making progress.

Ordinary native callers now wait for at most five seconds. They receive an explicit busy error after that and can retry later. A Rayon worker does not wait at all: keeping a limited pool's workers blocked would make the dependency harder to resolve.

The owner keeps its lock and its actual-work permit. A follower timing out does not cancel the owner's validation or make a cached result valid. Success still comes from completed work.

The code lives in [`cache_flight.rs`](https://github.com/francis-du/wcode/blob/4bccc0ca443a6d392dae903841d55fb890eabe15/src/runtime/harness/cache_flight.rs). The regressions also check recovery: later callers must be able to get through after the congested followers leave.

## Documentation crowded out the source evidence

The next bug needed no complicated scheduling.

wcode looks for uses of frameworks such as `proptest`, `hypothesis`, and `quickcheck`, alongside dependency declarations, when discovering advanced checks. That discovery used a text-search result list capped at 1,000 rows.

I built a tiny fixture with 1,100 mentions in a Markdown file, followed by the Rust and Python files that actually imported the frameworks. The documentation filled the result prefix. Source usage never reached discovery.

The same problem can cross language boundaries. Many Rust hits for `quickcheck` could hide a single R use of the same name.

Discovery now retains a much smaller fact: a query occurred in a particular source language. Repeated lines do not compete for room. Ordinary text search keeps its pagination; only framework discovery uses the query-and-language evidence path.

That scan also stays on a dedicated bounded I/O pool. One regression deliberately fills the global Rayon pool before asking discovery to finish. An accidental dependency on the global pool becomes a visible failure.

The negative control is straightforward. Restore the old discovery code and the noisy-documentation fixture fails. Restore the fix and the identical fixture passes. That tells me more than a test asserting that one clean file contains `proptest`.

## Do not rediscover a root within the same request

A workspace may contain separate Rust, Python, and Node projects. Provider ownership matters: a tool available in one island cannot automatically be reported as runnable in another.

I found a repeated scan in that aggregation. wcode discovered the workspace, then discovered it again while processing the `.` root. Two duplicate `.` declarations meant three scans in one request.

The aggregate now reuses its own root result. Nested projects still get separate discovery. Tests compare providers, gaps, and truncation as well as counting calls, so removing work cannot silently remove information. The duplicate-root fixture now performs one discovery.

I kept this reuse inside the request. A tool might have just been installed or a manifest edited. Removing the duplicate work did not require another long-lived cache with another freshness rule.

## Windows found a path representation mismatch

The OSS ownership checks surfaced a separate Windows issue. They canonicalized a compile target before comparing it with the checkout. Different path representations could make a legitimate source file appear to be outside the repository.

Both sides now get canonicalized before the boundary comparison. An actual external source remains rejected.

Packaging then found a smaller difference: `cargo package --list` returned backslash-separated paths on Windows, while the test looked for `src/lib.rs`. The package had been created successfully, but the check reported a missing file. [This follow-up commit](https://github.com/francis-du/wcode/commit/cee9059e701655c55cae9c47520f7c7c9c14b2e8) normalizes separators only for list membership. The source boundary checks stay intact.

The concurrency regressions retain their original load: 16 requests per operation and the existing 40-second mixed-request deadline. A failure is a reason to inspect the wait, rather than move the deadline.

The final concurrency-fix library suite passed 1,863 tests on macOS, with seven existing manual tests ignored. Linux, macOS, Windows, and OSS packaging have their own CI runs, linked from the PR. This is a pre-release development record; a local pass does not stand in for acceptance on every platform.

What I want from parallel work is fairly practical. The interface should be able to tell me who is running, who is waiting, and who needs to retry. Adding slots is less useful if it only adds more agents staring at the same loading indicator.
