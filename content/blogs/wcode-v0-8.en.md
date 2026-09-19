---
title: "wcode 0.8: I Started Treating the Repository as an Engineering Digital Twin"
date: 2026-09-19T15:33:00+08:00
draft: false
url: blog/wcode-v0-8/
translationKey: wcode-v0-8
image: /img/wcode/wcode-intro-intelligence-stack.svg
description: "In 0.8 I stopped adding isolated agent tools and started pulling architecture, code relationships, the Decision Plane, Engineering Fitness, and verification into one evidence-aware engineering view. The current release is 0.8.1."
tags:
  - wcode
  - Rust
  - Coding Agents
  - Engineering Digital Twin
  - Decision Plane
  - Release
images:
  - /img/share/wcode-v0-8.en.png
---

By the end of 0.7, wcode could already give an agent bounded repository context, edit files with SHA preconditions, run verification, and keep Design State, Software Graph, Evidence, and Reconciliation around the work.

But when I used it myself, one gap was still obvious:

> An agent being able to operate a repository does not mean a human can quickly understand the state of that repository.

I still kept going back to an IDE to inspect the tree, callers, tests, and Git changes, then back to wcode for verification and evidence. Each view was useful, but they were not really one engineering model.

That became the main idea behind 0.8.

I did not want another batch of MCP tools. I wanted to pull the existing pieces toward one thing:

**an Engineering Digital Twin of the repository that can be inspected, queried, revisited, and explicit about the precision of its evidence.**

The current release is **v0.8.1**. v0.8.0 built the main structure; v0.8.1 tightened the Decision Plane and Jev boundaries immediately afterwards.

![The wcode engineering intelligence stack, from repository facts to graph relationships and verification evidence](/img/wcode/wcode-intro-intelligence-stack.svg)

## A Code Graph is only useful if it admits what it knows

I have always been a little suspicious of code graphs.

The easy version is to draw every file, symbol, and module as a large connected ball. It looks impressive and becomes difficult to use almost immediately.

The questions I actually care about are more boring:

- Where did this relationship come from?
- Was it observed by Tree-sitter or confirmed by LSP?
- Was it declared in Design State or seen at runtime?
- Does it belong to the current graph revision?
- Is it related to the current Working Tree change?
- Is there proof or a test behind it?

In 0.8, Code Graph became a workbench inside **Engineering Architecture** rather than another top-level workspace.

Architecture remains the primary model. The graph is a deeper observable layer.

From a symbol, I can now inspect bounded callers, callees, references, dependencies, implementation ownership, tests, requirements, and verification/proof context.

Calls, Impact, and All Evidence modes all have hard depth, node, and edge limits. The UI uses upstream → focus → downstream lanes instead of allowing an unbounded node-ball.

More importantly, every retained relation keeps its **provenance** and **precision**.

Declared, syntax, semantic/LSP, runtime, deterministic, and heuristic evidence do not get flattened into a single vague confidence number.

I would rather see “this edge is syntax-derived” than have a clean graph hide uncertainty from me.

### Graph History is part of the same view

The Code Graph can also open a stored Graph History snapshot.

That gives me read-only graph time travel: I can ask whether a caller, dependency, or proof relationship existed in an earlier graph revision without rebuilding the repository or mutating current state.

For an agent this is useful context. For me it is mostly an engineering history tool.

## The Observatory is quieter now

The old Observatory could become noisy because a browser trying to get fresh state could trigger groups of relatively heavy snapshots.

That was technically correct and operationally annoying.

In 0.8, each Workspace allows at most one background Observatory rebuild at a time. Cached responses are revision-stamped and explicitly say whether the state is cached, current, or refreshing.

The browser renders useful cached state first and uses bounded lightweight probes instead of fanning out more heavy snapshot work.

I also reworked the information hierarchy.

Project Pulse and state are first-glance information. Metrics, relationships, and timelines come next. Evidence and inspectors are the third layer.

Stale, Unknown, Inconclusive, Failed, and Unverified are not allowed to look like current passing proof.

That sounds like a UI detail, but for an engineering control plane it is a trust boundary:

**the interface should never look more certain than the evidence underneath it.**

## Why I finally started using the phrase Engineering Digital Twin

I avoided that phrase for a while.

If all I had was a code index with graph edges, “Digital Twin” would feel inflated.

0.8 is the first version where the name feels closer to what the system is actually doing:

    Design State
        ↓
    Implementation ownership
        ↓
    Syntax / Semantic / Runtime relations
        ↓
    Working Tree changes
        ↓
    Drift / Risk / Impact
        ↓
    Verification / Evidence

This is not a second mutable project database.

Source, Git, Design State, runtime providers, and Evidence remain their own sources of truth. The Digital Twin is a read-only engineering view that composes them without pretending they have the same precision.

That distinction matters. The moment a twin becomes a second mutable project state, I have created a new consistency problem instead of solving one.

![The wcode engineering loop connecting context, graph, changes, verification, and evidence](/img/wcode/wcode-intro-engineering-loop.svg)

## The Decision Plane became a real subsystem in 0.8

The other large piece of 0.8 is the **Decision Plane**.

Coding agents make many small decisions that do not necessarily require the main reasoning model:

- Is the current context sufficient?
- Should retrieval continue?
- Are semantic relationships necessary evidence before a safe edit?
- Should verification become deeper?
- Is this state clear enough to act, or should it abstain?

0.8 represents these as provider-neutral structured Probability, Choice, and Score signals.

But the important part is not that I can plug a smaller model into the path.

The important part is that the Decision Plane still does **not** own the deterministic engineering boundary.

Authorization, Workspace boundaries, SHA preconditions, Evidence, risk-derived verification, and human approval stay deterministic.

A provider can say “retrieve more.” It cannot say:

> Confidence is 0.93, so skip the SHA check.

That would defeat most of the work I have done on wcode.

## Engineering Fitness stopped using wcode's own readiness as truth

A Decision Plane is not useful if it grades itself.

For context sufficiency, 0.8 calibrates against independently authored **Engineering Fitness Gold** instead of using wcode readiness fields as the answer.

I care about four different things:

1. Did retrieval find the required identity?
2. Did the agent receive the complete source body?
3. Is the SHA fresh?
4. If the task is actually writable, are all required edit inputs present?

On the 60-case model-free diagnostic used for the 0.8.0 release, the 1K cold and warm runs both reached **100%** required identity recall, complete-body recall, and fresh-SHA recall. All **58/58** eligible writable cases received the required edit inputs.

The decision baseline had a Brier score of **0.018846**, with zero false stops and zero false continues.

I do not read those numbers as “context engineering is solved.”

They are a baseline I can use when I change retrieval, ranking, budgets, or the Decision Plane. At least I can detect when I have broken a basic property without needing a large reasoning model to judge the result.

## Jev got narrower again in 0.8.1

v0.8.0 already supported comparing a baseline Decision Plane provider with a candidate on the same request.

In v0.8.1, I cleaned up the naming:

- the local model-free layer is the **Decision Plane**;
- the external semantic provider is **Jev**;
- the main large model is the **Reasoning Model**.

More importantly, I rewrote the questions.

A broad question such as:

> Would semantic navigation be useful?

is almost always answered “yes” in a coding task. Looking at more relationships is usually useful.

The narrower 0.8.1 boundary is closer to:

> Are semantic relationships necessary evidence before a safe edit?

Choice criteria now define positive and negative boundaries, and other_review exists for states that should abstain instead of pretending to be edit-ready.

The current Agent Context Jev question set is wcode.agent_context@3.

### Jev is increase-only

Jev may ask for more retrieval, semantic navigation, deeper verification, or more reasoning.

It may not reduce deterministic work.

A Jev edit_then_verify recommendation is suppressed unless the deterministic baseline already selected the same action. Unknown edit readiness goes to other_review rather than silently becoming edit-ready.

If the Jev advisory block would overflow the Agent Context budget, the advisory is dropped first. Source, SHA preconditions, tests, and deterministic risk evidence keep priority.

That gives me a failure mode I am comfortable with:

**if Jev disappears, wcode loses advice; it does not lose safety.**

## Shadow A/B is more useful to me than replacing the baseline

I did not make Jev the Decision Plane authority.

The baseline and candidate see the same immutable DecisionRequest, and wcode records shared and missing signals, probability and score deltas, Choice disagreements, shape mismatches, and safety-policy violations.

That is closer to Shadow A/B.

I want to see where a provider disagrees with the deterministic baseline before I give it any authority over runtime behavior.

It is slower than “API connected, enable it by default,” but much easier to reason about.

## Repository scanning finally shares Ignore semantics

This is less visible than the Digital Twin, but it has a large effect on everyday use.

Source scanning, search, indexing, status, and subspace discovery used to have slightly different traversal paths. That creates silly cases where one subsystem ignores target and another walks straight through it.

0.8 moves repository-wide walking onto shared ignore-aware behavior.

By default it respects .gitignore, .ignore, Git info exclude, Git global exclude, and protected paths. Heavy generated trees such as target, node_modules, caches, and common build outputs are pruned before traversal.

Explicit intent still wins. If I directly ask wcode to read or search an ignored path, bounded operations can still access it.

Performance rules should not silently override an explicit user request.

## The TUI became more task-first

I removed some permanent engineering telemetry from the main TUI.

Wide terminals now use a 70/30 layout: Workspace Activity is the main canvas, while engineering and connection state live in a compact control rail.

The rail is reduced to four independent lines:

    ARCH
    DRIFT
    PROOF
    MODEL

Medium and narrow terminals drop the permanent Engineering Pulse entirely so task rows keep the space.

The TUI is increasingly about three questions:

- What is the agent doing now?
- Is it blocked by authorization, verification, or runtime state?
- When do I need to intervene?

Detailed architecture and proof still live in the Engineering Console.

## 0.8.1 also fixed two "looks correct" UI bugs

These were good examples of why observability has to be part of correctness.

Code Graph requests are parameterized by query, mode, depth, and snapshot. A late response is not safe to render just because it succeeded; all four request semantics must still match the current view.

The Access page has a similar rule. Workspaces, commands, and authorizations are now published atomically. If one response fails shape validation, the group remains Unknown instead of showing a partially truthful state.

The dangerous UI is not the one that crashes.

It is the one that displays a coherent-looking answer made from mismatched state.

## The old boundaries are still the boundaries

wcode has changed a lot between 0.3 and 0.8, but I have not changed the basic rules I started with:

- Workspace Root remains a boundary;
- edits remain SHA-bound;
- Full Access is an explicit operator decision;
- the Decision Plane cannot grant authorization;
- Jev cannot lower verification;
- cancellation is not rollback;
- verification evidence belongs to an exact revision.

The Engineering Digital Twin is read-only observability. A graph relationship does not grant permission to mutate anything.

![The wcode verification mesh keeps checks, independent review, and evidence bound to repository state](/img/wcode/wcode-intro-verification-mesh.svg)

## The release was larger than I expected

From v0.7.6 to v0.8.0, the Git diff touched **135 files, about +7,364 / -775 lines**.

I originally thought 0.8 would mostly be “Code Graph plus a better Observatory.”

Instead it pulled on the whole path:

    Repository scan
        ↓
    Context
        ↓
    Graph / Digital Twin
        ↓
    Decision Plane
        ↓
    Edit boundary
        ↓
    Verification
        ↓
    Evidence
        ↓
    Human observability

That is why I ended up calling the release **Engineering Digital Twin** rather than Code Graph.

The graph is only one entry point into it.

## The current release is 0.8.1

v0.8.0 was the Engineering Digital Twin release on September 19. Later the same day I shipped v0.8.1, tightening Jev decisions, naming, and WebUI state truthfulness.

The detailed release notes are here:

- [v0.8.0 — Engineering Digital Twin](https://wcode.francis.run/docs/releases/v0.8.0/)
- [v0.8.1 — Jev Decision Plane hardening](https://wcode.francis.run/docs/releases/v0.8.1/)

If I had to reduce 0.8 to one change, it would be this:

**wcode used to focus mainly on helping an agent operate a repository safely. In 0.8, I started trying to make the human and the agent look at the same evidence-aware engineering state.**

That part is nowhere near finished, but the direction finally feels coherent.
