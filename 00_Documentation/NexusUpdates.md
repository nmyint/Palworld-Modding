# Nexus Mod Update Checks

The workshop can check Nexus Mods for newer files associated with reviewed Nexus
IDs stored in the persistent catalog and discovered from surviving downloads in
`01_Archives`.

## Safety and account model

The workshop uses the supported Nexus Mods API. It does not scrape web pages,
bypass download timers, or store an API key in Git.

A personal API key is appropriate for this private, personal-use workshop under
the [Nexus Mods API acceptable-use policy][api-policy]. Generate the key from
the **API Access** section of your Nexus account settings.

[api-policy]: https://help.nexusmods.com/article/114-api-acceptable-use-policy

Set it for the current PowerShell session without displaying it:

```powershell
$env:NEXUSMODS_API_KEY = Read-Host 'Nexus API key' -MaskInput
```

To keep it in the Windows user environment:

```powershell
$key = Read-Host 'Nexus API key' -MaskInput
[Environment]::SetEnvironmentVariable('NEXUSMODS_API_KEY', $key, 'User')
Remove-Variable key
```

Restart VS Code or the terminal after setting a persistent variable. The value
is stored in the Windows user environment, not in this repository.

Validate the connection:

```powershell
Import-Module ./10_Scripts/Modules/PalworldModding.psd1 -Force
Get-PwNexusApiIdentity
```

Do not paste the API key into a chat, command argument, script, profile, or
configuration file.

## Check for updates

Use menu option **Check mod and tool updates**, run the VS Code task
`PwTools: Check Mod Updates`, or call:

```powershell
Get-PwModUpdateReport
```

The check queries unique reviewed Nexus IDs. It compares the newest compatible
remote main file with the recorded installed or surviving local version.
Results include:

- `Current`;
- `UpdateAvailable`;
- `VariantNotFound`;
- `NoRemoteFiles`;
- `CheckFailed`.

A mod without a reviewed Nexus ID remains visible in the catalog but cannot be
checked automatically. Add or correct its identity through **Catalog → Edit
identity** after verifying the Nexus page.

## Universal Nexus metadata cache

The workshop keeps one persistent catalog-wide Nexus metadata snapshot at:

```text
.cache\NexusMetadata.json
```

The `.cache` directory is local generated state and is ignored by Git.

For every reviewed Nexus mod ID known through the persistent catalog, surviving
archives, or configured Nexus sources, the snapshot stores the complete raw JSON
returned by both canonical metadata endpoints used by the workshop:

- the mod metadata response;
- the complete mod file-list response, including every field Nexus returns in
  that response.

The snapshot therefore retains information that current menu modules do not yet
display. Update reporting, catalog metadata, identity review, current-game
adoption, profile archive planning, configured Nexus source checks, and exact
file selection all parse the fields they need from the same cached responses.
The existing commands continue to call `Invoke-PwNexusApi`; the shared API layer
routes supported mod and file reads to the snapshot.

The complete file-list response already contains the full metadata object for
each listed file, including descriptions, changelog HTML, sizes, content-preview
links, upload times, virus-scan links, primary-file status, and update-chain
records. The workshop therefore does not make a separate exact-file request for
every cached file.

This is intentionally not a crawl of every endpoint exposed by Nexus Mods. It
does not separately request or persist:

- API keys or other credentials;
- API validation responses, tracked-mod lists, endorsement lists, or other
  account endpoints;
- transient direct-download links;
- downloaded archive bytes;
- unrelated games, mods, collections, comments, or discovery feeds.

The mod metadata response is retained verbatim. Consequently, any optional
account-relative field Nexus includes inside that response, such as an inline
endorsement state, is preserved as part of the raw response; the workshop does
not make a separate account-data request to obtain it.

Direct-download links and API account validation are always requested live.
The selected mod is also refreshed immediately before an approved direct
Premium download so stale file IDs cannot be used.

### Cache lifetime and refresh

The Nexus snapshot has no automatic ten-minute expiration. It remains the
working remote metadata source until one of these events occurs:

- the cache does not exist, in which case the first Nexus-backed menu action
  builds the full snapshot;
- a new reviewed Nexus ID appears in the catalog, archives, or configured
  sources, in which case only the missing ID is added;
- the user explicitly presses `R` in menu 1 Remote Metadata or menu 4 Updates;
- a guarded direct download refreshes its selected Nexus mod before mutation.

Menu 1 and menu 4 show the snapshot timestamp and ready-versus-catalog mod count
in the screen title. `R` performs a complete catalog refresh. A successful prior
entry is retained if a later refresh fails, and the refresh error is recorded so
the cached data remains usable but visibly stale.

Local state is never substituted by this cache. `01_Archives`, the persistent
catalog, profiles, and update-source configuration are still reread normally, so
local changes remain visible immediately.

### Atomic cache writes and preview safety

`NexusMetadataCacheTransaction.ps1` treats the complete cache replacement as one
`ShouldProcess` transaction. During `-WhatIf`, it returns before creating the
cache directory, writing a temporary JSON file, or replacing the final cache.

During an approved write, the workshop:

1. creates the cache directory;
2. serializes the complete snapshot to a uniquely named temporary file;
3. verifies that the temporary file exists;
4. replaces `.cache\NexusMetadata.json`; and
5. removes any surviving temporary file in `finally`.

This prevents preview-only update checks from attempting to move a temporary
cache file that was intentionally not created.

## Lazy Nexus content inventories

The workshop can retain archive-content information without storing downloaded
archive bytes. Per-file inventories are stored inside the same
`.cache\NexusMetadata.json` snapshot.

Content previews are retrieved lazily, only when a Nexus file becomes
operationally relevant:

- a current or `UpdateAvailable` file selected by the update report;
- an existing API-downloaded archive carrying an `Api<FileId>` filename token;
- a successful guarded direct download; or
- an explicit inventory request from another module.

The workshop does not fetch every preview for every historical, archived,
optional, or deleted Nexus file during a normal metadata refresh.

Each cached inventory can retain:

- the raw Nexus content-preview JSON;
- normalized archive-relative paths;
- a fingerprint of the complete Nexus file metadata;
- detected package types;
- candidate deployment roots;
- file count and mixed-package status;
- retrieval source, authority, status, timestamp, and errors;
- local archive path and hash when the file has been inspected locally.

Detected package types include:

- `UE4SSLua`;
- `Pak`;
- `LogicMods`;
- `Native`;
- `Configuration`;
- `Documentation`;
- `SupportOrUnknown`.

Remote content previews are advisory. A changed Nexus file-metadata fingerprint
invalidates the advisory inventory. A locally inspected ZIP or 7z archive is
authoritative and replaces the advisory classification for that Nexus file.

The practical authority order is:

1. locally inspected ZIP or 7z archive;
2. cached Nexus content-preview inventory;
3. Nexus file metadata hints;
4. Nexus mod description hints.

Content-preview failure does not change the update status and does not bypass or
weaken guarded download checks. The failure is retained as enrichment metadata
for later review.

Update rows may expose:

- `RemoteContentInventoryStatus`;
- `RemoteContentInventorySource`;
- `RemotePackageTypes`;
- `RemoteDetectedRoots`;
- `RemoteContentFileCount`;
- `RemoteIsMixedPackage`;
- `RemoteContentInventoryError`.

## Download an update

Manual download works for any normal Nexus account:

```powershell
Open-PwNexusModPage -ModId 3968 -Launch
```

The command displays the resolved archive directory before opening the browser.
You can also display it directly:

```powershell
(Get-PwPaths).Archives
```

Save the completed ZIP or 7z file directly into that `01_Archives` directory.
The workshop does not monitor browser download completion and does not scan the
normal Windows Downloads directory. Wait until the browser has finished and no
partial-download extension remains, then return to menu option 4 and press `R`.
The update report rescans `01_Archives`; a supported Nexus filename is then
included as local archive metadata. Use menu option 2 to inspect and import it.

Nexus normally restricts direct API download links to Premium accounts. The
low-level downloader accepts an explicit Nexus mod ID and file ID:

```powershell
Save-PwNexusModUpdate -ModId 3968 -FileId 123456
```

For update-check workflows, use the guarded report handoff instead of manually
copying IDs:

```powershell
$update = Get-PwModUpdateReport |
    Where-Object Status -eq 'UpdateAvailable' |
    Select-Object -First 1

Save-PwModUpdateFromReport -Update $update
```

`Save-PwModUpdateFromReport` requires one exact `UpdateAvailable` row from the
report. It refuses `Current`, `VariantNotFound`, `NoRemoteFiles`, `CheckFailed`,
and rows without valid Nexus mod and remote file IDs. It supports `-WhatIf`,
uses high-impact confirmation, and passes the exact selected remote file ID to
the existing downloader.

Menu option 4 refreshes and matches the selected report row before a direct
download. It displays the selected mod, local and remote versions, variant,
remote filename, file ID, and status; refuses stale or non-actionable rows; and
requires deliberate confirmation before calling the guarded report command.
The result reports the downloaded archive path and SHA-256 hash and identifies
the next workflow step: inspect and import the archive through menu option 2.
Manual browser download remains available as the normal-account fallback.

The workshop uses the user-local `wget.exe` installation at
`%LOCALAPPDATA%\Programs\Wget`, otherwise `curl.exe`, and finally PowerShell web
download as a fallback. A direct download is written to a temporary file,
inspected using the existing archive safety checks, and moved into
`01_Archives` only after validation succeeds.

## Download a profile's missing archives

When you want to restore the current curated set for a profile, use the
profile-aware download plan. It reads the active mod set for the named profile,
looks up each mod in the persistent catalog, and downloads only the items that
still need an archive:

```powershell
Get-PwProfileModDownloadPlan -ProfileName Stable
Save-PwProfileModDownloads -ProfileName Stable -Confirm:$false
```

The helper keeps `02_Staging` aligned with the working setup while
reconstructing missing files in `01_Archives`. It does not overwrite existing
archives unless you explicitly choose to do so later.

Traditional direct links may expire. Nexus also offers browser-based resumable
downloads for eligible large files, so manual browser download remains the
preferred fallback. See [Nexus resumable downloads][resumable].

[resumable]: https://help.nexusmods.com/article/170-resumable-downloads

## Variant-aware update checks

The update checker treats filename/version markers as separate release
branches. `SP`/Singleplayer, `DS`/Dedicated Server, and `MP`/Multiplayer-host
files are compared only within the same branch. If the installed branch cannot
be found remotely, the report returns `VariantNotFound` instead of suggesting a
different build.

For example, AntiPhat `SP-2.0.5` is never compared with `DS-2.0.17`.
When both versions are present, an identical version is current even if the
remote upload timestamp contains seconds that were rounded out of the local
archive filename. Upload time is used only when version metadata is missing.
