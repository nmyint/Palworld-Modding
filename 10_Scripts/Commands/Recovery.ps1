<#
.SYNOPSIS
    Provides backup validation, restoration, inventory, history, and diagnostics.
#>

Set-StrictMode -Version Latest

function Test-PwRecoveryRelativePath {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.Contains("`0")) {
        return $false
    }

    $normalized = $Path.Replace('\', '/')

    if ($normalized.StartsWith('/') -or $normalized.Contains(':')) {
        return $false
    }

    foreach ($segment in $normalized.Split('/')) {
        if ($segment -in @('', '.', '..')) {
            return $false
        }
    }

    $true
}

function Resolve-PwBackupManifestPath {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $candidate = [System.IO.Path]::GetFullPath($Path)

    if (Test-Path -LiteralPath $candidate -PathType Container) {
        $candidate = Join-Path $candidate 'manifest.json'
    }

    $candidate
}

function Get-PwContainedPath {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    if (-not (Test-PwRecoveryRelativePath -Path $RelativePath)) {
        throw "Unsafe relative path: $RelativePath"
    }

    $resolvedRoot = [System.IO.Path]::GetFullPath($Root)
    $resolvedPath = [System.IO.Path]::GetFullPath(
        (Join-Path $resolvedRoot $RelativePath)
    )
    $rootPrefix = $resolvedRoot.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar

    if (-not $resolvedPath.StartsWith(
        $rootPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Path escapes its allowed root: $RelativePath"
    }

    $resolvedPath
}

<#
.SYNOPSIS
    Validates a deployment backup manifest and every recorded backup file.
.PARAMETER Path
    Backup directory or manifest.json path.
.OUTPUTS
    Validation result containing errors and normalized file records.
#>
function Test-PwBackup {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $files = [System.Collections.Generic.List[object]]::new()
    $manifestPath = Resolve-PwBackupManifestPath -Path $Path
    $manifest = $null

    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        $errors.Add("Backup manifest was not found: $manifestPath")
    }
    else {
        try {
            $manifest = Read-PwJson -Path $manifestPath
        }
        catch {
            $errors.Add("Backup manifest is not readable JSON: $($_.Exception.Message)")
        }
    }

    if ($manifest) {
        foreach ($property in @(
            'SchemaVersion',
            'Profile',
            'CreatedAt',
            'DestinationRoot',
            'Files'
        )) {
            if ($manifest.PSObject.Properties.Name -notcontains $property) {
                $errors.Add("Backup manifest is missing '$property'.")
            }
        }
    }

    if ($manifest -and $errors.Count -eq 0) {
        if ([string]$manifest.SchemaVersion -ne '1.0') {
            $errors.Add(
                "Unsupported backup schema version: $($manifest.SchemaVersion)"
            )
        }

        $backupRoot = Split-Path -Parent $manifestPath
        $palBackupRoot = Join-Path $backupRoot 'Pal'
        $seenPaths = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )

        foreach ($file in @($manifest.Files)) {
            foreach ($property in @('RelativePath', 'Hash')) {
                if ($file.PSObject.Properties.Name -notcontains $property) {
                    $errors.Add("Backup file entry is missing '$property'.")
                }
            }

            if (
                $file.PSObject.Properties.Name -notcontains 'RelativePath' -or
                -not (Test-PwRecoveryRelativePath -Path $file.RelativePath)
            ) {
                $errors.Add('Backup contains an unsafe relative path.')
                continue
            }

            if (-not $seenPaths.Add([string]$file.RelativePath)) {
                $errors.Add("Duplicate backup path: $($file.RelativePath)")
                continue
            }

            if ([string]$file.Hash -notmatch '^[A-Fa-f0-9]{64}$') {
                $errors.Add("Invalid SHA-256 hash: $($file.RelativePath)")
                continue
            }

            try {
                $backupPath = Get-PwContainedPath `
                    -Root $palBackupRoot `
                    -RelativePath $file.RelativePath
                $destinationPath = Get-PwContainedPath `
                    -Root $manifest.DestinationRoot `
                    -RelativePath $file.RelativePath
            }
            catch {
                $errors.Add($_.Exception.Message)
                continue
            }

            $actualHash = ''
            $status = 'Missing'

            if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
                $actualHash = (
                    Get-FileHash -LiteralPath $backupPath -Algorithm SHA256
                ).Hash
                $status = if ($actualHash -eq [string]$file.Hash) {
                    'Verified'
                }
                else {
                    'HashMismatch'
                }
            }

            if ($status -ne 'Verified') {
                $errors.Add(
                    "Backup file $status`: $($file.RelativePath)"
                )
            }

            $files.Add([PSCustomObject]@{
                RelativePath = [string]$file.RelativePath
                BackupPath = $backupPath
                DestinationPath = $destinationPath
                ExpectedHash = [string]$file.Hash
                ActualHash = $actualHash
                Status = $status
            })
        }
    }

    [PSCustomObject]@{
        Path = $Path
        ManifestPath = $manifestPath
        Manifest = $manifest
        IsValid = $errors.Count -eq 0
        Errors = @($errors)
        Files = @($files)
    }
}

<#
.SYNOPSIS
    Builds a read-only restore plan from a validated deployment backup.
.PARAMETER Path
    Backup directory or manifest.json path.
.OUTPUTS
    Restore plan with Create, Update, and Unchanged actions.
#>
function Get-PwRestorePlan {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $validation = Test-PwBackup -Path $Path

    if (-not $validation.IsValid) {
        throw 'Backup validation failed: ' + ($validation.Errors -join ' ')
    }

    $files = @(
        foreach ($file in $validation.Files) {
            $destinationHash = ''
            $action = 'Create'

            if (
                Test-Path `
                    -LiteralPath $file.DestinationPath `
                    -PathType Leaf
            ) {
                $destinationHash = (
                    Get-FileHash `
                        -LiteralPath $file.DestinationPath `
                        -Algorithm SHA256
                ).Hash
                $action = if ($destinationHash -eq $file.ExpectedHash) {
                    'Unchanged'
                }
                else {
                    'Update'
                }
            }

            [PSCustomObject]@{
                RelativePath = $file.RelativePath
                BackupPath = $file.BackupPath
                DestinationPath = $file.DestinationPath
                BackupHash = $file.ExpectedHash
                DestinationHash = $destinationHash
                Action = $action
            }
        }
    )

    [PSCustomObject]@{
        Profile = [string]$validation.Manifest.Profile
        ManifestPath = $validation.ManifestPath
        DestinationRoot = [string]$validation.Manifest.DestinationRoot
        Files = $files
        CreateCount = @($files | Where-Object Action -eq 'Create').Count
        UpdateCount = @($files | Where-Object Action -eq 'Update').Count
        UnchangedCount = @($files | Where-Object Action -eq 'Unchanged').Count
        CanRestore = $true
    }
}

function Write-PwRestoreLog {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $root = Join-Path (Get-PwPaths).Logs 'Restores'
    $path = Join-Path $root (
        '{0}-{1}.json' -f (
            Get-Date -Format 'yyyyMMdd-HHmmssfff'
        ), $InputObject.Profile
    )
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    Write-PwJson -InputObject $InputObject -Path $path
    $path
}

<#
.SYNOPSIS
    Previews or explicitly restores a validated deployment backup.
.DESCRIPTION
    Preview is the default. Applying first preserves current target files beneath
    13_Backups\PreRestore, then restores only Create and Update actions and
    verifies every resulting hash.
.PARAMETER Path
    Backup directory or manifest.json path.
.PARAMETER Apply
    Explicitly enables restoration.
#>
function Restore-PwDeployment {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$Apply
    )

    $plan = Get-PwRestorePlan -Path $Path

    if (-not $Apply) {
        return $plan
    }

    $actionable = @(
        $plan.Files |
            Where-Object { $_.Action -in @('Create', 'Update') }
    )

    if ($actionable.Count -eq 0) {
        return [PSCustomObject]@{
            Profile = $plan.Profile
            Status = 'Unchanged'
            Applied = $false
            SafetyBackup = ''
            LogPath = ''
            Files = @()
        }
    }

    if (-not $PSCmdlet.ShouldProcess(
        $plan.DestinationRoot,
        "Restore $($actionable.Count) file(s) from validated backup"
    )) {
        return $plan
    }

    $safetyRoot = Join-Path (
        Join-Path (Get-PwPaths).Backups 'PreRestore'
    ) (
        '{0}-{1}' -f (
            Get-Date -Format 'yyyyMMdd-HHmmssfff'
        ), $plan.Profile
    )
    $preserved = [System.Collections.Generic.List[object]]::new()

    foreach ($file in $actionable) {
        $currentBackupHash = (
            Get-FileHash -LiteralPath $file.BackupPath -Algorithm SHA256
        ).Hash

        if ($currentBackupHash -ne $file.BackupHash) {
            throw "Backup changed after planning: $($file.RelativePath)"
        }

        if ($file.Action -eq 'Update') {
            if (
                -not (
                    Test-Path `
                        -LiteralPath $file.DestinationPath `
                        -PathType Leaf
                )
            ) {
                throw "Restore target disappeared: $($file.RelativePath)"
            }

            $currentDestinationHash = (
                Get-FileHash `
                    -LiteralPath $file.DestinationPath `
                    -Algorithm SHA256
            ).Hash

            if ($currentDestinationHash -ne $file.DestinationHash) {
                throw "Restore target changed after planning: $($file.RelativePath)"
            }

            $preservePath = Get-PwContainedPath `
                -Root (Join-Path $safetyRoot 'Pal') `
                -RelativePath $file.RelativePath
            New-Item `
                -ItemType Directory `
                -Path (Split-Path -Parent $preservePath) `
                -Force |
                Out-Null
            Copy-Item `
                -LiteralPath $file.DestinationPath `
                -Destination $preservePath `
                -Force
            $preserved.Add([PSCustomObject]@{
                RelativePath = $file.RelativePath
                OriginalPath = $file.DestinationPath
                BackupPath = $preservePath
                Hash = $currentDestinationHash
            })
        }
        elseif (Test-Path -LiteralPath $file.DestinationPath) {
            throw "Restore target appeared after planning: $($file.RelativePath)"
        }
    }

    if ($preserved.Count -gt 0) {
        Write-PwJson -InputObject ([PSCustomObject]@{
            SchemaVersion = '1.0'
            Profile = $plan.Profile
            CreatedAt = Get-Date
            Reason = 'PreRestore'
            SourceRoot = $plan.DestinationRoot
            DestinationRoot = $plan.DestinationRoot
            Files = @($preserved)
        }) -Path (Join-Path $safetyRoot 'manifest.json')
    }

    $restored = [System.Collections.Generic.List[object]]::new()

    try {
        foreach ($file in $actionable) {
            New-Item `
                -ItemType Directory `
                -Path (Split-Path -Parent $file.DestinationPath) `
                -Force |
                Out-Null
            Copy-Item `
                -LiteralPath $file.BackupPath `
                -Destination $file.DestinationPath `
                -Force
            $restoredHash = (
                Get-FileHash `
                    -LiteralPath $file.DestinationPath `
                    -Algorithm SHA256
            ).Hash

            if ($restoredHash -ne $file.BackupHash) {
                throw "Post-restore verification failed: $($file.RelativePath)"
            }

            $restored.Add([PSCustomObject]@{
                RelativePath = $file.RelativePath
                DestinationPath = $file.DestinationPath
                Hash = $restoredHash
                Action = $file.Action
            })
        }
    }
    catch {
        $failure = [PSCustomObject]@{
            SchemaVersion = '1.0'
            Profile = $plan.Profile
            Status = 'Failed'
            Applied = $false
            RestoredAt = Get-Date
            SourceManifest = $plan.ManifestPath
            DestinationRoot = $plan.DestinationRoot
            SafetyBackup = if ($preserved.Count -gt 0) {
                $safetyRoot
            }
            else {
                ''
            }
            Error = $_.Exception.Message
            Files = @($restored)
        }
        $failureLog = ''

        try {
            $failureLog = Write-PwRestoreLog -InputObject $failure
        }
        catch {
            Write-Warning "Restore failure log could not be written: $_"
        }

        throw [System.InvalidOperationException]::new(
            "Restore failed: $($failure.Error) Failure log: $failureLog"
        )
    }

    $result = [PSCustomObject]@{
        SchemaVersion = '1.0'
        Profile = $plan.Profile
        Status = 'Succeeded'
        Applied = $true
        RestoredAt = Get-Date
        SourceManifest = $plan.ManifestPath
        DestinationRoot = $plan.DestinationRoot
        SafetyBackup = if ($preserved.Count -gt 0) {
            $safetyRoot
        }
        else {
            ''
        }
        Files = @($restored)
    }
    $logPath = Write-PwRestoreLog -InputObject $result

    [PSCustomObject]@{
        Profile = $plan.Profile
        Status = 'Succeeded'
        Applied = $true
        SafetyBackup = $result.SafetyBackup
        LogPath = $logPath
        Files = @($restored)
    }
}

<#
.SYNOPSIS
    Returns structured deployment and restoration history.
#>
function Get-PwDeploymentHistory {

    [CmdletBinding()]
    param()

    $logsRoot = (Get-PwPaths).Logs
    $records = [System.Collections.Generic.List[object]]::new()

    foreach ($definition in @(
        @{ Type = 'Deployment'; Directory = 'Deployments' },
        @{ Type = 'Restore'; Directory = 'Restores' }
    )) {
        $root = Join-Path $logsRoot $definition.Directory

        if (-not (Test-Path -LiteralPath $root -PathType Container)) {
            continue
        }

        foreach ($file in Get-ChildItem -LiteralPath $root -Filter *.json -File) {
            try {
                $record = Read-PwJson -Path $file.FullName
                $records.Add([PSCustomObject]@{
                    Type = $definition.Type
                    Timestamp = if (
                        $record.PSObject.Properties.Name -contains 'AppliedAt'
                    ) {
                        $record.AppliedAt
                    }
                    elseif (
                        $record.PSObject.Properties.Name -contains 'RestoredAt'
                    ) {
                        $record.RestoredAt
                    }
                    else {
                        $file.LastWriteTime
                    }
                    Profile = [string]$record.Profile
                    Status = [string]$record.Status
                    FileCount = @($record.Files).Count
                    Path = $file.FullName
                    IsValid = $true
                    Error = ''
                })
            }
            catch {
                $records.Add([PSCustomObject]@{
                    Type = $definition.Type
                    Timestamp = $file.LastWriteTime
                    Profile = ''
                    Status = 'Unreadable'
                    FileCount = 0
                    Path = $file.FullName
                    IsValid = $false
                    Error = $_.Exception.Message
                })
            }
        }
    }

    @($records | Sort-Object Timestamp -Descending)
}

<#
.SYNOPSIS
    Returns known-good mod installation records with current hash status.
#>
function Get-PwInstallationInventory {

    [CmdletBinding()]
    param()

    $root = Join-Path (Get-PwPaths).CurrentInstallation 'Mods'

    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        return @()
    }

    @(
        foreach (
            $file in Get-ChildItem -LiteralPath $root -Filter *.json -Recurse -File
        ) {
            try {
                $record = Read-PwJson -Path $file.FullName
                $fileStates = @(
                    foreach ($installed in @($record.Files)) {
                        $status = 'Missing'
                        $actualHash = ''

                        if (
                            Test-Path `
                                -LiteralPath $installed.InstalledPath `
                                -PathType Leaf
                        ) {
                            $actualHash = (
                                Get-FileHash `
                                    -LiteralPath $installed.InstalledPath `
                                    -Algorithm SHA256
                            ).Hash
                            $status = if (
                                $actualHash -eq $installed.ExpectedHash
                            ) {
                                'Verified'
                            }
                            else {
                                'Changed'
                            }
                        }

                        [PSCustomObject]@{
                            RelativePath = $installed.RelativePath
                            Status = $status
                            ExpectedHash = $installed.ExpectedHash
                            ActualHash = $actualHash
                        }
                    }
                )
                $healthy = @(
                    $fileStates |
                        Where-Object Status -ne 'Verified'
                ).Count -eq 0

                [PSCustomObject]@{
                    Name = [string]$record.Name
                    Version = [string]$record.Version
                    Profile = [string]$record.Profile
                    Status = if ($healthy) {
                        'Verified'
                    }
                    else {
                        'Drifted'
                    }
                    ValidatedAt = $record.ValidatedAt
                    FileCount = $fileStates.Count
                    Files = $fileStates
                    RecordPath = $file.FullName
                    IsValid = $true
                    Error = ''
                }
            }
            catch {
                [PSCustomObject]@{
                    Name = ''
                    Version = ''
                    Profile = ''
                    Status = 'Unreadable'
                    ValidatedAt = $file.LastWriteTime
                    FileCount = 0
                    Files = @()
                    RecordPath = $file.FullName
                    IsValid = $false
                    Error = $_.Exception.Message
                }
            }
        }
    )
}

<#
.SYNOPSIS
    Returns one structured workshop recovery and health report.
#>
function Get-PwDiagnostics {

    [CmdletBinding()]
    param()

    $paths = Get-PwPaths
    $backups = @()

    $backups = @(
        foreach ($category in @('Deployments', 'PreRestore')) {
            $backupRoot = Join-Path $paths.Backups $category

            if (Test-Path -LiteralPath $backupRoot -PathType Container) {
                Get-ChildItem -LiteralPath $backupRoot -Directory |
                    ForEach-Object {
                        Test-PwBackup -Path $_.FullName
                    }
            }
        }
    )

    $inventory = @(Get-PwInstallationInventory)
    $history = @(Get-PwDeploymentHistory)
    $warnings = [System.Collections.Generic.List[string]]::new()

    foreach ($backup in $backups | Where-Object { -not $_.IsValid }) {
        $warnings.Add("Invalid backup: $($backup.ManifestPath)")
    }

    foreach ($item in $inventory | Where-Object Status -ne 'Verified') {
        $warnings.Add(
            "Installation inventory requires attention: $($item.RecordPath)"
        )
    }

    foreach ($item in $history | Where-Object { -not $_.IsValid }) {
        $warnings.Add("Unreadable history record: $($item.Path)")
    }

    [PSCustomObject]@{
        GeneratedAt = Get-Date
        Environment = Test-PwEnvironment
        BackupCount = $backups.Count
        ValidBackupCount = @($backups | Where-Object IsValid).Count
        InventoryCount = $inventory.Count
        VerifiedInstallationCount = @(
            $inventory |
                Where-Object Status -eq 'Verified'
        ).Count
        HistoryCount = $history.Count
        Warnings = @($warnings)
        IsHealthy = $warnings.Count -eq 0
    }
}
