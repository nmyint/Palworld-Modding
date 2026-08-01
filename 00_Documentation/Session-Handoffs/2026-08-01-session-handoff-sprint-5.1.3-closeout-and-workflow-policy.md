# Session Handoff - Sprint 5.1.3 Closeout and Workflow Policy

**Date:** 2026-08-01  
**Repository:** `nmyint/Palworld-Modding`  
**Authoritative branch:** `main`  
**Sprint state:** Sprint 5.1.3 complete; Sprint 5.1.4 next planned

## Mandatory startup instructions

**Before answering any repository-specific question, making recommendations,
planning work, or modifying files, the AI assistant must complete all of the
following:**

1. Read `README.md` completely from beginning to end. Do not skim it, read only
   excerpts, or begin making assumptions after a superficial scan.
2. Follow and read every document that `README.md` identifies as required or
   authoritative for the requested work.
3. Read `00_Documentation/RepositoryStructure.txt` and
   `00_Documentation/RepositoryInventory.json` to verify the current repository
   layout.
4. Read `00_Documentation/AIRepositoryWorkflow.md` completely from beginning to
   end, follow every document it requires, and strictly abide by its workflow and
   safety rules.
5. Read all operational, standards, design, roadmap, handoff, and implementation
   documents indicated by those authoritative sources and relevant to the task.
6. Read `00_Documentation/Scrapbook.md` completely and preserve its working
   agreement, accepted decisions, and documented precedence rules.
7. Read this handoff and any newer relevant handoff before deciding the current
   continuation point.
8. Treat the current repository, `README.md`, `AIRepositoryWorkflow.md`, every
   document they require, the repository maps, relevant operational documents,
   and `Scrapbook.md` as authoritative sources according to their documented
   precedence. Do not allow conversation memory, cached context, prior answers,
   or assumptions to override them.
9. If any required source cannot be read completely, state exactly what remains
   unverified. Do not claim compliance, infer repository state, or proceed from
   assumptions as though the mandatory reading were complete.

These instructions are a compliance gate, not a suggested reading list. Reading
only this handoff is not sufficient preparation for repository work.

## Purpose

Provide a clean continuation point for a new ChatGPT session after completing
Sprint 5.1.3, merging it to `main`, validating the merged result locally, and
updating repository workflow guidance so branch usage is proportional to change
size and risk.

This handoff summarizes current state. It does not override explicit user
instructions, the mandatory startup instructions above, or newer authoritative
repository content.

## Authoritative reading order

After satisfying the mandatory startup instructions, use this reading order to
confirm completion:

1. `README.md`, read completely.
2. Every required document referenced by `README.md`.
3. `00_Documentation/RepositoryStructure.txt`.
4. `00_Documentation/RepositoryInventory.json`.
5. `00_Documentation/AIRepositoryWorkflow.md`, read completely and obeyed.
6. Every required document referenced by `AIRepositoryWorkflow.md`.
7. Operational and standards documents relevant to the requested task.
8. `00_Documentation/Scrapbook.md`, read completely.
9. This handoff and any newer relevant handoff.

Do not rely on conversation memory when current repository content can be
verified.

## Verified Sprint 5.1.3 completion

Sprint 5.1.3 delivered the public command:

```powershell
Get-PwWorkshopDashboard
```

The dashboard is a structured, deterministic, read-only snapshot over the
existing Workshop, Repository, Profile, Catalog, Deployment, UpdateCache, and
Diagnostics providers.

Key boundaries:

- existing commands remain authoritative;
- provider failures are isolated by section;
- dashboard completeness is separate from subsystem health;
- repository information uses local read-only Git commands;
- the dashboard does not fetch, pull, refresh remote metadata, build, deploy,
  restore, or mutate workshop/game state;
- output is independent of terminal formatting and serializes to JSON.

Authoritative implementation and documentation:

- `10_Scripts/Commands/WorkshopDashboard.ps1`
- `10_Scripts/Tests/WorkshopDashboard.Tests.ps1`
- `00_Documentation/WorkshopDashboard.md`

## Merge record

Sprint 5.1.3 was merged through GitHub pull request #4 using a merge commit.

```text
PR: #4 - Complete Sprint 5.1.3 dashboard data model
Merge commit: a8a5f630da14e498be477ae4123968a960cb20b0
```

The feature branch contained 16 commits and changed 14 files. No squash or
rebase was used because repository documentation and handoffs preserve commit
history and SHA references.

## Local validation evidence

The user synchronized local `main` to the merge commit and verified:

```text
Branch: main
Upstream: origin/main
Working tree: clean
HEAD: a8a5f63 Merge pull request #4 from nmyint/agent/sprint-5.1.3-dashboard-data-model
```

Complete local suite under PowerShell 7.6.4 and Pester 3.4.0:

```text
Passed: 145
Failed: 0
Skipped: 0
Pending: 0
Inconclusive: 0
```

The user also confirmed that `main` contains the merge commit and that
`git status --short` returned no changes.

Do not claim newer test results unless they are actually run.

## Workflow-policy decision

The user explicitly decided that branches must be created only when they provide
meaningful value.

### Work directly on `main`

Use `main` for minor, low-risk, clearly bounded work such as:

- small documentation corrections;
- narrow workflow clarifications;
- simple metadata/configuration maintenance;
- focused fixes whose scope and impact are already understood.

Minor direct-to-`main` work still requires:

- a focused commit;
- appropriate validation;
- review of the changed paths;
- a clean synchronized repository state.

### Create a dedicated branch

Use a branch for:

- a new sprint or major milestone;
- a major feature or broad behavioral change;
- a risky refactor or migration;
- experimental work that may be discarded;
- uncertain scope that may expand across multiple systems;
- work that materially benefits from isolated review or rollback.

Do not create a branch merely because a file is being edited. If work begins as
a small `main` change and expands materially, stop and create a branch before
continuing the expanded scope.

Branch-based work normally uses a pull request and merge commit. Delete local and
remote branches only after merged `main` is synchronized locally and required
validation has passed.

This policy is now recorded in:

- `00_Documentation/AIRepositoryWorkflow.md`
- `00_Documentation/ChangeManagement.md`
- `00_Documentation/Scrapbook.md`
- `CONTRIBUTING.md`

Documentation commits applied directly to `main`:

```text
9f9bde2 docs(workflow): define proportional branch policy
5aa2459 docs(contributing): clarify when branches are required
212fb06 docs(change): add proportional branch guidance
165cc77 docs(scrapbook): record proportional branch policy
```

## Branch state and cleanup

The completed Sprint 5.1.3 branch and the accidentally created empty Pw-Git
planning branch were removed locally and remotely after merge validation.

The user returned to clean `main`.

Historical branches still visible during the final check:

```text
agent/nexus-update-download-flow
origin/agent/nexus-update-download-flow
origin/docs/pw-git-v1.3-pull-diagnostics
```

These branches do not affect `main`. Review them in a later maintenance pass
before deletion; do not remove them automatically.

## Accepted future Pw-Git direction

The following decisions were accepted for later Pw-Git integration. They are not
implemented yet.

### 1. Unified update workflow

Add a main-menu option:

```text
[U] Update repository
```

and a matching direct command:

```powershell
pwsh -NoProfile -File ./pw-git.ps1 update
```

The intended guided sequence is:

```text
Preflight
-> Fetch
-> Compare
-> Fast-forward pull when behind
-> Check repository-map structural freshness
-> Refresh maps only when structurally required
-> Run repository-map tests
-> Run git diff --check
-> Stage only intended generated maps when changed
-> Review/commit with confirmation
-> Push with confirmation
-> Final status
```

The workflow must never:

- stage unrelated files;
- silently resolve conflicts;
- automatically stash, discard, delete, or move user work;
- force-push;
- merge without explicit approval.

### 2. Repository-map refresh optimization

Repository maps should require regeneration only when the stable mapped
structure changes, including:

- included files/directories added or removed;
- paths renamed or moved;
- an extension changes between included and excluded;
- exporter inclusion, exclusion, or traversal rules change.

Content-only edits to an existing included file should not require map refresh.

Current exporter behavior is not yet optimized because complete output hashes
include changing provenance fields such as:

- `Generated`;
- `Branch`;
- `CommitSHA`.

Future freshness logic should compare the stable structural model instead of
those volatile metadata fields. When structure is unchanged, no generated file
should be rewritten. A deliberate force-refresh option may remain available.

### 3. Pull diagnostics

Pw-Git v1.3 planning already includes clearer blocked-pull diagnostics:

- show exact tracked, untracked, or conflicted blocking paths;
- present an expected `[BLOCKED]` safety result;
- provide recovery guidance;
- preserve fast-forward-only and clean-tree safety;
- never automatically mutate blocking files.

### 4. Branch and merge support

Future Pw-Git branch/merge UX should support branches when genuinely needed. It
must not force every minor edit through branch creation, pull request, merge, and
deletion ceremony.

## Next Sprint boundary

Sprint 5.1.4, menu UX integration, is the next planned Sprint 5.1 increment.
Because it is a new sprint and will change user-facing behavior, a dedicated
branch is appropriate when implementation begins.

Sprint 5.1.4 should present the completed dashboard model through the existing
adaptive workshop menu without duplicating provider logic or changing the
read-only dashboard contract.

Sprint 5.1.5 remains responsible for broader repository, documentation,
configuration, module, and test-health reporting.

The user may choose to prioritize Pw-Git work before Sprint 5.1.4. Verify the
requested priority at the start of the next session rather than assuming it.

## Working agreement for the next session

- Use standard ChatGPT as the default environment.
- Do not invoke or recommend Work mode or Codex unless the user explicitly
  changes that decision.
- Use the GitHub connector to verify repository state and perform approved
  repository writes.
- Follow exact stepwise PowerShell commands when local execution is required.
- Let the user paste command output before advancing through risky operations.
- Never fabricate tests, logs, branches, commits, or repository state.
- Never claim completion without verification.
- Preserve the separation between PwWorkshop and Pw-Git.
- Do not expand scope into Sprint 5.1.4, Sprint 5.1.5, or Pw-Git implementation
  without explicit user direction.

## Final synchronized state before this instruction amendment

After publishing the original handoff and refreshing the repository maps, the
user verified the following local and remote state:

```text
Repository: D:\Projects\Palworld-Modding
Branch: main
Upstream: origin/main
Working tree: clean
HEAD: d29a1cc docs(repo): refresh maps after session handoff
Previous: d060e1f docs(handoff): record Sprint 5.1.3 closeout and workflow policy
```

The complete workshop validation remains the verified Sprint 5.1.3 result of
145 passed and 0 failed. The focused repository-map suite was required and run
during the original handoff/map closeout; do not invent a newer result.

This instruction amendment modifies only the contents of the existing handoff
file. It does not add, remove, rename, or move a mapped path, so it does **not**
require another repository-map refresh.

At the beginning of the next session, fetch, compare, and fast-forward pull
`main` before relying on a commit SHA or repository state recorded here.

## Session closeout status

**The session is ready to continue in a new conversation after this handoff
instruction amendment is synchronized locally.**

The next session must begin by completing the mandatory startup instructions at
the top of this file, verifying actual current repository state, and confirming
whether the next objective is Sprint 5.1.4 or the planned Pw-Git improvements.
