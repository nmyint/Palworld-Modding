# Mod Catalog and Workshop Menu

Sprint 4 begins with a read-only catalog of the downloads in `01_Archives` and
the loose mod snapshot in `02_Staging`. It does not extract, move, rename,
deploy, enable, disable, or delete mod files.

## Start the menu

From the repository root:

```powershell
pwsh -NoProfile -File ./PwWorkshop.ps1
```

The `PwTools: Workshop Menu` VS Code task starts the same interface. The first
menu contains only safe reporting actions:

- catalog and version matches;
- parsed Nexus archive metadata;
- loose staging inventory and enablement state;
- diagnostics, known-good installation inventory, and deployment history.

The menu measures the active terminal while it is waiting for input. It redraws
after a window resize, adjusts between compact and full-height layouts, and
truncates long labels inside the frame instead of allowing them to wrap.
Selections `1` through `7` and `Q` respond immediately without requiring Enter.
At result screens and nested Nexus update prompts, entering `Q` exits the entire
workshop instead of returning to the main menu.

The menu will become the primary workshop interface as later Sprint 4 actions
are reviewed. Existing PowerShell commands remain available for automation and
troubleshooting.

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
top-level staging only when the normalized tree does not exist.
It records:

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

The workshop menu exposes the same flow under **Catalog and versions**: press
`S` to preview and `A` to apply. Removed or externally backed-up archives are
not erased from history; their version records remain with
`ArchivePresent = false`. Loose mods without a matching archive are marked
`NeedsMetadata` for later reconciliation.

Later synchronization preserves reviewed source, Nexus identity, installed
version, and reconciliation status. Each installed record also carries an
`InstalledVariant` with platform, play mode, and package type. Archive-version
records carry the same dimensions so Steam/GamePass,
singleplayer/dedicated/multiplayer, and UE4SS/PAK releases can coexist.

`Get-PwStagingReconciliation` also reports when one installed mod owns multiple
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

## Current limitations

The catalog does not guess an authoritative installed version when loose files
contain no version metadata. Such records remain marked for reconciliation.
Deterministic path-level conflict detection still depends on assembling curated
library packages. Profile mod sets and preliminary compatibility reporting are
available, while full assembly remains Sprint 4.4 work.
Palworld itself does not appear to expose a general user-facing load-order
system, so Sprint 4.3 focuses on practical compatibility rules, file conflicts,
and dependency hints instead of a classic ordered-load manager.

Authenticated update checks and manual or Premium direct downloads are
documented in [NexusUpdates.md](NexusUpdates.md).
