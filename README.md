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

See [RepositoryStructureTool.md](00_Documentation/RepositoryStructureTool.md) for documentation about the exporter that creates these generated repository maps.

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

**Pw-Git v1.2 is complete.** Pw-Git is the repository-safe Git workflow interface used by the workshop and remains separate from PwWorkshop.

The responsive main menu provides repository health, status, fetch, compare, pull, selected-file pull, staging, commit, and committed-change push workflows. `H` opens the Advanced menu for unstage, discard, stash, stash restore, repository history, branch information, and manual repository-structure refresh.

Safety and usability features include:

- dynamic terminal redraw and resize handling
- review-first repository operations
- file selection before supported destructive operations
- explicit confirmation before commits and destructive changes
- direct staged-change review through `review-staged`
- synchronized direct-command validation in both launchers
- manual repository-map refresh through `refresh-structure`
- repository-map refresh leaves Git staging unchanged
- transactional generated-output replacement if export fails
- `Enter` or `B` returns to the previous menu where supported
- `Q` exits Pw-Git
- Ctrl-C safely interrupts the current operation

Run Pw-Git from the repository root:

```powershell
pwsh -NoProfile -File ./pw-git.ps1
```

Refresh the generated repository map manually:

```powershell
pwsh -NoProfile -File ./pw-git.ps1 refresh-structure
```

Pw-Git v1.2 was validated under PowerShell 7.6.4 with the focused exporter and Pw-Git test suites passing, generated changes reported correctly, staging preserved, and the regenerated repository maps published to `main`.

See [Pw-Git.md](00_Documentation/Pw-Git.md) for the completed v1.2 release record, menu map, direct commands, and safety model.

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
