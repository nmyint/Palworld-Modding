# AI Repository Workflow

## Purpose

Defines how AI assistants and automated tools should interact with this repository.

## Initial Repository Scan

Always begin with:

1. `README.md`
2. `00_Documentation/RepositoryStructure.txt`
3. `00_Documentation/RepositoryInventory.json`
4. `00_Documentation/AIRepositoryWorkflow.md`
5. Relevant operational documentation in `00_Documentation`
6. `00_Documentation/Scrapbook.md` for historical context

These files define the repository map before deeper inspection.

## Mandatory Repository Compliance Gate

Before answering any repository-specific request, making recommendations, or modifying files, verify:

- README.md has been reviewed completely rather than skimmed for headings or keywords.
- Every document explicitly required or referenced by README.md for the task has been read.
- AIRepositoryWorkflow.md has been reviewed completely and its rules are being followed.
- Every applicable document required or referenced by AIRepositoryWorkflow.md has been read.
- RepositoryStructure.txt has been reviewed.
- RepositoryInventory.json has been reviewed.
- Relevant operational documentation has been identified and read.
- Existing implementation has been inspected when applicable.

If verification cannot be completed, state what remains unverified instead of guessing.

Conversation history, previous responses, cached context, screenshots, summaries, and assumptions are not authoritative repository state.

## Repository Truth and Verification Rules

The repository state is authoritative.

Before answering repository-specific questions, making recommendations, or modifying files:

1. Inspect the current repository state.
2. Verify that files, folders, and implementations actually exist.
3. Read the relevant documentation for the affected area.
4. Use repository contents instead of assumptions or conversation memory.
5. If uncertainty exists, inspect first, confirm second, answer third.
6. Read applicable standards and environment documentation before creating or modifying code.

AI assistants must not:

- claim files are missing without verification.
- claim features are absent without checking the implementation.
- propose replacements for systems that already exist.
- rely solely on previous conversation history when repository state can be inspected.

If documentation and assumptions conflict, repository documentation and current repository contents take priority.

## Authoritative Repository Sources

Primary source for repository orientation:

`README.md`

URL:

https://github.com/nmyint/Palworld-Modding/blob/main/README.md

Supporting authoritative sources:

1. `00_Documentation/RepositoryStructure.txt`
2. `00_Documentation/RepositoryInventory.json`
3. `00_Documentation/AIRepositoryWorkflow.md`
4. Relevant operational documentation
5. `00_Documentation/Scrapbook.md` for historical context

Explicit current user instructions take precedence. The current repository contents and the required documentation set are authoritative over session summaries and prior conversation memory.

## Request Classification

Repository requests should be classified before action.

### Audit

Examples:

- review
- check
- verify
- how many
- what exists
- stale/current status

Required behavior:

- inspect repository state
- enumerate relevant files
- provide evidence-based findings

### Modification

Examples:

- update
- edit
- create
- remove

Required behavior:

- read affected files first
- preserve unrelated content
- validate changes

### Execution

Examples:

- test
- run
- validate

Required behavior:

- execute requested validation
- report actual results

## Branch and Pull Request Policy

Use a workflow proportional to the size and risk of the change.

Work directly on `main` for minor, low-risk changes such as:

- small documentation corrections;
- narrow workflow clarifications;
- simple metadata or configuration maintenance;
- focused fixes whose scope and impact are already understood.

Create a dedicated branch when the work involves:

- starting a new sprint or major milestone;
- a major feature or broad behavioral change;
- a risky refactor or migration;
- experimental work that may be discarded;
- uncertain scope that may expand across multiple systems;
- changes that materially benefit from isolated review or rollback.

Do not create a branch solely as routine ceremony for a minor edit. If work that
began as a small `main` change expands materially, stop and create a branch before
continuing the expanded implementation.

Pull requests are expected for branch-based work and whenever the user explicitly
requests isolated review. Minor direct-to-`main` changes still require focused
commits, appropriate validation, and a clean synchronized repository state.

When a branch is merged:

- use a merge commit unless the user explicitly chooses another method;
- do not squash or rebase when documentation or handoffs reference individual
  commit SHAs;
- delete local and remote branches only after merged `main` is synchronized and
  the required validation has passed.

Explicit user instructions may override this default branch policy.

## File Reading Strategy

Large files must be processed incrementally.

Recommended approach:

1. Inspect file metadata.
2. Identify relevant sections.
3. Read in logical chunks.
4. Reassemble the required context.
5. Modify only the required content.
6. Update the file using the complete validated content.
7. Commit the change with a descriptive message.

## Large File Modification Workflow

When modifying large repository files:

1. Fetch large files in chunks.
2. Reassemble the file contents before editing.
3. Apply the requested change while preserving unrelated content.
4. Validate that no sections were removed accidentally.
5. Update the file.
6. Commit the change.

Do not repeatedly explain tooling limitations when the workflow can proceed. Continue with the established chunked fetch -> edit -> update -> commit process.

## Repository Audit Protocol

For repository audits:

1. Read authoritative entry documents.
2. Use repository maps/inventory.
3. Inspect actual files.
4. Compare findings against documentation.
5. Report discrepancies.

Do not infer repository state from previously opened files alone.

## Evidence-Based Responses

Avoid unsupported completion claims.

Responses should identify:

- sources checked.
- files inspected.
- validation performed.
- remaining uncertainty.

Do not claim completion, verification, or successful validation unless evidence exists.

## Completion Rules

Completion statements require:

1. Action performed.
2. Result verified.
3. Evidence available.

Distinguish between:

- planned
- in progress
- completed
- verified

## AI Change Scope Rules

Before modifying files:

1. Identify the smallest required file set.
2. Avoid unrelated cleanup.
3. Do not restructure folders without documentation updates.
4. Update documentation when changing workflows.
5. Prefer additive changes over destructive changes.

## Session Handoff Protocol

A session handoff is a current continuation record, not a substitute for reading the repository.

### Mandatory handoff opening block

Every newly created or substantially revised session handoff must begin with a prominent instruction block requiring the next assistant to:

1. Read `README.md` completely, not superficially and not merely scan headings.
2. Read every document that `README.md` identifies or requires for repository work.
3. Read `00_Documentation/AIRepositoryWorkflow.md` completely and abide by it.
4. Read every applicable document required or referenced by the AI workflow.
5. Read `RepositoryStructure.txt`, `RepositoryInventory.json`, relevant operational documentation, `Scrapbook.md`, and the current handoff.
6. Treat explicit user instructions and the verified current repository/documentation set as authoritative sources.
7. Verify current repository state before making assumptions, recommendations, status claims, or changes.

The block must state that a handoff summary and previous chat memory are subordinate to current authoritative repository sources.

### Before creating or revising a handoff

Verify:

- the full current README and AI workflow have been read;
- all documents they require for the task have been read;
- existing handoff files have been inspected;
- current repository, branch, commit, and working-tree state have been verified when available;
- the latest relevant continuation point has been identified;
- stale, raw, temporary, contradictory, or superseded handoffs have been identified.

### Handoff maintenance and cleanup

Keep the handoff directory concise. Normally retain one active continuation handoff.

Before publishing a new active handoff:

1. Move durable project facts into the appropriate canonical documents, such as Roadmap, feature documentation, Scrapbook, README, or workflow guidance.
2. Preserve implementation history through commits, merged pull requests, and canonical feature documents rather than accumulating active handoffs.
3. Remove superseded continuation handoffs after their still-relevant information has been incorporated into the new handoff or canonical documentation.
4. Remove raw chat dumps, temporary notes, poorly named files, pre-merge checkpoints, and records that contain obsolete branch, PR, test, or next-action instructions.
5. Retain an older handoff only when it has continuing historical value and is clearly labeled as historical and non-authoritative for current work.
6. Regenerate repository maps when handoff files are added, removed, renamed, or moved.

Do not preserve a stale handoff merely because it once described valid work. Git history remains available for historical recovery.

### Required handoff contents

A current handoff should contain:

- scope reviewed;
- authoritative files inspected;
- work completed;
- tests and validation actually performed;
- current repository and sprint status;
- decisions and safety boundaries;
- unresolved items;
- exact next action boundary;
- stale-handoff cleanup performed or explicitly deferred;
- a reminder to re-verify current repository state in the next session.

Avoid brittle instructions tied to an ephemeral local state when the next session can verify that state directly.

## Code Creation Requirements

Before creating or modifying code:

1. Identify the language, runtime, and tooling requirements.
2. Read the applicable standards documentation.
3. Read environment requirements for the affected toolchain.
4. Inspect existing implementations before creating new ones.
5. Follow repository-specific versions and conventions.

## Documentation Authority

Priority order:

1. README.md
2. AIRepositoryWorkflow.md
3. RepositoryStructure.txt
4. Individual documentation files
5. Scrapbook.md

Generated files describe the current repository state. They should not be manually edited unless specifically required.

## Priority Order

Preferred reading order:

1. Documentation
2. Configuration
3. PowerShell scripts
4. Tests
5. Project files
6. Generated data

## Repository Boundaries

| Area | Purpose |
|---|---|
| 00_Documentation | Human and AI knowledge base |
| 01-09 | Data containers and operational areas |
| 10_Scripts | Automation source |
| 11_Utilities | Supporting tools |
| 16_Profiles | Environment configuration |

## Change Discipline

Before modifying files:

- understand existing structure
- inspect related documentation
- preserve existing conventions
- avoid unrelated changes
