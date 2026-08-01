# AI Session Startup Policy

## Purpose

This document defines the shared startup behavior for AI chat sessions working
with `nmyint/Palworld-Modding`.

The repository now has two short, repository-root entry files:

- `NewSession.md` — begin a new project, sprint, feature, maintenance task,
  investigation, or implementation scope.
- `ContinueSession.md` — resume from the active handoff under
  `00_Documentation/Session-Handoffs`.

The user only needs to point a new chat to the appropriate entry file. The entry
file then requires the assistant to complete the full repository startup gate.

## Minimal user prompts

### New project or implementation

```text
Use the GitHub connector for nmyint/Palworld-Modding.
Read NewSession.md completely and follow it.

Proposed work: <describe the new work here>
```

### Continue from the active handoff

```text
Use the GitHub connector for nmyint/Palworld-Modding.
Read ContinueSession.md completely and follow it.
```

No longer copy the complete startup instructions into every new chat. Maintain
them in the repository entry files instead.

## Shared silent startup-gate contract

The selected entry file, this policy, README, the AI repository workflow, the
required documentation set, repository maps, relevant implementation and tests,
and current repository state must all be processed within the same assistant
turn before the assistant sends a repository-specific natural-language response.

During startup-gate execution, the assistant must:

- perform all required connector calls, complete document reads, chunk or blob
  retrieval, repository inspection, and verification without sending a progress
  message;
- continue through the complete required reading set rather than stopping after
  an initial scan or partial retrieval;
- resolve ordinary response truncation with line ranges, chunks, or complete
  blob retrieval;
- verify actual repository state instead of inheriting a branch, commit, test
  result, or status from a prompt, handoff, screenshot, or previous conversation;
- keep repository modifications blocked until startup and requested scope
  confirmation are complete.

During startup-gate execution, the assistant must not send:

- acknowledgements such as `I understand`;
- progress updates or lists of remaining reading;
- plans, promises, apologies, or statements that it will continue;
- partial repository summaries;
- repeated paraphrases of startup instructions;
- requests for permission to continue required reading.

Needing additional connector calls, encountering a long document, or receiving a
retrievable truncated response is not a hard blocker.

## First visible response

The first visible natural-language response must be exactly one of these result
types.

### COMPLETED

The response may contain only the completion items required by the selected
entry file: gate confirmation, concise verified state, the verified project or
continuation boundary, genuine limitations, and one scope-selection or approval
question.

### BLOCKED

Use this only when a genuine hard technical failure prevents completion in the
current turn. The response may contain only:

- the exact source or operation that failed;
- the exact error or access limitation;
- the required verification that remains incomplete.

Do not use `BLOCKED` because the reading set is large, more connector calls are
required, or a response can be recovered through chunk or blob retrieval. Do not
send repeated blocker reports or promise to continue later.

Any acknowledgement, progress report, partial result, or promise to continue
before `COMPLETED` or a genuine `BLOCKED` result is a startup-gate violation.

## Recovery after a startup violation

When an assistant has already sent an acknowledgement or partial startup report,
use this once:

```text
Resume and complete the startup gate now.

Do not send another acknowledgement, explanation, apology, progress update,
plan, promise, partial result, or list of remaining work.

Continue all required connector calls, complete document retrieval, repository
inspection, and verification within this same assistant turn.

Your next visible natural-language response must be exactly one of:

COMPLETED — the completed startup-gate result required by the selected entry
file;

or

BLOCKED — one concise genuine hard technical blocker containing the exact failed
source or operation, exact error, and remaining required verification.

Lengthy reading, additional connector calls, and retrievable truncation are not
hard blockers.
```

## Maintenance rules

- Keep `NewSession.md` and `ContinueSession.md` synchronized with README,
  `AIRepositoryWorkflow.md`, this shared policy, and the active handoff policy.
- Keep shared rules in this document rather than duplicating full prompt blocks
  across handoffs or chat instructions.
- Future active handoffs should reference `ContinueSession.md` instead of
  embedding another complete startup prompt.
- Update the root entry files when mode-specific behavior changes.
- Adding, removing, renaming, or moving either entry file or this policy requires
  repository-map regeneration.
