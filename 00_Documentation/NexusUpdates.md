# Nexus Mod Update Checks

Sprint 4.1 can check Nexus Mods for newer files associated with the Nexus IDs
parsed from surviving downloads in `01_Archives`.

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

Restart Codex, VS Code, or the terminal after setting a persistent variable.
The value is stored in the Windows user environment, not in this repository.

Validate the connection:

```powershell
Import-Module ./10_Scripts/Modules/PalworldModding.psd1 -Force
Get-PwNexusApiIdentity
```

Do not paste the API key into a chat, command argument, script, profile, or
configuration file.

## Check for updates

Use menu option **Check Nexus for updates**, run the VS Code task
`PwTools: Check Mod Updates`, or call:

```powershell
Get-PwModUpdateReport
```

The check queries only unique, parsed Nexus IDs. It compares the newest remote
main file with the latest surviving local download. Results are:

- `Current`;
- `UpdateAvailable`;
- `NoRemoteFiles`;
- `CheckFailed`.

Mods whose original archives were deleted do not yet have a durable Nexus ID,
so they cannot be checked automatically until Sprint 4.2 metadata reconciliation
records those IDs.

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

Traditional direct links may expire. Nexus also offers browser-based resumable
downloads for eligible large files, so manual browser download remains the
preferred fallback. See [Nexus resumable downloads][resumable].

[resumable]: https://help.nexusmods.com/article/170-resumable-downloads
# Variant-aware update checks

The update checker treats filename/version markers as separate release
branches. `SP`/Singleplayer, `DS`/Dedicated Server, and `MP`/Multiplayer-host
files are compared only within the same branch. If the installed branch cannot
be found remotely, the report returns `VariantNotFound` instead of suggesting a
different build.

For example, AntiPhat `SP-2.0.5` is never compared with `DS-2.0.17`.
