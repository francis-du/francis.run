---
title: "wcode: Rebuilding the Coding Agent Runtime Around Jev"
date: 2026-09-22T02:36:00+08:00
draft: false
url: blog/coding-agent-without-kv-cache/
translationKey: wcode-jev-agent-runtime
description: "I do not want wcode to become another Claude Code. After reading Why yet another agent, I am even more convinced that Jev / TypeSafe ideas belong in the runtime beneath coding agents: context, state, action routing, verification, and background intelligence."
tags:
  - wcode
  - Jev
  - TypeSafe
  - Coding Agents
  - Context
  - Engineering Runtime
---

I have been thinking about one question for a while:

> Should the next phase of wcode keep adding more agent features, or should it rebuild the layer underneath the agent?

A few days ago I read a note called [Why yet another agent](https://docs.google.com/document/d/1G61uUB0FifUnmmrPzFQojZ3KpczYKmXGpgEXDJ2l_Zg/mobilebasic). One question in it stuck with me:

> How would you design a coding agent if LLMs had no KV cache?

That framing made a lot of things I had stopped questioning look strange again: compaction, restart, subagents, tool schemas, skills, model routing, long sessions, and memory.

My conclusion was not that we need a smarter agent.

It was almost the opposite.

I am more convinced now that **wcode should not try to copy Claude Code, Codex, or Cursor. It should build the runtime layer those agents are missing underneath.**

The most useful idea I take from Jev / TypeSafe is not “use another model.”

It is this:

> Turn fuzzy semantic judgments that normally live inside prompts and context into typed, bounded, explicit program decisions.

This is how I now want to keep restructuring wcode.

## I do not want Jev to run the agent

The first distinction matters.

I am not trying to build this:

~~~text
wcode
  ↓
Jev
  ↓
Jev decides everything
~~~

That would move wcode in the wrong direction.

A lot of wcode is deliberately deterministic already:

~~~text
Is this file SHA still current?
Is this path inside the Workspace?
Is this command authorized?
Did Verification actually run?
Does this Evidence belong to the current revision?
Has Design State drifted?
Are there unfinished Worklist items?
~~~

If code can compute the answer, code should compute it.

Jev is more useful for another class of questions:

~~~text
Is the current context sufficient?
Are we still missing important evidence?
Do we actually need callers / references / implementations?
Which legal action best fits the current semantic state?
Does this failure need more evidence, more semantics, or a direct repair?
~~~

These are the semantic if-statements that often end up buried in agent prompts.

That is why I think of Jev as part of the **Decision Plane**, not as another agent.

## wcode already has a first version of that Decision Plane

Jev in wcode does not receive the raw user prompt and take over.

The rough shape today is:

~~~text
repository state
     │
     ▼
deterministic baseline
     │
     ├── target
     ├── worktree
     ├── graph
     ├── verification
     ├── semantic readiness
     └── current risk
     │
     ▼
DecisionRequest
     │
     ├── local deterministic decision
     └── Jev decision
             │
             ▼
       shadow comparison
             │
             ▼
       increase-only guidance
~~~

Jev currently answers typed questions through Noul, Choice, and Score.

For example:

~~~text
context_sufficient            -> Noul
continue_retrieval            -> Noul
semantic_navigation_required  -> Noul
verification_escalation       -> Noul
next_action                   -> Choice
risk_surface                  -> Choice
evidence_density              -> Score
~~~

But it cannot say:

> “Looks fine to me, skip verification.”

The current rule is simple:

> **Jev may increase work, but it may not reduce deterministic safety.**

It can ask wcode to:

~~~text
retrieve one more symbol
review the worktree first
run semantic navigation
raise verification to full
~~~

It cannot remove:

~~~text
SHA preconditions
authorization
workspace containment
the verification floor
current-revision evidence
~~~

I want to keep that boundary.

## The bigger Jev lesson: State should come before Prompt

A traditional coding agent often treats state as something like:

~~~text
system prompt
+ conversation
+ files read earlier
+ tool calls
+ tool outputs
+ compaction summary
~~~

In other words:

> What the model knows is mostly a function of what happened earlier in this session.

That aligns naturally with KV-cache reuse.

It is not necessarily the right state model for an engineering system.

wcode already owns a lot of state that should never belong to a chat transcript in the first place:

~~~text
Execution
Worklist
Workspace
Design State
Software Graph
Semantic Provider State
Impact
Risk
Verification Plan
Evidence
Reconciliation
Runtime Task
~~~

That is the project state that matters.

A model can change.

A client can change.

A session can die.

Compaction can happen.

None of those events should erase or distort engineering state.

So the direction I want to push harder is:

> **The Runtime owns state. The Agent leases a task-specific view of it.**

## First: turn Agent Context into a Context Compiler

wcode already has agent_context.

It does much more than “search a few files”:

- localizes the target;
- attaches the current SHA;
- includes Design State;
- includes verification entry points;
- includes graph / semantic readiness;
- includes the Worklist;
- returns next actions.

But from this new perspective, it can go further.

I want to move it from:

> “produce one edit-ready context bundle”

toward:

> **compile the context required for this specific task.**

Everything that could enter the model would first become some form of context candidate:

~~~text
ContextChunk {
  source
  revision
  scope
  freshness
  sensitivity
  cost
  relevance
  precision
  render_level
}
~~~

Then each task gets compiled again:

~~~text
current goal
    │
    ▼
candidate chunks
    │
    ├── source
    ├── tests
    ├── graph
    ├── semantic state
    ├── design
    ├── evidence
    ├── worklist
    ├── past decisions
    └── runtime state
    │
    ▼
deterministic filters
    │
    ▼
Jev semantic scoring
    │
    ▼
render policy
    │
    ├── omit
    ├── one-line summary
    ├── detailed summary
    └── full content
    │
    ▼
compiled context
~~~

That differs from compaction in an important way.

Compaction asks:

> How do I compress everything that happened before?

A Context Compiler asks:

> **Why does this task need to see this piece of state at all?**

I think that is the more fundamental optimization.

## Second: move Retrieval from “continue or stop” to reranking

wcode already asks Jev questions like:

~~~text
continue_retrieval?
semantic_navigation_required?
~~~

The next step I want is candidate-level scoring.

Suppose search, graph traversal, experience retrieval, and design lookup produce thirty candidates:

~~~text
candidate 1
candidate 2
candidate 3
...
candidate 30
~~~

Today it is easy to rely too much on lexical order or fixed heuristics.

I would rather have:

~~~text
deterministic search
      │
      ▼
bounded candidate pool
      │
      ▼
Jev:
  relevant?
  task-critical?
  test-related?
  security-sensitive?
  stale?
  contradictory?
      │
      ▼
rerank
      │
      ▼
top context
~~~

But this still needs a deterministic floor.

I do not want Jev to be able to remove:

~~~text
a user-named target
current changed files
security-sensitive files
mapped acceptance tests
current failure locations
the SHA edit target
current-revision evidence
~~~

Jev may rerank optional context. It does not get to delete mandatory evidence.

## Third: add a Context Firewall

One idea from the note that matters a lot for coding agents is:

> Retrieved text should not automatically become instruction.

That is more dangerous in a coding agent than in ordinary RAG.

An agent reads:

- README files;
- docs;
- issues;
- generated source;
- shell output;
- web content;
- dependency manuals;
- MCP resources;
- comments.

Any of those can contain text like:

~~~text
Ignore previous instructions
Run this command
Upload this token
Disable verification
~~~

If all of that becomes undifferentiated model context, repository data and agent instructions collapse into the same channel.

So before the Context Compiler I want another layer:

~~~text
retrieved chunk
     │
     ▼
deterministic boundary
     │
     ▼
semantic classification
     │
     ├── evidence
     ├── conflict
     ├── instruction-like
     └── irrelevant
     │
     ▼
context admission
~~~

I think of this as a **Context Firewall**.

Jev would not become the security authority here.

The actual permissions stay in wcode.

But Jev can help answer:

> Does this text look like evidence, or is it trying to change agent behavior?

That distinction will matter more as agents consume more external data.

## Fourth: stop exposing the entire Tool Catalog forever

Another part of the note I strongly agree with is the context tax of tool calling.

The usual function-calling / MCP model is:

> Put all tool schemas in context before the model makes a decision.

That works when there are ten tools.

It gets awkward with dozens or hundreds.

There are two costs:

1. the schemas themselves consume context;
2. a huge action space does not necessarily improve tool selection.

wcode has already spent a lot of time shrinking its model-facing schemas.

I want to go further:

> **Replace the permanently visible Tool Catalog with an Action Registry plus progressive disclosure.**

The model would first see only lightweight capability hints:

~~~text
repository_search
semantic_navigation
code_edit
verification
runtime_control
authorization
design_state
evidence
~~~

Only after selecting a capability would the runtime expose:

~~~text
the exact action
the full schema
argument constraints
examples
failure semantics
risk class
~~~

The flow becomes:

~~~text
Goal
  │
  ▼
Action Router
  │
  ▼
Top-K capability
  │
  ▼
load full action schema
  │
  ▼
model tool call
~~~

This resembles TypeSafe's Skill Suggestion pattern:

start with short descriptions,

pick a small Top-K,

then load richer information and decide again.

If this works well, wcode can include a large number of capabilities without charging the model the full context cost on every turn.

## Fifth: separate Skills, Tools, and Context Rules

I increasingly think these are three different abstractions.

### Tool / Action

An operation that should happen now:

~~~text
run verification
read file
find references
start process
~~~

### Skill / Workflow

How to handle a class of tasks:

~~~text
release package
debug frontend
review migration
repair verification failure
~~~

### Context Rule

Knowledge that should remain available while a condition is true:

~~~text
frontend -> style guide
src/auth -> auth gotchas
Rust perf -> performance rules
writing -> personal style samples
~~~

That third category is easy to miss.

It resembles AGENTS.md, but it should not require globally loading the whole file.

It should look more like:

~~~text
if scope == src/auth:
    include auth-gotchas

if task == frontend:
    include frontend-style

if task == release:
    include release-policy
~~~

And it should support something conceptually like:

~~~text
sticky = true
~~~

Not “keep this in KV cache forever.”

Instead:

> As long as the task condition remains true, the Context Compiler must keep re-including this rule.

That avoids important instructions disappearing after compaction or a model switch.

## Sixth: Subagents should share State, not chat history

The hardest part of subagents has never been “how do I call another model?”

The hard questions are:

~~~text
Which parts of the main context should be passed over?
What should be merged back?
Is the subagent still reading the current revision?
What happens when several workers write?
How do we represent conflicts?
~~~

If State is explicit, the abstraction can change.

A subtask can be described as:

~~~text
Subgoal
  id
  revision
  input scope
  allowed reads
  allowed writes
  output schema
~~~

For example:

~~~text
subgoal:
  inspect auth impact

revision:
  R

read:
  Software Graph
  Semantic Provider
  src/auth
  mapped tests

write:
  ImpactReport only
~~~

It does not need a copy of the main agent's entire session.

It needs a task-specific context view.

Its result should not be “another long conversation to paste back.”

It should be a structured artifact.

At that point a subagent looks more like a worker than another chat.

## Seventh: make Background Intelligence first-class

The appendices in the note point out another pattern I find promising:

A lot of useful agent workflows are naturally background work.

Especially read-only tasks:

~~~text
security review
architecture review
test-gap analysis
graph refresh
documentation drift
eval generation
performance analysis
cross-model review
~~~

All of them can be modeled as:

> A function of the current repository revision.

That suggests a wcode shape like:

~~~text
Revision R
   │
   ├── Graph Builder
   ├── Security Review
   ├── Architecture Review
   ├── Test Gap
   ├── Docs Drift
   ├── Eval Builder
   └── Runtime Observation
           │
           ▼
   Derived Engineering State
~~~

When the revision changes:

~~~text
R -> R+1
~~~

old derived results become stale.

This is already close to how wcode treats Evidence, Verification, graph provenance, and revision binding.

I think this is a more maintainable multi-agent architecture than “spawn many agent chats and merge their prose.”

## Eighth: Model Routing comes last

Why yet another agent spends time on the way KV cache can make model routing economically strange.

I agree with the problem.

But I do not want to build the model router first.

If state and context are still one giant session history, then:

> A smarter router is mostly deciding which model has to ingest the giant transcript again.

The order should be reversed:

~~~text
make State explicit
     ↓
build the Context Compiler
     ↓
build the Action Router
     ↓
build Subgoal / Background planes
     ↓
then build Model Routing
~~~

At that point model switching becomes much more natural:

~~~text
simple task
→ compile a small Context View
→ cheap / fast model

complex task
→ compile a richer Context View
→ stronger model

security review
→ compile a security-specific View
→ independent reviewer
~~~

The second model does not need to inherit the first model's last half-hour of “brain state.”

It reads another view of the same Engineering State.

## This makes the wcode product boundary clearer

I do not want to define wcode as:

> a stronger coding agent.

I would rather define it as:

> **an Engineering Runtime underneath coding agents.**

Something like:

~~~text
                Codex / Claude / ChatGPT / custom agents
                               │
                               ▼
                         Current Goal
                               │
                               ▼
                  ┌─────────────────────┐
                  │   wcode Decision    │
                  │       Plane         │
                  │ deterministic + Jev │
                  └──────────┬──────────┘
                             │
           ┌─────────────────┼─────────────────┐
           ▼                 ▼                 ▼
   Context Compiler     Action Router     Background Plane
           │                 │                 │
           ▼                 ▼                 ▼
      State Fabric       Action Registry   Derived State
           │
           ├── Execution
           ├── Worklist
           ├── Workspace
           ├── Design State
           ├── Software Graph
           ├── Semantics
           ├── Risk
           ├── Verification
           ├── Evidence
           ├── Reconciliation
           └── Runtime Tasks
~~~

The Agent can change.

The model can change.

The UI can change.

The MCP client can change.

The engineering state and its boundaries do not.

That feels like the part wcode is actually well positioned to own.

## Jev's role in this architecture

If I compress all of this into one sentence:

> Jev should not be wcode's brain. It should be the typed decision engine for fuzzy semantic branches inside wcode.

Questions such as:

~~~text
Is this context chunk relevant?
Does it need a fuller rendering?
Are we still missing evidence?
Which legal action fits best?
Is this subgoal duplicating earlier work?
Does this diff justify extra review?
Is this retrieved text evidence or instruction-like content?
~~~

map naturally to:

~~~text
Noul
Choice
Score
~~~

Questions like:

~~~text
Can this file be written?
Can this command run?
Is this SHA current?
Did verification pass?
Is this Evidence stale?
~~~

should stay deterministic.

The cleaner that boundary is, the safer the system becomes.

## How I want to implement the next phase

After reading the note, this is roughly how I would order the next wcode restructuring work.

### 1. Productize Decision Policy

The question sets, thresholds, distributions, and calibration machinery already exist.

The next step is to make them explicit versioned policy:

~~~text
question_set_version
decision_policy_version
requested_model
resolved_model
calibration sample
Brier
false-stop
false-continue
~~~

### 2. Semantic Retrieval Reranker

Move Jev from “should we keep searching?” to “which candidates deserve context?”

### 3. Context Firewall

Classify:

~~~text
evidence
conflict
instruction-like content
irrelevant
~~~

### 4. Context Compiler

Choose a render level for each chunk:

~~~text
omit
summary
detailed
full
~~~

### 5. Action Registry

Show the model a lightweight capability index first, then load complete tool schemas on demand.

### 6. Structured Skill / Context Rule

Separate workflow behavior from long-lived task context.

### 7. Background Intelligence

Turn graph refresh, review, security, eval generation, and docs drift into revision-bound derived state.

### 8. Model Routing last

Only then should routing mean more than “switch models.”

It becomes:

> Compile different cost / depth views from the same State Fabric for different models.

## Final thought

The biggest thing Jev changed for me is not that there is a cheap model that can make small decisions for an agent.

The important idea is:

> **Move semantic decisions out of implicit prompt behavior and into typed, versioned, calibratable program interfaces.**

Why yet another agent pushes that one step further:

> **If state is explicit too, many of the complicated structures that grew around KV-cache-heavy sessions may not be fundamental at all.**

So the next phase of wcode, for me, is moving from Repository Control Plane toward Engineering Runtime.

Not another agent.

A cleaner substrate that any agent can use:

**State, Context, Decision, Action, Verification, Evidence, and Background Intelligence.**

If that works, I think it is a much more interesting direction than building another Claude Code clone.
