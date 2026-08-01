# AI Session Startup

## Purpose

This document defines the exact startup behavior for a new AI chat session working
with `nmyint/Palworld-Modding`.

Choose exactly one startup mode:

1. **New project or implementation** — use when beginning a new feature, sprint,
   maintenance project, investigation, or implementation scope that is not being
   resumed from an active session handoff.
2. **Continue from session handoff** — use when resuming work summarized in the
   active file under `00_Documentation/Session-Handoffs`.

Both modes use the same silent startup-gate execution contract.

## Silent startup-gate execution contract

The startup gate must be completed within the same assistant turn before the
assistant sends a natural-language repository response.

During startup-gate execution, the assistant must:

- perform all required GitHub connector calls, document reads, chunk or blob
  retrieval, repository inspection, and verification without sending a progress
  message;
- continue through the complete required reading set rather than stopping after
  an initial scan or partial document retrieval;
- resolve ordinary truncation by using line ranges, chunks, or complete blob
  retrieval;
- verify actual repository state instead of inheriting a commit, branch, test
  result, or status from a prompt, handoff, screenshot, or previous conversation;
- keep all repository modifications blocked until the startup gate and requested
  scope confirmation are complete.

During startup-gate execution, the assistant must not send:

- acknowledgements such as `I understand`;
- progress updates or lists of remaining reading;
- plans, promises, apologies, or statements that it will continue;
- partial repository summaries;
- repeated paraphrases of the startup instructions;
- a request for permission to continue the required reading.

Needing additional connector calls, encountering a long document, or receiving a
truncated response that can be retrieved in chunks is not a hard blocker.

The first visible natural-language response must be exactly one of these result
types:

### COMPLETED

The response may contain only:

1. confirmation that the complete startup gate was satisfied;
2. a concise verified repository-state summary;
3. the verified project or continuation boundary;
4. genuine limitations that remain after all available verification was tried;
5. the requested scope-selection or approval question.

### BLOCKED

Use this only when a hard technical failure prevents completion in the current
turn. The response must contain only:

- the exact source or operation that failed;
- the exact error or access limitation;
- the required verification that remains incomplete.

Do not use `BLOCKED` merely because the reading set is large, more connector calls
are required, or a retrievable response was truncated. Do not send repeated
blocker reports or promise to continue later.

Any acknowledgement, progress report, partial result, or promise to continue
before `COMPLETED` or a genuine `BLOCKED` result is a startup-gate violation.

## Startup block 1 — New project or implementation

Copy this block into a new chat when beginning a new project or implementation
scope:

```text
Use the GitHub connector for:

nmyint/Palworld-Modding

Treat the current main branch as authoritative unless I explicitly tell you that
my local repository differs.

This is a NEW PROJECT OR IMPLEMENTATION session. Do not assume that an older
session handoff defines the new scope.

Execute the complete repository startup gate silently within this same assistant
turn. Follow 00_Documentation/SessionStartup.md and its Silent startup-gate
execution contract.

Required startup work:

1. Read README.md completely, not superficially.
2. Read every document README.md requires or references for repository work.
3. Read 00_Documentation/AIRepositoryWorkflow.md completely and strictly abide by
   it.
4. Read every applicable document required or referenced by the AI workflow.
5. Read RepositoryStructure.txt, RepositoryInventory.json, all repository
   documentation required by README, the relevant operational and standards
   documentation, and Scrapbook.md.
6. Inspect the current implementation and tests relevant to the proposed new
   project or implementation.
7. Verify GitHub connector access, current main HEAD, recent commits, repository
   structure, and the relevant existing feature boundaries.
8. Treat my current instructions and verified current repository sources as
   authoritative. Do not allow previous chat memory or an unrelated handoff to
   override them.

Do not send acknowledgements, progress updates, apologies, plans, promises,
partial summaries, or lists of remaining reading. Do not ask me to confirm that
you should continue the startup work.

Your first visible natural-language response must be either:

COMPLETED — confirm the full gate, summarize the verified current state relevant
to the proposed work, identify the verified implementation boundary, recommend
whether a branch is warranted under the documented branch policy, and ask for
scope approval before implementation;

or

BLOCKED — provide one concise hard-blocker report with the exact failed source or
operation, exact error, and remaining required verification.

Do not begin implementation in the startup response.
```

## Startup block 2 — Continue from session handoff

Copy this block into a new chat when resuming from the active handoff:

```text
Use the GitHub connector and continue work on:

nmyint/Palworld-Modding

Treat the current main branch as authoritative unless I explicitly tell you that
my local repository differs.

This is a SESSION HANDOFF CONTINUATION session.

First locate and read the latest active file under:

00_Documentation/Session-Handoffs/

Read that handoff completely, then execute its startup gate and the complete
repository startup gate silently within this same assistant turn. Follow
00_Documentation/SessionStartup.md and its Silent startup-gate execution
contract.

Required startup work:

1. Read README.md completely, not superficially.
2. Read every document README.md requires or references for repository work.
3. Read 00_Documentation/AIRepositoryWorkflow.md completely and strictly abide by
   it.
4. Read every applicable document required or referenced by the AI workflow.
5. Read RepositoryStructure.txt, RepositoryInventory.json, all repository
   documentation required by README, the relevant operational and standards
   documentation, Scrapbook.md, and the active handoff.
6. Verify that the selected handoff is still the active continuation record and
   inspect any newer relevant repository changes.
7. Verify GitHub connector access, current main HEAD, recent commits, repository
   state, and the exact continuation boundary.
8. Treat my current instructions and verified current repository sources as
   authoritative. The handoff and previous chat memory are summaries and must not
   override current repository facts.

Do not send acknowledgements, progress updates, apologies, plans, promises,
partial summaries, or lists of remaining reading. Do not ask me to confirm that
you should continue the startup work.

Your first visible natural-language response must be either:

COMPLETED — confirm the full gate, summarize the verified current repository
state, state the exact continuation boundary and unresolved choices, and ask me
to select or confirm the next scope before implementation;

or

BLOCKED — provide one concise hard-blocker report with the exact failed source or
operation, exact error, and remaining required verification.

Do not begin implementation in the startup response.
```

## Recovery block after a startup violation

When an assistant has already sent an acknowledgement or partial startup report,
use this once:

```text
Resume and complete the startup gate now.

Do not send another acknowledgement, explanation, apology, progress update,
plan, promise, partial result, or list of remaining work.

Continue all required connector calls, complete document retrieval, repository
inspection, and verification within this same assistant turn.

Your next visible natural-language response must be exactly one of:

COMPLETED — the completed startup-gate summary and required scope question;

or

BLOCKED — one concise hard technical blocker containing the exact failed source
or operation, exact error, and remaining required verification.

Lengthy reading, additional connector calls, and retrievable truncation are not
hard blockers.
```

## Maintenance rules

- Keep these blocks synchronized with `README.md`,
  `AIRepositoryWorkflow.md`, and the active handoff policy.
- Future active handoffs must embed or explicitly invoke the handoff-continuation
  block and silent execution contract.
- Update this document when startup behavior changes instead of creating
  competing startup prompts in multiple handoff files.
- Adding, removing, renaming, or moving this document requires repository-map
  regeneration.
