---
title: "How I Store Verification Evidence for Coding Agents"
date: 2026-09-12T05:34:00+08:00
draft: false
url: blog/wcode-verification/
description: "Coding agents need more than a green test message. wcode treats verification as revision-bound evidence with provenance, complete plans, stale-result rejection, and explicit uncertainty."
tags:
  - wcode
  - Coding Agents
  - Verification
  - Testing
  - Software Engineering
images: []
---

I keep seeing the same line at the end of agent runs:

```text
Tests passed.
```

After a long edit session, that line is usually missing the part I care about.

Which tests ran? Were they quick checks or the full project gate? Did the source change while they were running? Did the design constraints change? Was the output complete? Is the result still valid for the code currently on disk?

In [wcode](https://github.com/francis-du/wcode) I ended up storing verification as evidence tied to a repository revision instead of a boolean in the final chat message.

## What a green command actually tells me

Consider a very normal agent sequence:

```text
edit A
run tests
edit B
finish
```

If the final answer says “tests passed,” the statement is technically true about some moment in the session, but it may say nothing about the final repository state.

The same problem appears when another process edits the repository during a test run, or when a model runs one language-specific check inside a polyglot project and reports the whole repository as verified.

wcode therefore separates several concepts that are often collapsed together:

```text
verification is mapped
verification was executed
verification passed
evidence belongs to this revision
```

Only the last one is useful as durable proof.

## Derive checks from the repository, not from imagination

`verify_project` does not try to invent a new testing framework.

It inspects the repository and derives checks that actually exist. A Rust project may produce a sequence such as formatting, checking, tests, Clippy, and release build. A Node repository is driven by scripts that are actually declared. Other ecosystems have their own providers.

The important part is that the plan is explicit.

Recent wcode versions also stopped silently truncating large mixed-language verification plans. The runtime now constructs the complete bounded plan first. If it exceeds the supported plan size, it fails before dispatch instead of running an arbitrary prefix and presenting that prefix as complete verification.

The old truncation bug was a good reminder that this has to be enforced by the runtime, not left to wording in a report.

## Evidence carries provenance

A useful verification record needs more than `passed: true`.

The evidence layer can retain information such as:

- producer and check identity;
- source and design revision;
- verification policy or plan;
- result and confidence where applicable;
- diagnostics and bounded output metadata;
- timestamps and provenance.

This means a later tool can ask a much better question than “did we ever run tests?”

It can ask whether there is current proof for *this* revision under *this* verification policy.

## Re-check the revision before accepting the result

There is an unavoidable race in repository verification.

A check starts against revision A. While it is running, something changes the source to revision B. The command can still exit successfully, but assigning that success to B would be wrong.

wcode records the source and design state before execution and checks them again before promoting the report to evidence. If the relevant revision changed, the stale result is rejected rather than attached to the new state.

wcode still does not snapshot the filesystem or freeze the worktree during a build. It only refuses to attach an old success to a newer source/design revision.

## Fast checks cannot erase a broader failure

Another subtle problem is aggregation.

Suppose a full verification fails, then a later quick check passes. A naive “latest result wins” rule can make the repository appear healthy even though the broader failure was never resolved.

wcode keeps verification scope and producer semantics when aggregating evidence. A narrow check cannot erase a wider failure merely because it is newer. Conflicting records at the same timestamp fail closed rather than selecting the optimistic interpretation.

The same principle applies to language-quality checks: one lint provider proving its own check does not become a universal “project verified” record.

## Missing evidence is not success

Agent interfaces often have pressure to summarize everything into a positive status indicator.

I try to resist that in the Observatory.

A missing result is missing. A truncated scan is truncated. A mapped acceptance test that has not run is not “mostly verified.” An unsampled resource is not zero.

That makes the UI less cheerful, but much more useful when debugging a long task.

I keep three states separate in the UI: proved, failed, and unknown/inconclusive. Unknown stays unknown.

## Long verification should survive a dropped client

Full project verification can take long enough that keeping one request connection alive is not a good durability model.

wcode can use the MCP Tasks extension for `verify_project`. A compatible client receives a persisted task identifier and can query it later with the same authenticated owner. The work remains managed by the runtime after the creating request ends.

The task handle also means the client does not need to replay `verify_project` just because one response disappeared. Once commands can have side effects, replay-on-timeout is a bad default.

The task ID is the durable handle; repeated polling reads the same task result instead of rerunning the verification.

## `completed` is still not `passed`

Even task state needs careful wording.

A persistent task can be *completed* because the underlying tool returned a result. That result may still represent failed checks.

So a caller must inspect the verification result itself, not infer correctness from transport-level completion.

So `completed` stays a transport/task state. The verification payload still decides whether the checks passed.

## Agents make stale verification easier to miss

Humans make stale-test mistakes too. Agents just compress more edits and checks into less time.

They operate quickly, they can issue multiple edits and checks in parallel, they can be interrupted and resumed, and they often summarize a long sequence into a few confident sentences. A single conversational “green” is therefore a weak audit trail.

Revision-bound evidence gives the next agent — or the human reviewing the work — something better than trust in the previous summary.

It can see what ran, what passed, what failed, what is stale, and what is still unknown.

For me, that is enough reason to keep verification outside the chat transcript. The useful part is being able to inspect the proof later, after the session that produced it is gone.
