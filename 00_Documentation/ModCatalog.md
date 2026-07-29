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

The menu will become the primary workshop interface as later Sprint 4 actions
are reviewed. Existing PowerShell commands remain available for automation and
troubleshooting.

## Catalog discovery

`Get-PwNexusArchiveMetadata` parses the current Nexus download filename format
from right to left:

```text
<Name> <NexusModId> <Version> <UTC download time> <token>.zip
```

The original filename, SHA-256 hash, Nexus mod ID and URL, archive version, and
download time are retained in memory. Archive inspection also discovers common
UE4SS installation folder names. This is offline metadata discovery; it does
not call Nexus Mods or require an API key.

`Get-PwStagedModSnapshot` inventories top-level folders under `02_Staging`.
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

## Current limitations

The catalog does not yet choose an authoritative installed version when the
loose files contain no version metadata. It reports candidates rather than
guessing. Persistent normalized manifests, conflict detection, dependencies,
mod sets, and menu-driven changes are later Sprint 4 work.

Authenticated update checks and manual or Premium direct downloads are
documented in [NexusUpdates.md](NexusUpdates.md).
