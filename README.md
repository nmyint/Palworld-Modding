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
Archive -> Stage -> Develop -> Test -> Deploy -> Commit
```

See [FolderStructure.md](00_Documentation/FolderStructure.md) for the role of each
workshop directory.

The completed milestones and forward plan are tracked in
[Roadmap.md](00_Documentation/Roadmap.md).

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

## Deployment

Deployment is preview-first and backs up overwritten files before applying changes.
See [Deployment.md](00_Documentation/Deployment.md) for the safety model and
commands.

## Mod intake

Downloaded ZIP archives can be inspected, staged, validated, and promoted without
touching the live game. See [ModIntake.md](00_Documentation/ModIntake.md).

## Tests

Run the automated checks from the repository root:

```powershell
pwsh -NoProfile -File ./10_Scripts/Tasks/Test-Workshop.ps1
```

In VS Code, run the default test task: `PwTools: Test`.

## Scope

This is a personal learning and backup workspace. Machine-specific integration
checks and the `Stable` profile are intentional. See
[Environment.md](00_Documentation/Environment.md) before moving the workshop to
another computer.
