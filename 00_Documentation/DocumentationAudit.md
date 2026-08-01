# Documentation Audit — Current Status

**Reviewed:** 2026-07-31  
**Repository:** `nmyint/Palworld-Modding`  
**Branch:** `agent/nexus-update-download-flow`

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
documentation, and Sprint 5.1.2, workshop runtime and session model, are complete.
Sprint 5.1.3, the dashboard data model, is the next planned Sprint 5.1 increment.

The documentation set still has maintenance items, but none invalidate the
accepted Sprint 1–4 milestones or the completed Sprint 5.1.1 and 5.1.2
boundaries.

## Resolved findings

The following earlier findings have been corrected:

- `Scrapbook.md` uses consistent tracked casing and is discoverable from the
  repository entry workflow.
- `Scrapbook.md` now assigns the workspace foundation, module foundation, safe
  automation, and mod-library/compatibility outcomes to Sprints 1, 2, 3, and 4
  respectively instead of attributing early foundation work to Sprint 4.
- `Roadmap.md`, `README.md`, and `Scrapbook.md` consistently mark Sprint 4 as
  complete, Sprint 5 as active, Sprint 5.1.1 and 5.1.2 as complete, and Sprint
  5.1.3 as next planned.
- `Environment.md` now provides the operator-facing documentation for
  `10_Scripts\Core\Bootstrap.ps1`, including initialization, context lifetime,
  reset behavior, structured output, read-only startup, and durable-state
  boundaries.
- Repository/document required-path, link, map-freshness, module,
  configuration, and test-health checks are assigned explicitly to Sprint
  5.1.5 rather than retained as an artificial blocker for the completed
  repository exporter milestone.
- The repository structure exporter includes the intended configuration,
  documentation, module, and generated-map scope.
- The repository structure exporter excludes `.git` and local `.cache` state.
- `RepositoryStructure.txt` and `RepositoryInventory.json` were regenerated and
  committed after the Nexus metadata and map-hygiene work.
- `Pw-Git.md` provides durable operator documentation and records the completed
  v1.2 command and safety model.
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

`README.md`, `AIRepositoryWorkflow.md`, and `Scrapbook.md` describe repository
authority and reading order with overlapping wording. Their current direction is
compatible, but the rules should eventually be consolidated so only one document
defines precedence.

### 4. Historical handoff hygiene

Some older files under `00_Documentation/Session-Handoffs` contain raw or poorly
named historical material. Current Nexus and Pw-Git handoffs are structured, but
older records should eventually be archived or standardized without altering
authoritative current documentation.

### 5. Automated documentation and health validation

There is no dedicated health suite validating exact path casing, internal links,
documented menu keys, required documents, generated-map freshness, module
health, configuration health, and completed-feature language. This work is now
explicitly assigned to Sprint 5.1.5.

### 6. Transient sprint labels in implementation text

The interactive menu header still contains:

```text
Sprint 4 - Catalog, Library, and Compatibility
```

`Start-PwWorkshop` comment-based help and one module-test description also retain
Sprint 4-era wording. These strings do not define project status, but they are
stale operator/developer text. Durable product/workflow labels are assigned to
Sprint 5.1.4 menu UX integration so the interface does not require a code change
every time the roadmap advances.

## Explicitly outside this correction

The following were reviewed but not changed:

- transactional profile assembly;
- `CanApply` implementation behavior;
- upgrade or removal apply commands;
- semantic analysis or merging of PAK contents;
- semantic interaction analysis between separate Lua mods;
- dashboard implementation;
- broad menu UX redesign;
- Sprint 5.1.5 health-check implementation.

## Status

**Sprint-state and Bootstrap documentation correction complete.**

The remaining findings are assigned to later implementation or maintenance
work. They must not be treated as unfinished Sprint 4, Sprint 5.1.1, or Sprint
5.1.2 work unless the project owner explicitly changes an accepted milestone
boundary.
