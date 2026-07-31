## Repository Entry Point (AI / Developer Workflow)

When opening this repository, begin with:

1. Read `README.md`
2. Read `00_Documentation/RepositoryStructure.txt`
3. Read `00_Documentation/RepositoryInventory.json`
4. Read `00_Documentation/AIRepositoryWorkflow.md`
5. Review relevant operational documentation in `00_Documentation`
6. Review `00_Documentation/Scrapbook.md` for historical context

The generated repository structure files provide the authoritative map of:

- folder responsibilities
- script organization
- documentation locations
- project boundaries
- deployment and testing areas

Large files should not be loaded blindly. Review large documents, logs, generated files, and archives incrementally using logical sections or chunks.

Prioritize:

- documentation
- configuration
- scripts
- tests

Avoid scanning:

- archives
- deployment payloads
- generated output
- game binaries

unless the task specifically requires them.

===== READ EVERY SINGLE DOCUMENT IN 00_Documentation/* =====

# Palworld Modding Workshop

This repository is the authoritative development workspace for a personal Palworld installation. It keeps development, testing, deployment, and archival work separate from the live game installation.

## Requirements

Workshop automation is developed and tested for **PowerShell 7.6.4** (`pwsh`). Windows PowerShell 5.1 is not a supported runtime for the workshop scripts. Git must also be available on `PATH`.

## Pw-Git

`Pw-Git` is the repository-safe Git workflow interface used by the workshop. It is designed to keep Git operations review-first and avoid accidental changes.

Features:

- dynamic terminal redraw and resize handling
- guided push and pull workflows
- file selection before destructive operations
- explicit commit confirmation
- `Enter` or `B` returns to the previous menu where supported
- `Q` exits Pw-Git
- Ctrl-C safely interrupts the current operation

Run Pw-Git from the repository root:

```powershell
pwsh -NoProfile -File ./pw-git.ps1
```

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

See [FolderStructure.md](00_Documentation/FolderStructure.md) for the role of each workshop directory.

The completed milestones and forward plan are tracked in [Roadmap.md](00_Documentation/Roadmap.md).

## PowerShell module

Workshop automation is provided by the `PalworldModding` module:

```powershell
Import-Module ./10_Scripts/Modules/PalworldModding.psd1 -Force
Initialize-PwWorkshop
Get-PwWorkshopInfo
```

PowerShell conventions and runtime requirements are documented in [PowerShellStandards.md](00_Documentation/PowerShellStandards.md).

## One-command menu

Start the menu-driven workshop from the repository root:

```powershell
pwsh -NoProfile -File ./PwWorkshop.ps1
```

The Sprint 4 menu provides catalog, archive, staging, component-ownership, compatibility, profile-set, diagnostic, inventory, history, and Nexus update workflows. The interface redraws automatically when its terminal window is resized.

## Tests

Run the automated checks from the repository root with PowerShell 7.6.4:

```powershell
pwsh -NoProfile -File ./10_Scripts/Tasks/Test-Workshop.ps1
```

In VS Code, run the default test task: `PwTools: Test`.

## Scope

This is a personal learning and backup workspace. Machine-specific integration checks and the `Stable` profile are intentional.

===== READ EVERY SINGLE DOCUMENT IN 00_Documentation/* =====
