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
