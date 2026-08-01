## New Chat Session Startup

Use one repository-root entry file when starting a new AI chat:

- `NewSession.md` — start a new project, sprint, feature, maintenance task,
  investigation, or implementation scope.
- `ContinueSession.md` — resume from the active session handoff.

Minimal prompts:

```text
Use the GitHub connector for nmyint/Palworld-Modding.
Read NewSession.md completely and follow it.

Proposed work: <describe the new work here>
```

```text
Use the GitHub connector for nmyint/Palworld-Modding.
Read ContinueSession.md completely and follow it.
```

The selected entry file invokes the shared policy in
`00_Documentation/SessionStartup.md`. The assistant must complete all required
reading and verification silently in the same assistant turn. It must not send
acknowledgements, progress updates, apologies, plans, promises, partial summaries,
or lists of remaining reading. The first visible natural-language response must
be either the completed verified startup result or one concise genuine
hard-blocker report.

## Repository Entry Point (AI / Developer Workflow)

When opening this repository, begin with:

1. Read the selected repository-root entry file: `NewSession.md` or
   `ContinueSession.md`.
2. Read `README.md` completely.
3. Read `00_Documentation/SessionStartup.md` and follow the shared startup policy.
4. Read `00_Documentation/RepositoryStructure.txt` and strictly abide by it.
5. Read `00_Documentation/RepositoryInventory.json` and strictly abide by it.
6. Read `00_Documentation/AIRepositoryWorkflow.md` and strictly abide by it.
7. Read `00_Documentation/AIRepositoryWorkflow_v2_Design.md` as a design reference for the merged workflow guardrails.
8. Review relevant operational documentation in `00_Documentation`.
9. Review `00_Documentation/Scrapbook.md` for historical context.

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

## Session Handoffs

The current AI/development continuation record is stored in:

`00_Documentation/Session-Handoffs/`

Use `ContinueSession.md` when resuming previous work. Use `NewSession.md` for a
new scope instead of assuming that an older handoff defines it.

- `Scrapbook.md` contains the canonical working agreement, project history, and
  research context.
- `Session-Handoffs/` contains the current continuation state for resumed work.
- Git history and merged pull requests preserve superseded historical records.

## AI Workflow Design Documents

The active AI workflow is maintained in:

- `00_Documentation/AIRepositoryWorkflow.md`

The repository-root session entry files are:

- `NewSession.md`
- `ContinueSession.md`

The shared startup policy is maintained in:

- `00_Documentation/SessionStartup.md`

The workflow guardrail design reference is maintained in:

- `00_Documentation/AIRepositoryWorkflow_v2_Design.md`

The v2 design has been reviewed and incorporated into the active workflow. It remains available as a design record.

# Palworld Modding Workshop

This repository is the authoritative development workspace for a personal Palworld installation. It keeps development, testing, deployment, and archival work separate from the live game installation.

## Current milestone

**Sprint 4 is complete and closed.** It delivered the persistent mod catalog,
component ownership, compatibility and conflict reporting, profile mod sets,
deterministic deployment assembly, and preview-only upgrade and removal
planning.

**Sprint 5 is active.** Within Sprint 5.1, repository awareness and structure
documentation (5.1.1), the workshop runtime/session model (5.1.2), and the
structured dashboard data model (5.1.3) are complete. Menu UX integration
(5.1.4) is active, with a dashboard-driven adaptive control-center checkpoint
implemented and validated. Broader diagnostics and health reporting (5.1.5)
follows.

See [Roadmap.md](00_Documentation/Roadmap.md) for the accepted milestone boundary
and future scope.

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
Get-PwWorkshopDashboard
```

The `Bootstrap.ps1` runtime/session contract, context lifetime, and read-only
initialization boundary are documented in
[Environment.md](00_Documentation/Environment.md). The structured, read-only
repository/profile/catalog/deployment/update-cache/diagnostic composition model
is documented in [WorkshopDashboard.md](00_Documentation/WorkshopDashboard.md).
PowerShell conventions and runtime requirements are documented in
[PowerShellStandards.md](00_Documentation/PowerShellStandards.md).

## One-command menu

Start the menu-driven workshop from the repository root:

```powershell
pwsh -NoProfile -File ./PwWorkshop.ps1
```

The workshop menu presents one read-only dashboard snapshot on every redraw,
including profile, repository, catalog, deployment, update-cache, and diagnostic
state. It also provides catalog, archive, staging, component-ownership,
compatibility, profile-set, build, deployment, diagnostic, inventory, history,
and Nexus update workflows. The interface redraws automatically when its
terminal window is resized.

## Tests

Run the automated checks from the repository root with PowerShell 7.6.4:

```powershell
pwsh -NoProfile -File ./10_Scripts/Tasks/Test-Workshop.ps1
```

In VS Code, run the default test task: `PwTools: Test`.

## Scope

This is a personal learning and backup workspace. Machine-specific integration checks and the `Stable` profile are intentional.

===== READ EVERY SINGLE DOCUMENT IN 00_Documentation/* =====
