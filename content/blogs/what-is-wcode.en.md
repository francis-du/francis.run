---
title: "What wcode Is: A Local Runtime for Coding Agents"
date: 2026-09-12T05:41:00+08:00
draft: false
url: blog/what-is-wcode/
image: /img/wcode/wcode-architecture.png
description: "wcode is a Rust runtime for coding agents. It handles local repository access, code intelligence, guarded edits, permissions, verification evidence, and project state while leaving the model and chat client up to you."
tags:
  - wcode
  - Rust
  - MCP
  - Coding Agents
  - Developer Tools
images:
  - /img/wcode/wcode-architecture.png
---

<p class="project-logo"><a href="https://wcode.francis.run/" target="_blank" rel="noopener" title="wcode documentation"><img src="/img/wcode/wcode-logo.svg" alt="wcode" width="320" height="96"></a></p>

<p class="project-links"><a href="https://github.com/francis-du/wcode" target="_blank" rel="noopener">GitHub ↗</a><a href="https://wcode.francis.run/" target="_blank" rel="noopener">Docs ↗</a></p>

wcode started because I was tired of moving code between a browser and my editor.

I already had AI products I liked using. The annoying part was local repository access: copy a file into chat, upload an archive, switch to a different coding client, or configure another API key just so a model could inspect the same code that was already on my machine.

The first version of wcode was basically a bridge: a local workspace over MCP, with authentication and file boundaries around it.

Once I started letting agents make real edits, most of my bugs and design work moved somewhere else. I needed to know which revision an agent had read, whether a symbol result came from Tree-sitter or a language server, whether two edits could overlap, and whether a test result still belonged to the current code.

That is where the project spends most of its time now.

## How I think about wcode now

**wcode is a local runtime and engineering harness for coding agents.**

The model can live in ChatGPT, Claude, Codex, or another MCP-capable client. wcode stays on the machine with the repository and handles the parts that should be local and inspectable.

```text
ChatGPT / Claude / Codex / another agent
                  │
                  │ MCP
                  ▼
┌──────────────────────────────────┐
│              wcode               │
│                                  │
│ Workspace / Auth / Permissions   │
│ Search / Tree-sitter / LSP       │
│ Guarded edits / Git / Commands   │
│ Design State / Verification      │
│ Evidence / Observatory           │
└────────────────┬─────────────────┘
                 │
                 ▼
          local repository
```

I want that layer to stay useful when I change models. Repository boundaries, edit safety, indexing, and verification should not need to be rebuilt every time the model on the other end gets better.

## Repository access with an actual boundary

A path mentioned by a model is not permission to access it.

wcode works inside configured workspaces. File operations reject common escape paths and protected locations, and edits to existing files use the SHA of the version the agent actually read. If I change a file while the model is thinking, an edit based on the stale SHA fails instead of overwriting my newer work.

The same idea applies to commands. A command can be safe, blocked, or require an exact local approval depending on its shape. Approval is attached to the real operation rather than a vague “the agent can run commands now” switch.

I do not expect models to be the authority on their own permissions.

## Code intelligence has more than one precision level

Tree-sitter is cheap and useful for outlines, definitions, ranges, and syntax-level relationships. It is also not a compiler.

When a task needs cross-file references, implementations, call hierarchy, or similar semantic information, wcode can use the language server installed for the project. Results keep their provider and revision information so a syntax result is not presented as compiler-grade fact, and stale semantic state can be rejected after source changes.

I have been bitten enough by confident answers built on the wrong precision level that I keep this metadata visible.

## `agent_context` is the entry point I use most

For me, the useful part of context is having the right files and constraints ready before the first edit.

For a concrete task, `agent_context` builds a bounded package around what the agent is about to do. It can include the likely target files and their SHAs, repository guidance, Design State, semantic-provider readiness, active work, verification hints, and dependency lanes that are safe to run in parallel.

If a compiler diagnostic already points at a file and line, wcode starts there instead of paying for a repository-wide search first.

## Parallel work follows dependencies

I spent a fair amount of time optimizing the wrong number: tool slots.

A high slot count looks good on a dashboard, but it does not tell me whether useful work finishes sooner. wcode now separates outer tool admission, CPU work, bounded file I/O, child processes, and Git probes. The scheduler starts a successor when its own dependencies are ready rather than waiting for unrelated work in the same batch.

Independent reads can overlap. Conflicting writes do not race. A build does not get to consume every resource simply because there are free outer slots.

That model has been much easier to reason about than “turn concurrency up until the graph looks busy.”

## Verification belongs to a revision

A line saying `tests passed` is almost useless after a long editing session unless I know which code it describes.

wcode records verification as evidence tied to code and Design State revisions. It can distinguish a test that is mapped to a requirement from one that was actually executed, passed, and is still fresh for the current source.

If the repository changes after verification, the old result does not silently become proof for the new version.

![wcode Project Observatory](/img/wcode/wcode-observatory-full.png)

I spend a surprising amount of time on this because patch generation is rarely the part that fails late in a long session. Stale or over-broad verification is.

## Design State gives the repository a memory outside the chat

Source code describes the implementation you have. It does a poor job of describing every constraint you intended to preserve.

wcode can keep requirements, components, constraints, and acceptance criteria under `.wcode/` in the repository. That Desired State is available to context retrieval, impact analysis, drift detection, and verification mapping.

I now use it on this blog too. The repository records things such as:

- Chinese stays at root and English stays under `/en/`;
- the photography Gallery has its own rendering and JavaScript lifecycle;
- technical posts should not turn into generic AI-sounding copy;
- template changes need a real Hugo build, not only a clean diff check.

I trust those rules more when they live beside the code than when they only exist in an old chat.

## Where I use wcode

The first use case is still the one that started the project: connecting a web AI product to local code over MCP. The model stays in the product I already use; wcode provides the local repository tools.

I also use it as a harness for local coding agents. Search, guarded edits, permissions, project context, verification, and evidence do not need to be reimplemented by every agent loop.

The third case is long-running work across a real codebase. Stale context, conflicting edits, invalidated tests, and handoff state become much more noticeable after dozens of tool calls. Most of the recent wcode work is aimed there.

## What wcode does not try to own

wcode does not ship a model and it does not try to decide which model you should use.

It also does not need to own the chat UI or your conversation history. Provider rate limits, context limits, and subscription rules still belong to the provider you are using.

Its job is the local side of the connection: repository state, tools, authority, and evidence.

I change models often enough that I want the local repository layer to stay boring and predictable.

## Trying it

The source is here:

[github.com/francis-du/wcode](https://github.com/francis-du/wcode)

Installation, host setup, and the current command reference live here:

[wcode.francis.run](https://wcode.francis.run/)

After installing wcode, the normal starting point is:

```bash
wcode setup
```

For the full command surface, including advanced options:

```bash
wcode help-all
```

If you are only trying to decide whether the extra runtime layer is useful, I would start with a repository you already know well. Give an agent one complete task that requires finding code, editing it, and verifying the result. That shows the difference much faster than reading a feature list.
