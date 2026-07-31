===== READ EVERY SINGLE DOCUMENT IN 00_Documentation/* =====

# Palworld Modding Workshop

This repository is the authoritative development workspace for a personal
Palworld installation. It keeps development, testing, deployment, and archival
work separate from the live game installation.

## Requirements

Workshop automation is developed and tested for **PowerShell 7.6.4** (`pwsh`).
Windows PowerShell 5.1 is not a supported runtime for the workshop scripts.
Git must also be available on `PATH`.

Verify the active runtime before using the workshop tooling:

```powershell
$PSVersionTable.PSVersion
```

The expected result is `7.6.4`. The authoritative configured requirement is
stored in `.config/Workshop.json` under `Tools.PowerShell.RequiredVersion`.

## Goals

- Maintain a stable modded installation.
- Develop and test compatibility patches.
- Archive every mod update.
- Document reproducible issues and solutions.
- Automate repetitive maintenance safely.
- Keep experiments isolated from deployment-ready work.

## Workflow

```text
Archive -> Stage -> Library -> Deploy -> Validate -> Inventory
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

PowerShell conventions and runtime requirements are documented in
[PowerShellStandards.md](00_Documentation/PowerShellStandards.md).

## One-command menu

Start the menu-driven workshop from the repository root:

```powershell
pwsh -NoProfile -File ./PwWorkshop.ps1
```

The Sprint 4 menu provides catalog, archive, staging, component-ownership,
compatibility, profile-set, diagnostic, inventory, history, and Nexus update
workflows. The interface redraws automatically when its terminal window is
resized. See
[ModCatalog.md](00_Documentation/ModCatalog.md).

Cataloged Nexus mods can be checked for updates through the supported API.
Manual browser downloads work for normal accounts; validated direct downloads
are available when Nexus permits them. See
[NexusUpdates.md](00_Documentation/NexusUpdates.md).

Optional tools and dependencies can also use explicit Nexus or GitHub release
providers without silently changing sources. See
[UpdateSources.md](00_Documentation/UpdateSources.md).

Missing-archive entries can be enriched through their reviewed Nexus IDs, with
GitHub sources discovered from page descriptions. See
[CatalogMetadata.md](00_Documentation/CatalogMetadata.md).

## Profiles

Installation and deployment settings are stored in JSON profiles under
`16_Profiles`. See [Profiles.md](00_Documentation/Profiles.md) for the schema,
commands, and readiness rules.

## Deployment

Deployment is preview-first and backs up overwritten files before applying changes.
See [Deployment.md](00_Documentation/Deployment.md) for the safety model and
commands.

Menu option `7` captures the reconciled active mod set into curated library
manifests, builds and SHA-256 verifies `05_Deployment`, and compares it with the
current game before deployment is permitted. Nexus identity and local integrity
boundaries are described in
[NexusHashVerification.md](00_Documentation/NexusHashVerification.md).

The complete repeatable operator checklist is in
[DailyWorkflow.md](00_Documentation/DailyWorkflow.md). The sequential main menu
uses `1–7` for catalog-to-deployment work, `8–0` for health/history, and `Q` to
quit.

## Mod intake

Downloaded ZIP and 7z archives can be inspected, staged, validated, and promoted
without touching the live game. See
[ModIntake.md](00_Documentation/ModIntake.md).

## Recovery and diagnostics

Deployment backups can be validated and restored through an explicit,
preview-first workflow. See [Recovery.md](00_Documentation/Recovery.md) for
restoration, known-good inventory, history, and diagnostics.

## Git and external backups

Git tracks source and lightweight metadata rather than large workshop binaries.
Maximum-compression 7z backups preserve durable workshop data on external
storage. See
[WorkshopBackup.md](00_Documentation/WorkshopBackup.md).

## Tests

Run the automated checks from the repository root with PowerShell 7.6.4:

```powershell
pwsh -NoProfile -File ./10_Scripts/Tasks/Test-Workshop.ps1
```

In VS Code, run the default test task: `PwTools: Test`.

## Scope

This is a personal learning and backup workspace. Machine-specific integration
checks and the `Stable` profile are intentional. See
[Environment.md](00_Documentation/Environment.md) before moving the workshop to
another computer.

===== READ EVERY SINGLE DOCUMENT IN 00_Documentation/* =====
