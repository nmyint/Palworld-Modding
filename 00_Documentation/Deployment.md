# Safe Deployment

Sprint 3.3 introduces preview-first deployment from `05_Deployment\Pal` into the
active profile's Palworld `Pal` directory.

## Safety model

1. Deployment output is compared with the game installation using SHA-256 hashes.
2. `.gitkeep` placeholders are never included.
3. Preview is the default; no game files are changed without `-Apply`.
4. Applying requires high-impact confirmation.
5. Existing files that will be overwritten are backed up first.
6. Only Create and Update actions are copied.
7. Deployment never deletes files from the game installation.
8. Applied deployments produce a structured JSON log.
9. Source and destination hashes are revalidated immediately before copying.
10. Every copied destination is hashed again to verify the deployed content.

## Preview

```powershell
$plan = Get-PwDeploymentPlan
$plan
$plan.Files | Format-Table Action, RelativePath
```

`Invoke-PwDeployment` without parameters returns the same read-only preview:

```powershell
Invoke-PwDeployment
```

## Apply

Review the plan before applying it:

```powershell
Invoke-PwDeployment -Apply
```

PowerShell requests confirmation before writing to the game installation. Files
classified as Update are copied to a timestamped directory under
`13_Backups\Deployments` before deployment.

`-SkipBackup` is available for exceptional cases, but normal deployments should
retain the default backup behavior.

## Logs and restoration

Deployment logs are written beneath `09_Logs\Deployments`. Each backup includes a
`manifest.json` that records the original path, backup path, and pre-deployment
SHA-256 hash.

Successful logs include the verified hash for every copied file. If an operation
fails after approval, a failure log records the error, backup information, planned
files, and any files copied before the failure.

Sprint 3.4 does not automate restoration. Restore operations remain manual until
Sprint 3.6 adds explicit validation and confirmation.
