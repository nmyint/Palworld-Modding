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

Sprint 3.3 does not automate restoration. Restore operations remain manual until a
later sprint can add explicit validation and confirmation.
