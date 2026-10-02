---
title: "wcode 0.9.0: getting multi-agent work organized"
date: 2026-10-02T21:45:00+08:00
draft: false
url: blog/wcode-v0-9/
aliases: ["/blog/wcode-parallel-work/"]
images: ["/img/share/wcode-v0-9.en.png"]
translationKey: wcode-v0-9
image: /img/wcode/wcode-logo.svg
description: "Scoped task claims, reusable handoffs, and a workbench that connects current problems to source and checks: what I am building in wcode 0.9.0."
tags:
  - wcode
  - Rust
  - Coding Agent
  - Multi-agent
---

[![wcode](/img/wcode/wcode-logo.svg)](https://wcode.francis.run/)

I have been working on several projects in parallel, with agents handling backend fixes, interface work, and PR review. Splitting the work helps. Bringing it back together takes care: which files did each agent change, which results are still useful, and has anyone checked the combined version?

That is much of what I am working on in wcode 0.9.0.

For anyone new to the project, wcode is a set of repository tools I am building in Rust. It connects to an existing coding assistant through MCP and helps it read source, find code, edit files, and run checks. Tasks, file revisions, and verification results stay with the repository workflow, so another model can pick up from them.

[Version 0.8](/en/blog/wcode-v0-8/) organized code graphs, architecture, and evidence. In 0.9, I want to make the daily work easier to coordinate and follow.

## Assign the files along with the task

Giving three agents implementation, tests, and documentation sounds clear enough. They may still all end up editing the same file.

In 0.9, Worklist tasks can declare their write scope. An interface task might own `src/ui/`, a backend task `src/runtime/`, and a review task an empty `write_paths` array for read-only work. Claims check dependencies and the current revision. If another active claim has an overlapping write scope, the new claim is rejected.

A worker calls `worklist_claim` to receive its own claim token and handoff package. Claims have a 15-minute lease that longer tasks must renew. Workers use `worklist_submit` to return bounded results and references to evidence they have already produced, giving the lead agent something concrete to collect.

The host still launches the agents. Codex or Claude Code can use its own model and worker support; wcode keeps the coordination state.

A claim also keeps the existing file and command checks. Owning a task for `src/ui/` does not remove SHA preconditions or grant command access. If another session changes a file, the worker has to read it again before editing.

This becomes useful when several sessions are active in one repository. The assignment, conflict, and revision being handed back are all visible.

## Open the workbench and see what needs attention

wcode already had architecture, code relationships, tasks, and verification views. Deciding what to do next still meant moving between them.

Version 0.9 brings current problems into one attention list: failed checks, unfinished verification, conflicting evidence, missing design mappings, and risks needing another look. Each item leads into the relevant task, source, or verification view.

![The wcode 0.9.0 project workbench](/img/wcode/wcode-v0-9-overview.png)

*The 0.9.0 development interface, shown with demonstration project data.*

I want the first screen to make a few things easy to find: what is blocked, who is working on it, and which result should I open? The complete graph, history, and detailed metrics are there when I follow a problem further.

The workspace, source revision, and snapshot state stay visible across pages. A refreshing cache or unavailable provider is shown as such, so I can tell what the page actually knows.

The terminal observatory also has overview, attention, task, provider, and agent navigation. Smaller windows prioritize tasks and recovery controls, with details available separately. Those are the things I want to notice when the terminal stays open beside my work.

## Read source without mixing revisions

Some questions eventually need the code itself.

The file tree and large-module entries can open actual source with bounded line paging. Pages are tied to the original source SHA. If the file changes before the next page, the viewer requires a fresh read.

Suppose I am inspecting a function while another agent changes the second half of its file. The next page must not silently append the new revision. That would look like one complete file while combining two different moments.

Changing the workspace or query also invalidates old responses. A request arriving late cannot overwrite the view I have just opened. The source viewer needs to take revisions as seriously as editing does.

## Repeat less context during handoffs

Another cost of multiple agents is explaining the same repository repeatedly.

Starting each worker with another scan, another introduction, and another tool search spends context on information already collected. The 0.9 handoff can reuse valid task context and fetch only what is missing or stale.

Tool information has been trimmed too. Standard tool names and necessary arguments remain; reconstructible routing information and repeated default-workspace guidance need fewer copies. Source bodies, SHAs, relevant checks, and failures stay available.

The useful question is whether an agent can get back to work with that package. Removing fields only to make it ask another question and reread the file saves little.

This round also addresses waiting under concurrency. Identical verification work can share an execution, while record-store contention is isolated by workspace. Writing one repository's records should not hold up another repository's query.

## Check the version that comes back together

Collecting completed worker reports leaves one more job.

Each task tested its own version. Another worker may subsequently have changed related files. The lead agent needs to review and verify the combined current code. Earlier passing results are useful references, but cannot approve that new version.

Change Acceptance is being developed into a readable record of the current Git revision, project requirements, checks actually run, and what is still missing. The implemented local workflow can report concrete blockers. Team workflows and remote merge integration still need deployment acceptance.

When a change is ready to merge, I want to follow its record to the checks behind that decision, without asking every worker once more whether it is really finished.

The source version is now **0.9.0**. The latest public package is still **0.8.5**, and 0.9.0 remains under pre-release verification. Follow progress on [GitHub](https://github.com/francis-du/wcode), find setup instructions on the [project website](https://wcode.francis.run/), or read the [0.9.0 feature notes](https://wcode.francis.run/docs/releases/v0.9.0/).
