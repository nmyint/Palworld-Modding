# Palworld Modding Workshop

This repository is the authoritative development workspace for a personal
Palworld installation. It keeps development, testing, deployment, and archival
work separate from the live game installation.

## Goals

- Maintain a stable modded installation.
- Develop and test compatibility patches.
- Archive every mod update.
- Document reproducible issues and solutions.
- Automate repetitive maintenance safely.
- Keep experiments isolated from deployment-ready work.

## Workflow

```text
Workshop -> Test -> Deploy -> Commit
```

See [FolderStructure.md](00_Documentation/FolderStructure.md) for the role of each
workshop directory.

## PowerShell module

Workshop automation is provided by the `PalworldModding` module:

```powershell
Import-Module ./10_Scripts/Modules/PalworldModding.psd1 -Force
Initialize-PwWorkshop
Get-PwWorkshopInfo
```

PowerShell conventions are documented in
[PowerShellStandards.md](00_Documentation/PowerShellStandards.md).

## Profiles

Installation and deployment settings are stored in JSON profiles under
`16_Profiles`. See [Profiles.md](00_Documentation/Profiles.md) for the schema,
commands, and readiness rules.

## Tests

Run the automated checks from the repository root:

```powershell
pwsh -NoProfile -Command "Invoke-Pester -Path './10_Scripts/Tests' -EnableExit"
```

In VS Code, run the default test task: `PwTools: Test`.
