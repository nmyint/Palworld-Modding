# Documentation Audit — Current Status

**Reviewed:** 2026-07-31  
**Repository:** `nmyint/Palworld-Modding`  
**Branch:** `main`

## Purpose

Track verified documentation inconsistencies without reopening completed
milestones or expanding implementation scope. This document replaces the older
audit snapshot whose findings no longer matched the repository.

## Current assessment

The operational documentation now describes the accepted Sprint 4 boundary,
the current menu workflows, the established staging/library/deployment model,
and Pw-Git v1.2 accurately enough to serve as the project knowledge base.

The documentation set still has several maintenance items, but none of them
invalidate the accepted Sprint 4 milestone or Pw-Git v1.2 closure.

## Resolved findings

The following earlier findings have been corrected:

- `Scrapbook.md` uses consistent tracked casing and is discoverable from the
  repository entry workflow.
- The repository structure exporter includes the intended configuration,
  documentation, module, and generated-map scope.
- `RepositoryStructure.txt` and `RepositoryInventory.json` were regenerated
  after the dedicated Pw-Git v1.2 handoff was added.
- `Pw-Git.md` provides durable operator documentation and records the completed
  v1.2 command and safety model.
- `Roadmap.md`, `README.md`, and `ModCatalog.md` consistently mark Sprint 4 as
  complete and Sprint 5 as active.
- `ModCatalog.md` describes the current catalog, ownership, compatibility,
  profile assembly, and preview-only upgrade/removal capabilities.
- `UpdateSources.md` now documents `U` as the UE4SS baseline action and `B` as
  back/cancel.
- `NexusUpdates.md` no longer describes completed Sprint 4.1 or Sprint 4.2 work
  as future functionality.
- `FolderStructure.md` now documents the actual experiment path:
  `15_Sandbox\ProfileExperiments\<timestamp>-<Profile>-<Label>`.
- `ModCatalog.md` now explains that `CanApply` is a forward-compatible plan
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
beneath `02_Staging\Pal`. The documentation now states this accurately, but the
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

`README.md`, `AIRepositoryWorkflow.md`, and `Scrapbook.md` still describe
repository authority and reading order with overlapping wording. Their current
direction is compatible, but the rules should eventually be consolidated so
only one document defines precedence.

### 4. Historical handoff hygiene

Some older files under `00_Documentation/Session-Handoffs` contain raw or poorly
named historical material. Current Pw-Git handoffs are clean, but older records
should eventually be archived or standardized without altering authoritative
current documentation.

### 5. Automated documentation validation

There is no dedicated documentation test suite verifying exact path casing,
internal links, documented menu keys, required documents, and completed-feature
language. This remains a future repository-health improvement.

### 6. Sprint label embedded in the menu

The interactive menu header still contains the text:

```text
Sprint 4 - Catalog, Library, and Compatibility
```

The menu remains functional, and `WorkshopMenu.ps1` was intentionally left
untouched during this documentation-only correction. A future menu/UX review may
replace the sprint label with a durable product or workflow label.

## Explicitly outside this correction

The following were reviewed but not changed:

- transactional profile assembly;
- `CanApply` implementation behavior;
- upgrade or removal apply commands;
- semantic analysis or merging of PAK contents;
- semantic interaction analysis between separate Lua mods;
- Sprint or roadmap restructuring;
- `WorkshopMenu.ps1` implementation and help text.

## Status

**Documentation correction complete for the approved scope.**

The remaining findings require separate review and authorization. They must not
be treated as unfinished Sprint 4 work unless the project owner explicitly
changes the accepted milestone boundary.
