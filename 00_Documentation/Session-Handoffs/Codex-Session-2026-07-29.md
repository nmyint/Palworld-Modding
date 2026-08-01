I am building a private, personal Palworld Modding Workshop in PowerShell.

Repository:
D:\Projects\Palworld-Modding

GitHub:
https://github.com/nmyint/Palworld-Modding

This is primarily a learning, local backup, and personal mod-management project. It does not need to be generalized for public distribution. PowerShell remains the primary language and PwWorkshop.ps1 is the intended one-command, menu-driven interface.

Current architecture:
- 00_Documentation: operating instructions and roadmap
- 01_Archives: original Nexus/GitHub ZIP and 7z downloads
- 02_Staging: editable game-shaped working configuration
- 03_Mod_Library: curated, versioned, manifest-backed packages
- 04_Projects: active mod-development projects
- 05_Deployment: deterministic deployment assembly
- 06_Packages: completed portable packages
- 07_Testing: test plans/results
- 08_Tools: external tool references
- 09_Logs: deployment and diagnostic logs
- 10_Scripts: PowerShell module, commands, menu, and tests
- 11_Research: experiments/references
- 12_Templates: reusable project templates
- 13_Backups: deployment and recovery backups
- 14_Temp: disposable working data
- 15_Sandbox: isolated experiments
- 16_Profiles: installation and mod-set profiles

Safety rules:
1. Never modify the live game without explicit approval.
2. Preview all destructive or external changes.
3. Preserve original downloads.
4. Use SHA-256 manifests and provenance records.
5. Back up files before overwriting or removing them.
6. Do not silently remove modified, unknown, shared, or current-game-only files.
7. Add Pester tests and documentation for new behavior.
8. Preserve the dynamic, menu-driven interface.
9. Keep PowerShell modules separated by responsibility.
10. Stage, review, test, then commit and push each completed checkpoint.

Sprints 0–3 are complete.

Sprint 4 currently provides:
- Persistent Nexus-aware mod catalog
- Archive filename and content inspection
- ZIP and 7z support
- UE4SS, PAK, LogicMods, Native, configuration, and mixed-package handling
- PalSchema add-on and hybrid-package routing
- Component ownership reconciliation
- Profile mod sets
- Deterministic deployment assembly
- SHA-256 deployment verification
- Current-game comparison
- Backup and restoration
- Nexus update checks
- Manual downloads and Premium-only direct downloads
- Preview-only upgrade and removal plans
- Deployment requirement and expected-destination warnings
- Responsive PwWorkshop menu
- More than 90 Pester tests

Do not begin Sprint 5 until Sprint 4.3 and 4.5 are confirmed complete and committed.

SPRINT 5 — DEVELOPMENT AND TESTING

Goal:
Support active Palworld mod projects and repeatable compatibility investigations without risking the stable installation.

Sprint 5.1 — Project templates
- Add New-PwProject.
- Create templates for UE4SS Lua mods, PalSchema data mods, hybrid UE4SS/PalSchema mods, PAK research projects, and configuration-only projects.
- Store projects under 04_Projects\<ProjectName>.
- Generate project.json with name, version, type, source, requirements, target paths, and status.
- Keep templates under 12_Templates.
- Add numbered project creation to PwWorkshop.
- Validate identifiers and prevent unsafe paths.

Sprint 5.2 — Test profiles and sandbox builds
- Create isolated Test/Experimental profiles.
- Build experiments under 15_Sandbox without changing Stable, 03_Mod_Library, or the live game.
- Allow selected mods or candidate versions to be added to a temporary test set.
- Compare experimental output against Stable.
- Record creates, updates, removals, conflicts, requirements, and shared files.
- Require explicit promotion into the curated library.

Sprint 5.3 — Repeatable test plans
- Add test-plan JSON schema.
- Record mod/version, profile, Palworld version, UE4SS version, PalSchema version, test steps, expected results, actual results, status, notes, and timestamps.
- Store plans and results under 07_Testing.
- Add menu options to start, resume, pass, fail, or abandon a test.
- Preserve failed-test evidence rather than deleting it.

Sprint 5.4 — Logs and diagnostic bundles
- Collect relevant UE4SS logs, PalSchema logs, workshop logs, configuration snapshots, manifests, hashes, profile details, and dependency versions.
- Redact API keys, credentials, usernames where appropriate, and unrelated save data.
- Create timestamped diagnostic bundles.
- Add Get-PwDiagnosticBundle or New-PwDiagnosticBundle.
- Make collection previewable and selectable.

Sprint 5.5 — Game launch helpers
- Add preview-first game-launch helpers for selected profiles.
- Verify required files and dependencies before launch.
- Never modify Steam launch options globally without approval.
- Record the exact profile and assembly used.
- Support launching normally or opening the game directory/log directory.
- Treat server/client requirements separately.

Sprint 5.6 — Compatibility investigations
- Record tested mod combinations.
- Track confirmed compatible, incompatible, conditional, superseded, and unknown relationships.
- Do not infer incompatibility merely because two mods edit similar areas.
- Add compatibility notes only after reviewed evidence.
- Support experimental compatibility patches as separate projects.
- Keep PAK editing and rebuilding deferred unless explicitly approved.

Sprint 5 completion criteria:
- Projects can be created from templates.
- Experiments are isolated.
- Test results are reproducible.
- Diagnostic evidence can be collected.
- Tested compatibility information feeds the catalog.
- Stable and live-game files remain protected.

SPRINT 6 — PACKAGING AND MAINTENANCE

Goal:
Make the workshop reproducible, recoverable, and maintainable over time.

Sprint 6.1 — Versioning and changelog
- Adopt semantic versioning for the workshop module.
- Generate or maintain CHANGELOG.md.
- Record sprint, command, schema, and behavior changes.
- Avoid rewriting historical releases.
- Add release-readiness validation.

Sprint 6.2 — Reproducible packages
- Build portable workshop packages from tracked source and required manifests.
- Exclude 01_Archives, 02_Staging, 03_Mod_Library payload archives, deployment output, backups, logs, temp files, secrets, and machine-specific data unless explicitly requested.
- Include dependency/setup documentation.
- Generate SHA-256 checksum manifests.
- Verify packages by extracting them into an isolated temporary directory.

Sprint 6.3 — Release preparation
- Add New-PwReleasePlan and Invoke-PwReleasePreparation.
- Preview changed files, version, changelog, tests, package contents, and Git status.
- Do not automatically publish public releases.
- Support a private GitHub/tag workflow only after approval.
- Keep normal Git operations separate from release packaging.

Sprint 6.4 — Disaster recovery
- Test restoration on an isolated mock workshop.
- Verify that a new computer can clone the repository, install prerequisites, restore external archives/backups, rebuild profiles, and validate the environment.
- Document which folders belong in Git and which belong in Google Drive/OneDrive/7z backups.
- Verify backup retention and checksums.
- Never test recovery against the only live copy.

Sprint 6.5 — Update monitoring
- Generate maintenance reports for Nexus mods, GitHub tools, UE4SS, and PalSchema.
- Preserve single-player, dedicated-server, multiplayer, Steam/Game Pass, UE4SS/PAK, and other variant selection.
- Do not automatically install an update.
- Report hidden, deleted, unavailable, ambiguous, and manually downloaded mods.
- Track last checked, last available version, selected file ID, and update disposition.

Sprint 6.6 — Repository health
- Validate documentation links and menu-flow documentation.
- Validate JSON schemas, manifests, profiles, catalog records, and module exports.
- Detect obsolete commands, duplicated logic, stale TODOs, orphaned files, and inconsistent version references.
- Run all Pester tests.
- Produce a final health report.
- Confirm Git status is clean before release.

Sprint 6 completion criteria:
- The workshop has a reproducible release process.
- A clean-machine recovery procedure is documented and tested.
- Update monitoring is repeatable.
- Checksums and provenance are preserved.
- Repository and documentation health checks pass.
- The project remains private and safe for personal use.

Deferred future work:
- Read-only PAK inspection
- repak/UnrealPak/FModel/UAssetGUI integration
- PAK modification and rebuilding
- C#/.NET hybrid architecture
- GUI replacement for the PowerShell menu

These should remain deferred until the PowerShell workflow is stable and reviewed.

Before making changes:
1. Read README.md, 00_Documentation/Roadmap.md, MenuFlow.md, FolderStructure.md, Deployment.md, ModIntake.md, and the module manifest.
2. Inspect git status and recent commits.
3. Run the existing Pester suite.
4. Continue only from the current repository state.
5. Do not assume Sprint 4.3 or 4.5 is complete unless the roadmap and Git history confirm it.
Important current handoff detail: Sprint 4.3/4.5 closure work has started locally after commit 90ae3fa, but it is not yet completed or committed. A normal chat should inspect git status before proceeding.


Wednesday 10:38 AM
