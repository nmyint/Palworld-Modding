# Mod Catalog and Workshop Menu

The workshop catalog is the persistent metadata and ownership layer for curated
mods. It connects original downloads in `01_Archives`, the reviewed working tree
in `02_Staging`, versioned packages in `03_Mod_Library`, profile selections, and
deterministic output in `05_Deployment`.

The catalog began as a read-only Sprint 4.1 discovery view. Sprint 4 subsequently
added reviewed metadata writes, component ownership, profile mod sets,
compatibility reporting, deterministic assembly, and preview-only upgrade and
removal planning. Sprint 4 is complete; later automation builds on these
existing capabilities rather than redefining the milestone.

## Start the menu

From the repository root:

```powershell
pwsh -NoProfile -File ./PwWorkshop.ps1
```

The `PwTools: Workshop Menu` VS Code task starts the same interface. The current
main menu provides:

- catalog, version, remote-metadata, and ownership workflows;
- archive inspection and normalized staging import;
- staging inventory and component reconciliation;
- Nexus and source update checks;
- compatibility and conflict reporting;
- profile mod-set creation and preview;
- staged builds, isolated experiments, deterministic assembly, verification,
  live-game comparison, and explicitly approved deployment;
- diagnostics, installation inventory, deployment history, and restore history.

The menu measures the active terminal while it is waiting for input. It redraws
after a window resize, adjusts between compact and full-height layouts, and
truncates long labels inside the frame instead of allowing them to wrap. The
current navigation and action keys are documented in
[MenuFlow.md](MenuFlow.md).

Existing PowerShell commands remain available for automation, testing, and
troubleshooting. The menu is a guided interface over those commands rather than
a separate implementation.

## Catalog discovery

`Get-PwNexusArchiveMetadata` parses the current Nexus download filename format
from right to left:

```text
<Name> <NexusModId> <Version> <UTC download time> <token>.zip
```

It also recognizes the older hyphenated Nexus format:

```text
<Name>-<NexusModId>-<hyphenated version>-<Unix upload time>.7z
```

For example, `RotateIt_beta-684-1-17-1-1738046580.7z` becomes mod name
`RotateIt_beta`, Nexus ID `684`, version `1.17.1`, and upload timestamp
`2025-01-28 06:43 UTC`. Because hyphenated names ending in numeric components
can be inherently ambiguous, unfamiliar patterns remain flagged for manual
metadata rather than being guessed.

The original filename, SHA-256 hash, Nexus mod ID and URL, archive version, and
download time are retained in memory. Archive inspection also discovers common
UE4SS installation folder names. This is offline metadata discovery; it does
not call Nexus Mods or require an API key.

`Get-PwStagedModSnapshot` inventories the normalized
`02_Staging\Pal\Binaries\Win64\ue4ss\Mods` tree. It falls back to legacy
top-level staging only when the normalized tree does not exist. It records:

- marker and legacy `mods.txt` enablement state;
- UE4SS, native, PAK, and support-file classifications;
- file count, size, and a deterministic content hash.

`Get-PwModCatalog` joins both views. A staged mod may be:

- `Matched` to one surviving archive;
- `MultipleVersions` when several candidate downloads match;
- `MissingArchive` when the original download no longer exists.

Archive-only items, duplicate hashes, and malformed `mods.json` are reported as
warnings. Matching by an internal UE4SS folder name is important because the
Nexus page name and the folder accepted by UE4SS may differ.

## Persistent catalog and version history

Sprint 4.2 stores portable metadata in `03_Mod_Library/catalog.json`. It records
catalog identity, install names, Nexus IDs, installed content hashes, and
archive versions with their SHA-256 hashes and provenance. It contains no
absolute workshop or game paths.

Preview changes without writing:

```powershell
Get-PwModCatalogSyncPlan
```

Apply the reviewed plan:

```powershell
Update-PwModCatalog
```

The workshop menu exposes the same flow under **Catalog**. Removed or externally
backed-up archives are not erased from history; their version records remain
with `ArchivePresent = false`. Loose mods without a matching archive are marked
`NeedsMetadata` for later reconciliation.

Later synchronization preserves reviewed source, Nexus identity, installed
version, and reconciliation status. Each installed record also carries an
`InstalledVariant` with platform, play mode, and package type. Archive-version
records carry the same dimensions so Steam/GamePass,
singleplayer/dedicated/multiplayer, and UE4SS/PAK releases can coexist.

`Get-PwStagingReconciliation` reports when one installed mod owns multiple
deployment components. For example, a single catalog identity may contain a
UE4SS Lua folder plus files under `Pal\Content\Paks\~mods` or
`Pal\Content\Paks\LogicMods`. Configuration files remain attached to their
component but do not create a separate package type.

Component ownership aliases are stored separately from archive/install names.
This allows a mixed mod such as `PalMiniMap` to own the UE4SS folder
`PalMiniMap`, `PalMiniMap.pak`, and `Paldar.modconfig.json` without treating
`Paldar` as a separate Nexus identity. PAK-only mods can receive a reviewed,
metadata-only catalog record from the ownership menu.

The same operations are available non-interactively:

```powershell
Set-PwModCatalogMetadata `
    -CatalogKey 'palminimap' `
    -ComponentName 'Paldar'

New-PwModCatalogRecord `
    -DisplayName 'Example PAK Mod' `
    -ComponentName 'ExampleMod_P'
```

Explicit component ownership takes precedence over filename-derived identity.
This allows bundled folders such as `shared` to remain owned by their parent
package without creating a duplicate deployment selection.

After confirming missing information from Nexus or the installed mod, record it
without changing any mod files:

```powershell
Set-PwModCatalogMetadata `
    -CatalogKey 'orphanmod' `
    -DisplayName 'Orphan Mod' `
    -NexusModId 1234 `
    -InstalledVersion '1.0.0'
```

Bundled UE4SS support components can be classified without inventing a Nexus
identity:

```powershell
Set-PwModCatalogMetadata `
    -CatalogKey 'bpmodloadermod' `
    -Source UE4SSBundled
```

## Compatibility and conflict reporting

`Get-PwCompatibilityReport` combines catalog, staging, profile, archive, and
variant information into a read-only report. It identifies duplicate archives,
mixed reviewed packages, practical dependency hints, missing dependencies, and
platform or play-mode variant warnings.

`Get-PwProfileAssemblyPlan` performs the authoritative deterministic assembly
checks. It identifies conflicting curated package directories and path-level
collisions where more than one selected catalog package targets the same
normalized deployment path. A profile build is blocked while unresolved
ownership, missing profile selections, package conflicts, or destination-path
conflicts remain.

Palworld does not expose a general user-facing load-order system. The workshop
therefore reports practical compatibility evidence and dependency hints instead
of inventing a classic ordered-load manager.

Persistent user-authored incompatibility policies, reviewed decision overrides,
and expanded compatibility-rule automation are future enhancements. They are
not unfinished Sprint 4 requirements.

## Profile sets and deterministic assembly

Profile mod sets select reviewed catalog identities without modifying the live
game. `Get-PwProfileAssemblyPlan` previews the selected packages and conflicts.
`Build-PwProfileDeployment` captures reviewed staging content into versioned,
manifest-backed library packages and assembles verified loose files beneath
`05_Deployment`.

Assembly uses deterministic relative paths and SHA-256 verification. It writes
an assembly manifest and remains separate from live deployment. The game is
changed only through the explicit deployment workflow after assembly
verification and live-game comparison.

## Upgrade and removal planning

Sprint 4.5 delivered preview-only planning:

```powershell
Get-PwModUpgradePlan
Get-PwModRemovalPlan
```

Upgrade plans compare current and candidate manifests by normalized deployment
path and SHA-256, classifying files as `Create`, `Update`, `Remove`, or
`Unchanged`.

Removal plans distinguish `Owned`, `Modified`, `Shared`, and `Missing` files so
shared ownership and locally changed output remain visible. Plans report backup
requirements and retain the package manifests needed for a later rollback-aware
workflow.

These commands do not copy, overwrite, or remove files. Transactional plan
application, stale-plan protection, and automatic rollback require a separately
approved future scope.

## Current limitations

The catalog does not guess an authoritative installed version when loose files
contain no version metadata. Such records remain marked for reconciliation.

Compatibility reporting reflects evidence available in catalog, staging,
profile, and package manifests. It does not claim that every third-party mod
combination is known or tested.

Upgrade and removal operations remain preview-only. Live deployment also
continues to prohibit automatic deletion of current-game-only files.

Authenticated update checks and manual or Premium direct downloads are
documented in [NexusUpdates.md](NexusUpdates.md).
