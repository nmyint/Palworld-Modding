# Workshop Roadmap

This document is the authoritative sprint roadmap for the Palworld Modding
Workshop. It combines the verified repository history with the agreed direction
for future work.

Future sprint contents are planning targets. They may be refined as Palworld,
Unreal Engine tooling, or the workshop's needs change. Completed sprint records
should describe what was actually delivered.

## Status key

| Status | Meaning |
| --- | --- |
| Complete | Implemented, tested, committed, and pushed |
| In progress | The sprint has started but is not fully delivered |
| Planned | Agreed direction; detailed scope can still be refined |

## Sprint overview

| Sprint | Objective | Status |
| --- | --- | --- |
| 0 | Development environment and repository setup | Complete |
| 1 | Workshop foundation | Complete |
| 2 | PowerShell module and integrated development tooling | Complete |
| 3 | Safe workshop automation | In progress |
| 4 | Mod intake, library management, and validation | Planned |
| 5 | Mod development, testing, and diagnostics | Planned |
| 6 | Packaging, releases, restoration, and maintenance | Planned |

## Sprint 0 - Environment setup

Prepare the Windows development environment and establish source control.

Delivered:

- PowerShell 7, Git, VS Code, and GitHub tooling.
- Local Palworld Modding workspace.
- Git repository and GitHub remote.
- Initial ChatGPT and repository integration.

## Sprint 1 - Workshop foundation

Create a reproducible workspace that separates downloaded artifacts,
experiments, projects, tests, deployment output, and the live game.

Delivered:

- Numbered workshop folder structure.
- Workshop configuration and JSON helpers.
- Bootstrap and initialization scripts.
- Repository placeholders for intentionally empty directories.
- Initial documentation and operating conventions.

## Sprint 2 - Module and development tooling

Turn the initial scripts into repository-aware tooling that can be invoked
consistently from PowerShell and VS Code.

Delivered:

- `PalworldModding` PowerShell module.
- Workshop context and configuration commands.
- VS Code tasks and repository workflow.
- GitHub and ChatGPT connector setup.
- Automated module and workshop tests.

## Sprint 3 - Safe workshop automation

Build the operational foundation before processing or deploying real mods.

### Sprint 3.1 - Stabilization and standards

Status: Complete

- Normalized PowerShell layout, documentation, and comments.
- Established module conventions and comment-based help.
- Improved Pester coverage and validation.
- Confirmed a clean, reproducible repository baseline.

### Sprint 3.2 - Profile management

Status: Complete

- Added JSON profiles for installation-specific settings.
- Added profile discovery, creation, validation, and activation.
- Created the `Stable` profile for the local Palworld installation.
- Kept machine-specific paths outside reusable command logic.

### Sprint 3.3 - Safe deployment

Status: Complete

- Added SHA-256-based deployment planning.
- Classified files as Create, Update, or Unchanged.
- Made preview the default and required explicit approval to apply.
- Backed up files before overwriting them.
- Prohibited automatic deletion from the live game.
- Added structured deployment logs, documentation, tasks, and tests.

### Sprint 3.4 - Hardening and streamlining

Status: Complete

- Strengthen configuration and environment validation.
- Revalidate deployment plans immediately before applying them.
- Verify copied files and record partial failures.
- Preserve useful machine-specific integration checks while improving migration
  guidance.
- Simplify VS Code tasks and MCP configuration.
- Document dependencies, reserved settings, and the canonical workflow.

### Sprint 3.5 - Mod intake foundation

Status: Complete

- Import downloaded archives into `02_Staging`.
- Support original ZIP and 7z downloads.
- Inspect archive layout without writing to the live game.
- Detect path traversal, unsupported layouts, and suspicious files.
- Capture source, version, author, and download metadata.
- Classify common Palworld mod types and installation targets.
- Promote approved packages into flat
  `03_Mod_Library\<ModName>-<Version>` folders.
- Create maximum-compression library and portable deployment 7z packages.
- Generate deterministic content under `05_Deployment`.
- Record a hash-verified known-good installation after successful in-game
  testing.
- Clean matching staging and generated deployment artifacts only after the
  installation record is safely written.
- Test the workflow with isolated fixtures.

### Sprint 3.6 - Recovery and diagnostics

Status: Complete

- Validate deployment backup manifests and hashes.
- Add explicit, preview-first restoration with pre-restore safety copies.
- Add hash-verified installation inventory and deployment history commands.
- Expand known-good manifests into a complete installation inventory.
- Add structured recovery and workshop diagnostics.
- Complete the core workshop command palette.

## Sprint 4 - Mod library and compatibility

Manage multiple curated mods safely and assemble coherent installations. Archive
intake and basic validation belong to Sprint 3.5; Sprint 4 begins after packages
have entered the library.

Planned outcomes:

- Searchable mod catalog and normalized metadata schema.
- Version history linked to original archives.
- Duplicate and file-conflict detection.
- Dependency, incompatibility, and load-order metadata.
- Enable and disable mod sets through profiles.
- Deterministic deployment assembly from the curated library.
- Upgrade and removal plans that preserve rollback information.

## Sprint 5 - Development and testing

Support active mod projects and repeatable compatibility investigations.

Planned outcomes:

- Project templates and `New-PwProject` workflow.
- Isolated test profiles and sandbox deployments.
- Repeatable test plans and regression records.
- Log collection and diagnostic bundles.
- Game-launch helpers with selected profiles.
- Compatibility patch workflow.
- Automated validation for project and deployment artifacts.

## Sprint 6 - Packaging and maintenance

Make completed work reproducible, distributable, and maintainable.

Planned outcomes:

- Semantic versioning and changelog generation.
- Reproducible release packages.
- Git-integrated release preparation.
- Checksums, manifests, and provenance records.
- Tested backup restoration and disaster-recovery procedures.
- Mod-update monitoring and maintenance reports.
- Documentation synchronization and long-term repository health checks.

## Delivery rules

Every sprint or sub-sprint should:

1. Keep the live Palworld installation unchanged unless the user explicitly
   approves an apply operation.
2. Preview destructive or external changes before execution.
3. Preserve original downloads and create backups before overwriting files.
4. Add or update automated tests for new behavior.
5. Update user documentation and command help.
6. Leave the repository in a working, reviewable state.
7. Be reviewed before its final commit and push.
