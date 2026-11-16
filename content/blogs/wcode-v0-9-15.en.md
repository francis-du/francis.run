---
title: "Catching Up on wcode: 0.9.0 to 0.9.15"
date: 2026-11-16T23:25:00+08:00
lastmod: 2026-11-16T23:25:00+08:00
draft: false
url: blog/wcode-v0-9-15/
translationKey: wcode-v0-9-15
author: "Francis Du"
image: /img/wcode/wcode-logo.svg
images: ["/img/share/wcode-v0-9-15.en.png"]
description: "What changed across wcode 0.9.1–0.9.15: evidence tied to revisions and policy, honest unknown states, an investigation workbench, recoverable tasks, and less repeated context work."
tags:
  - wcode
  - Rust
  - Coding Agent
  - Verification
---

[![wcode](/img/wcode/wcode-logo.svg)](https://wcode.francis.run/)

The last [release post](/en/blog/wcode-v0-9/) covered 0.9.0 on October 2. Code and documentation kept moving; the blog fell behind. As of November 16, the latest public release is **0.9.15**. This post catches up on the fifteen patch releases in between.

In 0.9.0 I wrote about task claims, change acceptance, and the workbench. The questions became more specific as work continued. Does a passing check still apply after the Git index changes? Why does an unmeasured duration appear as 0 ms? Why does selecting a file reveal the file area without finding the actual file?

Much of this round went into those details. They affect whether someone can trust the interface and whether the agent repeats work it has already done.

If the project is new to you, start with the [introduction](/en/blog/what-is-wcode/). wcode is written in Rust and exposes repository tools to coding assistants through MCP; your assistant still supplies the model. The scope here is the published 0.9.15 release. Later main-branch and development-branch changes are separate.

## Work out which checks still count

A passing check comes with conditions: the code and design it examined, the policy it ran under, where its evidence came from, and whether that evidence is still available.

Version 0.9.8 supplied real project data that the design-consistency view had been missing. Browser fixtures included acceptance criteria and constraints, but the live snapshot did not carry all those fields. The interface had rows for them, yet a real session could keep showing absent declarations and plans. A convincing fixture can hide an incomplete connection to the backend.

A requirement can now lead to its acceptance criteria and individual checks: whether a check is mapped, whether it ran, its outcome, and whether its result still applies. A declared check with no execution result remains visible.

Version 0.9.9 tightened several evidence decisions. Consider `git add`: source files may remain identical while the index changes. An empty commit can change HEAD. Comparing only code and design content misses part of the Git identity used by acceptance.

Where a workspace has a Git identity, a verification plan now checks that the evidence record and receipt match it. Results produced under a different policy cannot satisfy the current plan merely because the source stayed the same. If a reused result's original evidence is no longer visible in retained history, it cannot keep appearing as a current pass.

Reports also distinguish checks actually executed in this run from reused results. Reuse is useful; the reader needs to know how the result was obtained.

The details are in [0.9.8](https://wcode.francis.run/docs/releases/v0.9.8/) and [0.9.9](https://wcode.francis.run/docs/releases/v0.9.9/).

## An absent observation is not a measured zero

One recurring bug was the interface turning missing data into a definite-looking number.

| Situation | What the interface should say |
| --- | --- |
| No timing observation for a check | Duration unknown |
| No diff line-count observation | Added and removed counts unknown |
| No samples or usable denominator | No percentage available |
| A check is declared but has no execution record | Result missing |
| A verification plan belongs to another revision | Superseded |
| A command has no structured failure location | No specific source line available |

A measured 0 ms and an absent timer are different observations. Showing the same zero makes it too easy to read “not observed” as “nothing wrong.”

Versions 0.9.8 through 0.9.12 carried this distinction through check timing, task counts, graph coverage, change statistics, and evidence state. Percentages keep their own numerators and denominators so the number remains attached to what it measures.

Graph views need an identity too. A view selected as “latest” becomes stale when a newer snapshot arrives. A deliberately pinned historical snapshot can remain on screen, provided it keeps its historical identity.

I want the state to be specific enough to act on: a check that never ran, a failed execution, and an outdated result each need a different next step.

## Follow a problem through to the code

The workbench changed substantially. The practical question was whether a problem could lead to the next useful piece of evidence.

Version 0.9.3 added symbol outlines, definition ranges, and line navigation to the code reader. Changed definitions with explicit requirement mappings can show the corresponding requirement. The precision boundary remains: overlap between a diff range and a symbol establishes a location relationship, not complete semantic impact.

Version 0.9.7 connected the command palette and navigation to specific objects: requirements, components, files, jobs, evidence, and symbols. Investigation locations enter the URL hash, allowing back and forward navigation.

By 0.9.12, the layout had an object navigator on the left, the current view in the centre, an inspector on the right, and shared Problems, Jobs, Logs, and Evidence drawers below. A failure can lead to a job's output and back to source. Workspace, revision, and connection identity have their own place and remain visible on narrower screens.

Version 0.9.15 fixed a small but irritating navigation failure. Selecting a file now scrolls to and focuses its actual tree entry. A filter hiding that target is cleared; a target beyond the collapsed first page causes the relevant entries to become visible.

The file tree initially renders **200 entries**, states how many are shown, and offers an explicit expansion control. A large repository does not need every tree node inserted into the page immediately. Changing the query or workspace resets expansion so old view state does not interfere with new results.

See [0.9.12](https://wcode.francis.run/docs/releases/v0.9.12/) and [0.9.15](https://wcode.francis.run/docs/releases/v0.9.15/) for the interaction changes. Screenshots in older posts still describe their original releases.

## Leave enough state to resume a long task

A long task may outlive a model session, a page refresh, or a connection. On return, someone needs to know what is running, what finished, what failed, and which dependencies remain.

Versions 0.9.1 and 0.9.2 worked on retained jobs, source filters, output search, and re-observation by task ID. After a connection interruption, the useful recovery action is to read the original task's result. Starting the command again because its output is missing can turn one connection problem into two running jobs.

Version 0.9.11 fixed a different retention problem. Trimming history by a global count could remove the last snapshot of a less frequently updated plan. Claimed or completed work could then appear to be Pending again. Retaining each plan's newest snapshot preserves somewhere to recover that progress.

Version 0.9.13 added explicit plan-to-Worklist associations with ID validation. Steering that changes the objective or scope requires replanning while preserving the existing approval boundary.

Version 0.9.14 brought requirement convergence into the home view and terminal observations: stable, changing, and needing work. That makes the distribution of unfinished work visible before opening the consistency matrix.

Persistent state helps the next worker continue. A worker's completion report still needs verification evidence for the relevant revision.

## Move less context and repeat less computation

Most of the performance work removed repetition.

Versions 0.9.4 through 0.9.6 reduced repeated lowercase-string construction and unnecessary allocation in graph queries, diff ordering, and repository mapping. Version 0.9.7 made several heavy state tools return summaries by default, explicitly identifying omissions and where to retrieve more detail.

The first response should contain enough to choose the next action. Source bodies, editing SHAs, failures, and required constraints still have explicit retrieval paths.

Version 0.9.12 reused cached graph snapshots instead of repeatedly deep-copying them. In 0.9.14, context compaction started reusing a byte count already measured by the caller, avoiding repeated serialization during each step. Candidate ranking also computes a key once before sorting.

These changes explain work the tools no longer perform. Measuring whole-task latency or a model bill requires fixed tasks, models, and execution conditions. Serialized JSON bytes from a release diagnostic do not directly measure provider tokens or task success.

The [release index](https://wcode.francis.run/docs/releases/) links the implementation details; this post does not need to reproduce every allocation and loop.

## Writing the evidence contract down as a paper

I also wrote this up in a preprint dated November 6, [WCode: Revision-Bound Evidence for Stateful Software Agents](https://wcode.francis.run/docs/paper/), under my name, Francis Du.

The question is what a result must carry before it can support the current software change: its subject, producer, coverage, policy, and code–design revision.

The diagnostic used 60 developer-authored synthetic scenarios in four languages. Across response budgets, cache phases, and repetitions, it produced 2,520 measured calls. It also replayed 22 selected contract counterexamples and checked eleven operational controls.

That scope matters. The experiment examines selected runtime contracts. It does not establish independent real-repository issue-resolution rates or comparative success rates for complete agents. The paper is bound to the retained November 6 experiment; later capabilities described in this post cannot be attributed to that measured revision.

The page provides English and Chinese PDFs, LaTeX sources, build instructions, and checksums for anyone who wants to inspect the experiment.

## Check the running process after an upgrade

For a normal upgrade, inspect the installed version and run:

```bash
wcode --version
wcode update
wcode --version
```

`wcode update` selects the latest stable release available when it runs. To pin 0.9.15, use that version's [release downloads](https://github.com/francis-du/wcode/releases/tag/v0.9.15) and matching `SHA256SUMS`. The update command has no `--version` option.

After replacing the executable, reconnect the MCP host. For a separate service, inspect active jobs before arranging a restart. Check the new process's executable path and version to establish which installation is actually running.

Permissions also need to be read against the current documentation. Command policy and authorization are permissive by default in these releases; early descriptions should not be read as a promise of approval for every command. An operating-system sandbox is selected per call, and an unavailable backend can fall back to direct execution. The documented combination for passive inspection is `--read-only --no-exec --no-semantic`; `--no-exec` still overrides session command grants. Workspace file boundaries, guarded edits, and command execution controls have separate roles. The [security reference](https://wcode.francis.run/docs/security/) explains their configuration.

The 0.9.15 release also moves `rustix`, `quinn-proto`, and `quinn-udp` to patched versions. Published source, platform archives, and installed services have separate states; inspection needs to reach the version actually being used.

## Release links for this stretch

| Releases | Main changes |
| --- | --- |
| [0.9.1](https://wcode.francis.run/docs/releases/v0.9.1/)–[0.9.2](https://wcode.francis.run/docs/releases/v0.9.2/) | Upgrades and reconnection, retained jobs, output search, observation recovery |
| [0.9.3](https://wcode.francis.run/docs/releases/v0.9.3/)–[0.9.7](https://wcode.francis.run/docs/releases/v0.9.7/) | Change and symbol navigation, graph-query overhead, default summaries |
| [0.9.8](https://wcode.francis.run/docs/releases/v0.9.8/)–[0.9.9](https://wcode.francis.run/docs/releases/v0.9.9/) | Live design-consistency data, per-check acceptance, evidence identity and policy |
| [0.9.10](https://wcode.francis.run/docs/releases/v0.9.10/)–[0.9.12](https://wcode.francis.run/docs/releases/v0.9.12/) | Explicit unknown observations, retained plan state, investigation workbench |
| [0.9.13](https://wcode.francis.run/docs/releases/v0.9.13/)–[0.9.15](https://wcode.francis.run/docs/releases/v0.9.15/) | Plan/task associations, replanning after steering, requirement convergence, precise file navigation |

[Source](https://github.com/francis-du/wcode) · [Documentation](https://wcode.francis.run/docs/) · [Release history](https://wcode.francis.run/docs/releases/) · [Paper](https://wcode.francis.run/docs/paper/)
