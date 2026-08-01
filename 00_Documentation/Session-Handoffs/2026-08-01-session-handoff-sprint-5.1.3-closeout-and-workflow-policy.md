> **MANDATORY STARTUP GATE — COMPLETE BEFORE ANY REPOSITORY-SPECIFIC RESPONSE OR ACTION**
>
> 1. Read `README.md` completely. Do not skim it, scan only headings, or begin from assumptions.
> 2. Read every document that `README.md` identifies or requires for repository work.
> 3. Read `00_Documentation/AIRepositoryWorkflow.md` completely and abide by every applicable rule.
> 4. Read every applicable document required or referenced by the AI workflow.
> 5. Read `00_Documentation/RepositoryStructure.txt`, `00_Documentation/RepositoryInventory.json`, the relevant operational documentation, `00_Documentation/Scrapbook.md`, and this handoff.
> 6. Treat explicit current user instructions and the verified current repository/documentation set as authoritative sources.
> 7. Verify current repository state before making assumptions, recommendations, status claims, or changes.
>
> This handoff and previous chat memory are summaries only. They are subordinate to explicit user instructions and current authoritative repository sources.

# Session Handoff - Sprint 5.1.3 Closeout and Workflow Policy

**Date:** 2026-08-01  
**Repository:** `nmyint/Palworld-Modding`  
**Authoritative branch:** `main`  
**Sprint state:** Sprint 5.1.3 complete; Sprint 5.1.4 next planned

## Purpose

Provide one clean continuation point for a new ChatGPT session after completing Sprint 5.1.3, merging and validating it, adopting proportional branch usage, recording accepted future Pw-Git improvements, and removing stale session-handoff material.

This is the only active continuation handoff. Durable project facts remain in canonical documentation, implementation, Git history, and merged pull requests.

## Required authoritative reading order

Before continuing repository work:

1. Read `README.md` completely.
2. Follow and read every document it requires for the requested task.
3. Read `00_Documentation/AIRepositoryWorkflow.md` completely.
4. Follow and read every applicable document it requires or references.
5. Read `00_Documentation/RepositoryStructure.txt`.
6. Read `00_Documentation/RepositoryInventory.json`.
7. Read the relevant operational documentation.
8. Read `00_Documentation/Scrapbook.md` completely.
9. Read this handoff.
10. Verify actual current repository state before proceeding.

Do not use previous conversation context as a substitute for this reading order.

## Verified Sprint 5.1.3 completion

Sprint 5.1.3 delivered:

```powershell
Get-PwWorkshopDashboard
```

The dashboard is a structured, deterministic, read-only snapshot over the existing Workshop, Repository, Profile, Catalog, Deployment, UpdateCache, and Diagnostics providers.

Authoritative implementation and documentation:

- `10_Scripts/Commands/WorkshopDashboard.ps1`
- `10_Scripts/Tests/WorkshopDashboard.Tests.ps1`
- `00_Documentation/WorkshopDashboard.md`
- `00_Documentation/Roadmap.md`

Safety boundaries:

- existing commands remain authoritative;
- provider failures are isolated by section;
- dashboard collection completeness is separate from subsystem health;
- repository information uses local read-only Git commands;
- dashboard collection does not fetch, pull, refresh remote metadata, build, deploy, restore, or mutate workshop/game state;
- output remains independent of terminal formatting and serializes to JSON.

## Merge and validation record

Sprint 5.1.3 was merged through GitHub pull request #4 using a merge commit:

```text
PR: #4 - Complete Sprint 5.1.3 dashboard data model
Merge commit: a8a5f630da14e498be477ae4123968a960cb20b0
```

The repository owner synchronized local `main` and verified under PowerShell 7.6.4 and Pester 3.4.0:

```text
Passed: 145
Failed: 0
Skipped: 0
Pending: 0
Inconclusive: 0
```

The last explicitly reported clean synchronized closeout before this handoff-maintenance update was:

```text
Branch: main
Upstream: origin/main
Working tree: clean
HEAD: d29a1cc docs(repo): refresh maps after session handoff
```

A future session must fetch and verify current state rather than assuming this historical checkpoint is still HEAD.

## Active branch policy

Use Git workflow proportional to change size and risk.

### Work directly on `main`

Use `main` for minor, low-risk, clearly bounded work such as:

- small documentation corrections;
- narrow workflow clarifications;
- simple metadata or configuration maintenance;
- focused fixes whose scope and impact are already understood.

Direct-to-`main` work still requires focused commits, appropriate validation, reviewed paths, and a clean synchronized repository state.

### Create a dedicated branch

Use a branch for:

- a new sprint or major milestone;
- a major feature or broad behavioral change;
- a risky refactor or migration;
- experimental work that may be discarded;
- uncertain scope that may expand across multiple systems;
- work that materially benefits from isolated review or rollback.

Do not create branches as routine ceremony. If a small change begins on `main` and expands materially, stop and create a branch before continuing the expanded scope.

Branch-based work normally uses a pull request and merge commit. Delete merged branches only after local `main` is synchronized and required validation passes.

## Accepted future Pw-Git direction

The following direction is accepted but not yet implemented.

### Unified update workflow

Add:

```text
[U] Update repository
```

with matching direct command:

```powershell
pwsh -NoProfile -File ./pw-git.ps1 update
```

Intended sequence:

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

It must never stage unrelated files, silently resolve conflicts, automatically stash/discard/move/delete user work, force-push, or merge without explicit approval.

### Repository-map refresh optimization

Refresh maps only when the stable mapped structure changes:

- included files/directories are added or removed;
- paths are renamed or moved;
- extensions cross included/excluded boundaries;
- exporter inclusion, exclusion, or traversal rules change.

Content-only edits to an existing included file should not require map refresh.

Future freshness checks must ignore volatile provenance fields such as `Generated`, `Branch`, and `CommitSHA` when deciding whether structure changed. When structure is unchanged, generated map files should not be rewritten. An explicit force-refresh option may remain available.

### Pull diagnostics

Planned Pw-Git v1.3 diagnostics should:

- show exact tracked, untracked, or conflicted blocking paths;
- present expected blocked safety results clearly;
- provide actionable recovery guidance;
- preserve clean-tree and fast-forward-only pull safeguards;
- never automatically mutate blocking files.

### Branch and merge support

Future Pw-Git branch/merge UX should support branches only when genuinely needed. It must not force minor edits through branch creation, PR, merge, and deletion ceremony.

## Handoff maintenance policy

Future handoffs must follow the procedure now recorded in `00_Documentation/AIRepositoryWorkflow.md`:

- begin with the mandatory startup gate used at the top of this file;
- require complete reading of README and the AI workflow, including every applicable referenced document;
- treat current user instructions and verified repository documentation/state as authoritative;
- verify actual repository state instead of inheriting assumptions;
- inspect all existing handoffs before publishing a new one;
- normally retain one active continuation handoff;
- move durable facts into canonical documentation;
- remove superseded continuation files, raw chat dumps, temporary notes, pre-merge checkpoints, poorly named files, and records with obsolete branch/PR/test/next-action guidance;
- regenerate repository maps whenever handoff paths are added, removed, renamed, or moved.

Git history and merged PRs preserve historical records. Stale handoffs do not need to remain active documentation.

## Stale-handoff audit and cleanup

The handoff directory was audited during this maintenance pass.

Files identified for removal include:

- raw chat or Codex transcripts;
- the poorly named 2026-07-30 raw handoff dump;
- Pw-Git kickoff, v1.1, v1.2 checkpoint, and redundant review records superseded by current canonical Pw-Git documentation;
- interim Nexus foundation/menu/cache records that still describe merged PR #2 as open or draft;
- AI-workflow review checkpoints superseded by the current workflow;
- the pre-PR Sprint 5.1.3 completion handoff superseded by this merged closeout record;
- older sprint-state correction records now represented in Roadmap and Scrapbook.

After cleanup, this file is the active continuation handoff. Historical details remain recoverable through Git history, canonical documents, and merged pull requests.

## Next development boundary

Sprint 5.1.4, menu UX integration, is the next planned Sprint 5.1 increment. Because it is a new sprint and changes user-facing behavior, a dedicated branch is appropriate when implementation begins.

Sprint 5.1.4 should present the completed dashboard model through the existing adaptive workshop menu without duplicating provider logic or changing the read-only dashboard contract.

Sprint 5.1.5 remains responsible for broader repository, documentation, configuration, module, and test-health reporting.

The user may choose to prioritize Pw-Git improvements before Sprint 5.1.4. Confirm the requested priority at the start of the next session rather than assuming it.

## Working agreement for the next session

- Use standard ChatGPT as the default environment.
- Do not invoke or recommend Work mode or Codex unless the user explicitly changes that decision.
- Use the GitHub connector to verify repository state and perform approved repository writes.
- Follow exact stepwise PowerShell commands when local execution is required.
- Let the user paste command output before advancing through risky operations.
- Never fabricate tests, logs, branches, commits, or repository state.
- Never claim completion without verification.
- Preserve the separation between PwWorkshop and Pw-Git.
- Do not expand scope into Sprint 5.1.4, Sprint 5.1.5, or Pw-Git implementation without explicit user direction.

## New-session starting action

The next session must first complete the mandatory startup gate, verify current `main`, and then confirm whether the objective is:

1. Sprint 5.1.4 menu UX integration; or
2. the accepted Pw-Git improvements.

Do not begin implementation before that verification and scope confirmation.
