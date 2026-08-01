# Documentation Audit — Current Status

**Reviewed:** 2026-08-01  
**Repository:** `nmyint/Palworld-Modding`  
**Branch:** `main`

## Purpose

Track verified documentation inconsistencies without reopening completed
milestones or expanding implementation scope. This document replaces older audit
snapshots whose findings no longer match the repository.

## Current assessment

The operational documentation describes the accepted Sprint 4 boundary, the
current menu workflows, the established staging/library/deployment model,
Pw-Git v1.2, the persistent Nexus metadata workflow, and the active Sprint 5.1
sequence accurately enough to serve as the project knowledge base.

Sprint 5 remains active. Sprint 5.1.1, repository awareness and structure
documentation; Sprint 5.1.2, workshop runtime and session model; and Sprint
5.1.3, the dashboard data model, are complete. Sprint 5.1.4, menu UX integration,
is active with a validated implementation checkpoint.

The documentation set still has maintenance items, but none invalidate the
accepted Sprint 1–4 milestones or the completed Sprint 5.1.1 through 5.1.3
boundaries.

## Resolved findings

The following earlier findings have been corrected:

- `Scrapbook.md` uses consistent tracked casing and is discoverable from the
  repository entry workflow.
- `Scrapbook.md` assigns the workspace foundation, module foundation, safe
  automation, and mod-library/compatibility outcomes to Sprints 1, 2, 3, and 4
  respectively instead of attributing early foundation work to Sprint 4.
- `Roadmap.md`, `README.md`, and `Scrapbook.md` consistently mark Sprint 4 as
  complete, Sprint 5 as active, Sprint 5.1.1 through 5.1.3 as complete, and
  Sprint 5.1.4 as active.
- `Environment.md` provides the operator-facing documentation for
  `10_Scripts\Core\Bootstrap.ps1`, including initialization, context lifetime,
  reset behavior, structured output, read-only startup, and durable-state
  boundaries, and links the completed dashboard composition layer.
- `WorkshopDashboard.md` documents the fixed dashboard schema, existing-command
  authority, failure isolation, local Git boundary, serialization contract, and
  verified read-only behavior.
- Repository/document required-path, link, map-freshness, module,
  configuration, and test-health checks are assigned explicitly to Sprint
  5.1.5 rather than retained as an artificial blocker for the completed
  repository exporter or dashboard milestones.
- The repository structure exporter includes the intended configuration,
  documentation, module, and generated-map scope.
- The repository structure exporter excludes `.git` and local `.cache` state.
- `RepositoryStructure.txt` and `RepositoryInventory.json` were regenerated and
  committed after the Nexus metadata, map-hygiene, dashboard-model, and handoff
  cleanup work.
- `Pw-Git.md` provides durable operator documentation and records the completed
  v1.2 command and safety model without depending on a deleted historical
  handoff.
- `ModCatalog.md` describes the current catalog, ownership, compatibility,
  profile assembly, and preview-only upgrade/removal capabilities.
- `UpdateSources.md` documents `U` as the UE4SS baseline action and `B` as
  back/cancel.
- `NexusUpdates.md` documents the persistent catalog-wide metadata snapshot,
  lazy content inventories, explicit refresh behavior, and guarded downloads.
- `FolderStructure.md` documents the actual experiment path:
  `15_Sandbox\ProfileExperiments\<timestamp>-<Profile>-<Label>`.
- `ModCatalog.md` explains that `CanApply` is a forward-compatible plan
  readiness flag, not evidence that an apply command exists.
- `Recovery.md` explicitly states that restoration is not a complete uninstall
  or full-state rollback.
- `ModIntake.md` distinguishes the active game-shaped staging mirror from the
  legacy per-package cleanup path used by `Complete-PwModInstallation`.
- The handoff directory was audited and reduced to one active continuation
  record. Raw transcripts, temporary checkpoints, obsolete pre-merge records,
  and contradictory continuation files were removed; Git history and merged
  pull requests preserve their historical record.
- `SessionStartup.md`, `README.md`, and `AIRepositoryWorkflow.md` now define two
  canonical new-session modes: new project/implementation and handoff
  continuation.
- The startup policy now requires silent completion of the full startup gate in
  one assistant turn. Acknowledgements, progress updates, apologies, plans,
  promises, partial summaries, and lists of remaining reading are prohibited
  before a completed result or genuine concise hard-blocker report.
- The adaptive workshop menu now consumes one dashboard snapshot per redraw and
  uses a durable control-center label instead of a transient sprint label.
- The `Start-PwWorkshop` help and module-version test no longer describe Sprint
  4 as current work.
- The main-menu key reader accepts the displayed inventory (`9`) and history
  (`0`) actions.

## Remaining verified findings

### 1. Legacy completion cleanup path

`Complete-PwModInstallation` still calculates its staging cleanup target as:

```text
02_Staging\<Name>\<Version>
```

Current archive intake and profile assembly use the active game-shaped tree
beneath `02_Staging\Pal`. The documentation states this accurately, but the
implementation contract should be reviewed separately before changing cleanup
behavior.

### 2. PowerShell runtime contract

The repository documentation identifies PowerShell 7.6.4 as the supported and
tested runtime. The module manifest still declares:

```powershell
PowerShellVersion = '7.0'
```

A later implementation review must decide whether 7.0 is the true minimum or
whether the manifest should require 7.6.4.

### 3. Authority hierarchy duplication

`README.md`, `AIRepositoryWorkflow.md`, `SessionStartup.md`, and `Scrapbook.md`
describe repository authority and reading order with overlapping wording. Their
current direction is compatible, but future maintenance should keep the exact
startup prompts centralized in `SessionStartup.md` and avoid introducing new
competing copies.

### 4. Automated documentation and health validation

There is no dedicated health suite validating exact path casing, internal links,
documented menu keys, required documents, generated-map freshness, module
health, configuration health, and completed-feature language. This work remains
explicitly assigned to Sprint 5.1.5.

## Explicitly outside this correction

The following were reviewed but not changed:

- transactional profile assembly;
- `CanApply` implementation behavior;
- upgrade or removal apply commands;
- semantic analysis or merging of PAK contents;
- semantic interaction analysis between separate Lua mods;
- broad menu UX redesign;
- Sprint 5.1.5 health-check implementation.

## Status

**Sprint 5.1.3 dashboard documentation reconciliation and session-startup policy
reconciliation complete.**

The remaining findings are assigned to later implementation or maintenance
work. They must not be treated as unfinished Sprint 4 or Sprint 5.1.1 through
5.1.3 work unless the project owner explicitly changes an accepted milestone
boundary.
