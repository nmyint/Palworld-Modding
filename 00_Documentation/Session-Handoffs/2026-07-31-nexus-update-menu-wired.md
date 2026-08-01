# Session Handoff - Nexus Update Menu Wiring

**Date:** 2026-07-31
**Repository:** `nmyint/Palworld-Modding`
**Branch:** `agent/nexus-update-download-flow`
**Pull request:** #2, open and draft

## Scope

Continue the Sprint 5 Nexus workflow without reopening completed Sprint 4. The
branch now combines:

- guarded option-4 update downloads;
- option-4 navigation and manual-download guidance;
- a persistent catalog-wide Nexus metadata snapshot;
- explicit refresh UX in menu 1 and menu 4; and
- a fix for menu 1 Remote Metadata when an incomplete catalog identity has no
  install-name alias.

Do not merge to `main` without the repository owner's explicit approval.

## Guarded Download Boundary

The option-4 direct-download flow:

- accepts only an exact `UpdateAvailable` report row;
- matches both Nexus mod ID and current remote file ID;
- refuses current, failed, incompatible-variant, missing-file, stale-file-ID,
  and empty-refreshed-report cases before mutation;
- shows the selected name, local and remote versions, variants, filename, file
  ID, and status;
- requires high-impact confirmation;
- retains the original explicit-ID `ShouldProcess`, `-Confirm`, and `-WhatIf`
  boundary;
- validates Premium status live;
- obtains the direct-download link live;
- downloads to a temporary path, inspects the archive, and only then moves it
  into `01_Archives`; and
- returns the archive path, SHA-256 hash, and option-2 import next step.

Manual browser download remains available for normal accounts. The menu displays
the resolved `01_Archives` path before opening Nexus. Browser completion is not
monitored; the completed ZIP or 7z must be saved into `01_Archives`, followed by
option-4 `R` and option 2 archive inspection/import.

## Nexus Metadata Usage Audit

Current workshop consumers use these Nexus fields:

- update reports: mod name/version and file ID, filename, version, category, and
  upload time;
- catalog metadata and identity review: name, version, summary, description,
  GitHub links, and framework hints;
- current-game adoption: identity data plus file name, version, category, size,
  and upload time;
- profile archive plans: mod data and latest compatible file;
- configured Nexus sources: mod version/description and latest file metadata;
- direct downloads: live Premium identity, current mod/file data, and a live
  transient download link.

Before this branch, these workflows independently repeated overlapping mod and
file-list API calls.

## Universal Nexus Metadata Snapshot

The single cache/API authority is:

```text
10_Scripts\Commands\NexusMetadataCache.ps1
```

It loads **before** `NexusUpdateMenuWiring.ps1`. The wiring file consumes the
cache services and contains only menu UX and download orchestration.

The local persistent snapshot is:

```text
.cache\NexusMetadata.json
```

`.cache` is ignored by Git. The snapshot covers every unique reviewed Nexus ID
known through:

- `03_Mod_Library\catalog.json`;
- surviving Nexus archives in `01_Archives`; and
- enabled configured Nexus sources.

For each ID it preserves the complete raw JSON returned by:

- `games/palworld/mods/{id}.json`;
- `games/palworld/mods/{id}/files.json`.

The full file-list response already contains complete per-file metadata,
including descriptions, changelog HTML, sizes, content-preview links, upload
times, virus-scan links, primary-file state, and file-update chains. Exact-file
reads are resolved from that cached list rather than causing per-file API fan-
out.

Existing commands continue calling `Invoke-PwNexusApi`. The shared API layer
routes supported mod, file-list, and exact-file reads to the snapshot, so menu
and module code parse one authoritative dataset.

### Deliberate exclusions

The snapshot does not separately request or store:

- API keys or credentials;
- API validation responses;
- tracked-mod or endorsement-list endpoints;
- transient direct-download links;
- archive contents or content-preview payloads;
- unrelated games, collections, comments, discovery feeds, or other user-
  specific endpoints.

The mod-info response is retained verbatim. If Nexus includes an optional
account-relative field inside that raw response, such as an inline endorsement
state, it is preserved with the response; no separate account-data request is
made to obtain it.

`users/validate.json` and `download_link.json` remain live-only.

## Snapshot Lifetime and Refresh

There is no automatic Nexus cache expiration.

- An absent or empty cache builds the complete catalog-wide snapshot, including
  when first reached through a single-mod request.
- Normal menu/module use reuses the disk snapshot indefinitely.
- Newly reviewed IDs are fetched incrementally without refreshing existing IDs.
- Menu 1 Remote Metadata `R` refreshes the complete snapshot and redraws the
  report in place.
- Menu 4 Updates `R` refreshes the complete Nexus snapshot, clears the short-
  lived GitHub source cache, and reruns both reports.
- A selected mod and full file list are refreshed immediately before an
  approved direct download.
- Menu 1 and menu 4 show the cache timestamp and ready-versus-catalog count.
- When a refresh fails, a prior known-good entry is retained and the refresh
  error/time is recorded and surfaced in the title.
- Cache writes use a temporary file followed by replacement of the final JSON
  path.

Local archives, catalog, profiles, and source configuration remain uncached and
are reread normally.

For approximately 30 unique mods, a complete refresh performs approximately 60
stable metadata requests: one mod-info and one full file-list request per ID.
Normal reads then reuse the snapshot until explicit refresh or catalog coverage
changes.

## Menu 1 Remote Metadata Fix

The observed exception:

```text
Index was outside the bounds of the array.
```

came from indexing the first `InstallNames` value without checking whether an
incomplete catalog record had one.

`Get-PwNexusCatalogMetadataReport` now:

- filters absent and blank install-name values safely;
- uses the first valid install name when available;
- falls back to `DisplayName`, then `CatalogKey`;
- keeps the record visible as `NeedsNexusId`; and
- no longer terminates the Remote Metadata screen.

## Menu UX

### Menu 1 - Remote Metadata

The screen title shows the Nexus cache timestamp and ready/catalog count.
Controls include:

- `A` store derived reviewed metadata;
- `V` verify a review item;
- `R` refresh the complete Nexus snapshot and redraw in place;
- `B` return to the catalog submenu; and
- `Q` exit.

### Menu 4 - Updates

The screen title shows the same Nexus cache timestamp and count. Controls
include:

- Nexus mod ID selection;
- `U` UE4SS baseline flow;
- `R` complete Nexus refresh plus GitHub source-cache clear;
- `B` or Enter to return to the main menu; and
- `Q` exit.

## Implementation Files

- `.gitignore`
- `10_Scripts/Commands/NexusMetadataCache.ps1`
- `10_Scripts/Commands/NexusUpdateDownloads.ps1`
- `10_Scripts/Commands/NexusUpdateMenuWiring.ps1`
- `10_Scripts/Commands/CatalogMetadata.ps1`
- `10_Scripts/Modules/PalworldModding.psm1`
- `10_Scripts/Tests/NexusUpdateMenuSafety.Tests.ps1`
- `10_Scripts/Tests/NexusUpdateMenuInteraction.Tests.ps1`
- `10_Scripts/Tests/NexusUpdateMenuWiring.Tests.ps1`
- `10_Scripts/Tests/NexusUpdateDownloads.Tests.ps1`
- `10_Scripts/Tests/CatalogMetadata.Tests.ps1`
- `00_Documentation/NexusUpdates.md`
- `00_Documentation/MenuFlow.md`

## Test Coverage Added

The focused tests cover:

- fail-closed refreshed-report behavior;
- explicit-ID `-WhatIf` safety;
- complete raw mod/file-list storage for every catalog ID;
- persistent disk reuse without repeated API calls;
- incremental retrieval of a newly reviewed ID;
- exact-file lookup from the full cached file list;
- live retrieval of every download-link response;
- GitHub metadata session caching and explicit clearing;
- menu 4 timestamp, `R`, and `B` behavior;
- menu 1 explicit refresh and redraw;
- manual browser handoff; and
- incomplete catalog records with no install names.

New Pester 3.4 cache/UX cases are isolated into separate `Describe` scopes to
avoid module-scoped mock leakage.

## Earlier Verified Checkpoint

The repository owner validated executable commit
`9baa746bab6054e1445a1de8fc9aefa1ba398af7` locally under PowerShell 7.6.4 and
Pester 3.4.0 on 2026-07-31:

- original safety suite: 2 passed, 0 failed;
- complete suite: 125 passed, 0 failed.

The persistent snapshot and menu 1 fix are later executable changes and have not
yet been locally validated.

## Required Local Validation

Because `NexusMetadataCache.ps1` is a new command file, regenerate the generated
repository maps **before** the complete Pester suite:

```powershell
.\10_Scripts\Utilities\Export-PwRepositoryStructure.ps1
Invoke-Pester ./10_Scripts/Tests/NexusUpdateMenuSafety.Tests.ps1
Invoke-Pester ./10_Scripts/Tests/CatalogMetadata.Tests.ps1
Invoke-Pester ./10_Scripts/Tests/NexusUpdateMenuInteraction.Tests.ps1
Invoke-Pester ./10_Scripts/Tests
```

Expected counts, assuming no additional tests are added first:

- safety suite: 12 passed, 0 failed;
- catalog metadata suite: 8 passed, 0 failed;
- option-4 interaction suite: 2 passed, 0 failed;
- complete suite: 136 passed, 0 failed.

Then verify:

```powershell
git status --short --branch
git check-ignore -v .cache/NexusMetadata.json
```

Expected generated tracked changes:

- `00_Documentation/RepositoryStructure.txt`
- `00_Documentation/RepositoryInventory.json`

The cache JSON itself must remain ignored and untracked.

## Interactive Acceptance

1. Menu 1 `R` opens Remote Metadata without an indexing exception.
2. Menu 1 shows the timestamp/count and inner `R` refreshes/redraws.
3. Menu 4 shows the same timestamp/count plus visible `R` and `B`.
4. Menu 4 `B` returns to the main menu.
5. Manual mode displays the resolved `01_Archives` path and opens Nexus.
6. Menu 4 `R` rescans local archives and refreshes remote metadata.
7. Cancelling direct-download confirmation leaves files unchanged.
8. `.cache\NexusMetadata.json` exists after first use and remains ignored.

A real Nexus Premium download remains optional and must use the repository
owner's own account and API key.
