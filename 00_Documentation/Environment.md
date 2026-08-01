# Local Environment

This repository is a personal learning and backup workspace. It intentionally
contains a `Stable` profile and integration tests for Noel's current Palworld
installation. It is not intended to be a redistributable PowerShell package.

## Required software

- PowerShell 7.6.4
- Git
- Node.js and npm for the filesystem MCP server
- 7-Zip with `7z.exe`
- VS Code with the recommended PowerShell extension
- Pester 3.4.0

Install the test dependency in PowerShell when preparing another computer:

```powershell
Install-Module Pester -RequiredVersion 3.4.0 -Scope CurrentUser
```

The test syntax currently targets Pester 3.4.0. Upgrading to Pester 5 should be a
deliberate future task rather than an incidental dependency update.

## Workshop runtime and session context

The workshop runtime/session foundation is implemented by:

```text
10_Scripts\Core\Bootstrap.ps1
```

The module loads this script during import. It can also be dot-sourced
independently because it loads the required JSON and workshop-configuration
helpers itself.

The runtime contract consists of three public commands:

- `Initialize-PwWorkshop` validates the workshop configuration, resolves the
  repository root and configuration path, loads configuration, and returns one
  structured context object.
- `Get-PwContext` lazily initializes that context on first use and returns the
  same cached context for the current imported-module session.
- `Reset-PwContext` removes only the cached in-memory context so the next access
  revalidates and reloads the current configuration.

The context object contains:

- `WorkshopRoot`;
- `ConfigPath`;
- `Config`;
- `Started`.

Initialization is read-only. It does not create directories, alter profiles,
write configuration, update the catalog, build deployment output, or modify the
live game. Filesystem or external changes remain the responsibility of explicit
commands with their own validation and `ShouldProcess` boundaries.

The cached context is module-session state, not durable project state. It is not
written to disk and does not survive a new PowerShell process or module reload.
Durable configuration remains in `.config\Workshop.json`; profiles, catalog
metadata, manifests, and other project records remain in their documented
locations.

`10_Scripts\Tests\PalworldModding.Tests.ps1` verifies initialization, repository
root resolution, configuration loading and validation, configured path
resolution, module exports, and compatibility with the existing command
surface.

This runtime/session model satisfies Sprint 5.1.2. A future dashboard model may
compose additional read-only state over the existing commands, but it must not
replace this context contract or introduce hidden mutation during startup.

## Moving to another computer

1. Clone or restore the repository.
2. Install the required software.
3. Open `Palworld-Modding.code-workspace` in VS Code.
4. Update `16_Profiles\Stable.json` with the new game and Saved-directory paths.
5. Update `.config\Workshop.json` for local tool paths and external backups.
6. Run `PwTools: Validate Environment`.
7. Run `PwTools: Test`.
8. Run `PwTools: Preview Deployment` before applying anything.

The filesystem MCP uses `${workspaceFolder}` and should not require a path change
after migration.

## Configuration status

The following settings currently affect behavior:

- `Deployment.ActiveProfile`
- `Preferences.CreateBackupsBeforeDeployment`
- configured workshop paths
- configured tool information
- `Tools.SevenZip`
- `Backup.DestinationRoot`
- `Backup.RetentionCount`

External backups use maximum-compression 7z packages. Configure a locally
synced Google Drive, OneDrive, or other external folder only after confirming
its filesystem path; see
[WorkshopBackup.md](WorkshopBackup.md).

The following settings are reserved for later sprints:

- `Preferences.AutoArchiveLogs`
- `Preferences.VerboseOutput`
- `Preferences.ConfirmDestructiveOperations`
- `Deployment.MirrorGameStructure`
- `Deployment.CleanDeploymentBeforeBuild`
- UE4SS and WinMerge automation settings

Reserved settings document intended behavior but should not be treated as active
automation yet.
