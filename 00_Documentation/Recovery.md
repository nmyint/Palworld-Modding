# Recovery and Diagnostics

Sprint 3.6 provides hash-verified, preview-first recovery from deployment
backups. Restore commands never use the absolute `OriginalPath` recorded in a
manifest. Destinations are rebuilt from the validated destination root and safe
relative paths.

## Validate a backup

Backups are stored beneath `13_Backups\Deployments`. Pass either a backup folder
or its `manifest.json`:

```powershell
$validation = Test-PwBackup `
    -Path './13_Backups/Deployments/<timestamp>-Stable'
$validation.Files | Format-Table RelativePath, Status
```

Validation checks:

- required manifest properties;
- readable JSON;
- safe relative paths and root containment;
- duplicate paths;
- presence of every backup file; and
- SHA-256 hashes.

An invalid backup cannot produce a restore plan.

## Preview restoration

```powershell
$plan = Get-PwRestorePlan `
    -Path './13_Backups/Deployments/<timestamp>-Stable'
$plan.Files | Format-Table Action, RelativePath, DestinationPath
```

`Restore-PwDeployment` is also preview-only by default:

```powershell
Restore-PwDeployment `
    -Path './13_Backups/Deployments/<timestamp>-Stable'
```

Files are classified as `Create`, `Update`, or `Unchanged`.

## Apply restoration

After reviewing the plan:

```powershell
Restore-PwDeployment `
    -Path './13_Backups/Deployments/<timestamp>-Stable' `
    -Apply
```

Before overwriting an `Update` target, the command copies its current state into
`13_Backups\PreRestore`. It then revalidates the selected backup and target
hashes, restores the files, verifies the resulting hashes, and writes a
structured record beneath `09_Logs\Restores`.

Restoration does not delete unlisted game files.

## Installation inventory

Known-good records created after in-game testing are inspected with:

```powershell
Get-PwInstallationInventory |
    Format-Table Name, Version, Profile, Status, FileCount
```

Each recorded installed file is hashed again. A mod is `Verified` only when all
files match; missing or changed files make it `Drifted`.

## Deployment history

```powershell
Get-PwDeploymentHistory |
    Format-Table Timestamp, Type, Profile, Status, FileCount
```

This combines deployment and restore logs without changing them. Unreadable
records remain visible with `IsValid = False`.

## Combined diagnostics

```powershell
Get-PwDiagnostics
```

The report combines environment readiness, deployment and pre-restore backup
validity, installation inventory, deployment history, and actionable warnings.

Equivalent `PwTools` tasks are available from the VS Code command palette for
backup validation, restore preview, explicit restore, inventory, history, and
diagnostics.
