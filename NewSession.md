# New Session — New Project or Implementation

## Purpose

This is the repository-root entry point for a new AI chat that begins a new
feature, sprint, maintenance task, investigation, or implementation scope.

Do not use an older session handoff to define the new scope unless the user
explicitly asks for that handoff to be considered.

## Minimal user prompt

The user may start the chat with only:

```text
Use the GitHub connector for nmyint/Palworld-Modding.
Read NewSession.md completely and follow it.

Proposed work: <describe the new work here>
```

The assistant must treat this file as an instruction to perform the complete
startup process, not as a request to summarize this file.

## Required assistant startup

Before sending any repository-specific natural-language response, the assistant
must silently complete all of the following within the same assistant turn:

1. Verify GitHub connector access to `nmyint/Palworld-Modding`.
2. Treat current `main` as authoritative unless the user explicitly states that
   the local repository differs.
3. Read `README.md` completely, not superficially.
4. Read `00_Documentation/SessionStartup.md` completely and follow its shared
   silent startup-gate contract.
5. Read `00_Documentation/AIRepositoryWorkflow.md` completely and strictly abide
   by it.
6. Read every document required or referenced by README and the AI workflow,
   including all repository documentation required by README,
   `RepositoryStructure.txt`, `RepositoryInventory.json`, relevant operational
   and standards documentation, and `Scrapbook.md`.
7. Inspect the current implementation and tests relevant to the proposed work.
8. Verify current `main` HEAD, recent commits, repository structure, and the
   existing feature, sprint, and safety boundaries relevant to the proposed
   work.
9. Determine whether the documented branch policy warrants a dedicated branch.
10. Keep implementation blocked until the startup gate is complete and the user
    approves the proposed scope.

## Visible-response contract

During startup, do not send an acknowledgement, progress report, apology, plan,
promise, partial summary, list of remaining reading, or request for permission to
continue.

Lengthy reading, additional connector calls, and retrievable truncation are not
hard blockers.

The first visible natural-language response must be exactly one of these result
types:

### COMPLETED

It may contain only:

1. confirmation that the complete startup gate was satisfied;
2. a concise verified repository-state summary relevant to the proposed work;
3. the verified implementation and milestone boundary;
4. a branch recommendation under the documented branch policy;
5. genuine limitations remaining after available verification was attempted;
6. one scope-approval question.

### BLOCKED

Use this only for a genuine hard technical failure. It may contain only:

- the exact source or operation that failed;
- the exact error or access limitation;
- the required verification that remains incomplete.

Do not begin implementation in the startup response.
