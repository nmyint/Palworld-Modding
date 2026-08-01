# Continue Session — Active Handoff

## Purpose

This is the repository-root entry point for a new AI chat that resumes work from
the active continuation handoff under `00_Documentation/Session-Handoffs`.

The active handoff is a continuation summary. It is subordinate to explicit
current user instructions and verified current repository state.

## Minimal user prompt

The user may start the chat with only:

```text
Use the GitHub connector for nmyint/Palworld-Modding.
Read ContinueSession.md completely and follow it.
```

The assistant must treat this file as an instruction to perform the complete
startup process, not as a request to summarize this file.

## Required assistant startup

Before sending any repository-specific natural-language response, the assistant
must silently complete all of the following within the same assistant turn:

1. Verify GitHub connector access to `nmyint/Palworld-Modding`.
2. Treat current `main` as authoritative unless the user explicitly states that
   the local repository differs.
3. Locate the active continuation handoff under
   `00_Documentation/Session-Handoffs` and read it completely.
4. Verify that the selected handoff is still the active continuation record and
   inspect newer relevant repository changes.
5. Read `README.md` completely, not superficially.
6. Read `00_Documentation/SessionStartup.md` completely and follow its shared
   silent startup-gate contract.
7. Read `00_Documentation/AIRepositoryWorkflow.md` completely and strictly abide
   by it.
8. Read every document required or referenced by README and the AI workflow,
   including all repository documentation required by README,
   `RepositoryStructure.txt`, `RepositoryInventory.json`, relevant operational
   and standards documentation, and `Scrapbook.md`.
9. Verify current `main` HEAD, recent commits, repository state, active-handoff
   status, and the exact continuation boundary.
10. Inspect the implementation and tests relevant to the continuation boundary.
11. Keep implementation blocked until the startup gate is complete and the user
    selects or confirms the next scope.

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
2. a concise verified current repository-state summary;
3. the exact verified continuation boundary and unresolved choices;
4. genuine limitations remaining after available verification was attempted;
5. one question asking the user to select or confirm the next scope.

### BLOCKED

Use this only for a genuine hard technical failure. It may contain only:

- the exact source or operation that failed;
- the exact error or access limitation;
- the required verification that remains incomplete.

Do not begin implementation in the startup response.
