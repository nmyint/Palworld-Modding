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

## Download an update

Manual download works for any normal Nexus account:

```powershell
Open-PwNexusModPage -ModId 3968 -Launch
```

Choose the desired file in the browser and save it into `01_Archives`. The next
catalog scan will discover it.

Nexus normally restricts direct API download links to Premium accounts. For a
Premium account, the menu can download the selected remote file directly, or:

```powershell
Save-PwNexusModUpdate -ModId 3968 -FileId 123456
```

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
