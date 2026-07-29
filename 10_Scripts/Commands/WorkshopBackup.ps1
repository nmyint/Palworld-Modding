<#
.SYNOPSIS
    Creates portable, compressed backups of the durable workshop state.
#>

Set-StrictMode -Version Latest

function Get-PwWorkshopBackupSettings {

    [CmdletBinding()]
    param(
        [string]$DestinationRoot,

        [int]$RetentionCount
    )

    $configuration = Get-PwWorkshopConfig
    $configuredDestination = ''
    $configuredRetention = 5

    if ($configuration.PSObject.Properties.Name -contains 'Backup') {
        if (
            $configuration.Backup.PSObject.Properties.Name -contains
                'DestinationRoot'
        ) {
            $configuredDestination = [System.Environment]::ExpandEnvironmentVariables(
                [string]$configuration.Backup.DestinationRoot
            )
        }

        if (
            $configuration.Backup.PSObject.Properties.Name -contains
                'RetentionCount'
        ) {
            $configuredRetention = [int]$configuration.Backup.RetentionCount
        }
    }

    $resolvedDestination = if (
        -not [string]::IsNullOrWhiteSpace($DestinationRoot)
    ) {
        [System.Environment]::ExpandEnvironmentVariables($DestinationRoot)
    }
    else {
        $configuredDestination
    }

    if ([string]::IsNullOrWhiteSpace($resolvedDestination)) {
        throw 'No workshop backup destination is configured. Supply ' +
            '-DestinationRoot or set Backup.DestinationRoot in Workshop.json.'
    }

    $effectiveRetention = if ($RetentionCount -ge 1) {
        $RetentionCount
    }
    else {
        $configuredRetention
    }

    if ($effectiveRetention -lt 1 -or $effectiveRetention -gt 100) {
        throw 'Workshop backup retention must be between 1 and 100.'
    }

    [PSCustomObject]@{
        DestinationRoot = [System.IO.Path]::GetFullPath($resolvedDestination)
        RetentionCount = $effectiveRetention
    }
}

function Get-PwGitBackupMetadata {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Root
    )

    $commit = ''
    $branch = ''
    $hasChanges = $false

    try {
        $commit = (
            & git -C $Root rev-parse HEAD 2>$null
        ).Trim()
        $branch = (
            & git -C $Root branch --show-current 2>$null
        ).Trim()
        $hasChanges = @(
            & git -C $Root status --porcelain 2>$null
        ).Count -gt 0
    }
    catch {
        # Git metadata is helpful but not required for a filesystem backup.
    }

    [PSCustomObject]@{
        Commit = $commit
        Branch = $branch
        HasUncommittedChanges = $hasChanges
    }
}

<#
.SYNOPSIS
    Creates a maximum-compression 7z backup with metadata and retention.
.DESCRIPTION
    Archives the durable workshop state for external storage such as Google
    Drive. Git internals, staging, generated deployment output, logs, workshop
    backups, and sandbox files are excluded by default. Original downloads and
    curated mod packages are included.
.PARAMETER DestinationRoot
    External directory for backup archives. Overrides configured destination.
.PARAMETER RetentionCount
    Number of newest workshop backup sets to retain. Defaults to configuration.
.PARAMETER IncludeDisposable
    Includes staging, deployment output, logs, and sandbox files. The .git
    directory and 13_Backups remain excluded.
.OUTPUTS
    PSCustomObject describing the archive, checksum, metadata, and retention.
#>
function New-PwWorkshopBackup {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [string]$DestinationRoot = '',

        [ValidateRange(0, 100)]
        [int]$RetentionCount = 0,

        [switch]$IncludeDisposable
    )

    $settings = Get-PwWorkshopBackupSettings `
        -DestinationRoot $DestinationRoot `
        -RetentionCount $RetentionCount
    $workshopRoot = [System.IO.Path]::GetFullPath((Get-PwPaths).Root)
    $destination = $settings.DestinationRoot
    $workshopPrefix = $workshopRoot.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar

    if (
        $destination.Equals(
            $workshopRoot,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        $destination.StartsWith(
            $workshopPrefix,
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        throw 'Workshop backups must be stored outside the workshop root.'
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
    $baseName = "Palworld-Workshop-$timestamp"
    $archivePath = Join-Path $destination "$baseName.7z"
    $metadataPath = Join-Path $destination "$baseName.json"
    $checksumPath = Join-Path $destination "$baseName.sha256"
    $exclusions = [System.Collections.Generic.List[string]]::new()
    $exclusions.Add('.git')
    $exclusions.Add('13_Backups')

    if (-not $IncludeDisposable) {
        foreach ($path in @(
            '02_Staging',
            '05_Deployment',
            '09_Logs',
            '15_Sandbox'
        )) {
            $exclusions.Add($path)
        }
    }

    $plan = [PSCustomObject]@{
        WorkshopRoot = $workshopRoot
        DestinationRoot = $destination
        ArchivePath = $archivePath
        MetadataPath = $metadataPath
        ChecksumPath = $checksumPath
        RetentionCount = $settings.RetentionCount
        Exclusions = @($exclusions)
        IncludeDisposable = [bool]$IncludeDisposable
        Created = $false
    }

    if (-not $PSCmdlet.ShouldProcess(
        $archivePath,
        'Create compressed workshop backup and apply retention'
    )) {
        return $plan
    }

    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    $sevenZip = Get-Pw7ZipExecutable
    $arguments = [System.Collections.Generic.List[string]]::new()

    foreach ($argument in @(
        'a',
        '-t7z',
        '-mx=9',
        '-mmt=on',
        $archivePath,
        '.'
    )) {
        $arguments.Add($argument)
    }

    foreach ($excludedPath in $exclusions) {
        $arguments.Add("-xr!$excludedPath")
    }

    try {
        $previousLocation = Get-Location

        try {
            Set-Location -LiteralPath $workshopRoot
            & $sevenZip @arguments | Out-Null
        }
        finally {
            Set-Location -LiteralPath $previousLocation
        }

        if ($LASTEXITCODE -ne 0) {
            throw "7-Zip exited with code $LASTEXITCODE."
        }

        $archiveHash = (
            Get-FileHash -LiteralPath $archivePath -Algorithm SHA256
        ).Hash
        $git = Get-PwGitBackupMetadata -Root $workshopRoot
        $metadata = [PSCustomObject]@{
            SchemaVersion = '1.0'
            CreatedAt = Get-Date
            WorkshopRoot = $workshopRoot
            ComputerName = [System.Environment]::MachineName
            ArchiveName = [System.IO.Path]::GetFileName($archivePath)
            ArchiveLength = (
                Get-Item -LiteralPath $archivePath
            ).Length
            ArchiveHash = $archiveHash
            HashAlgorithm = 'SHA256'
            SevenZipPath = $sevenZip
            Exclusions = @($exclusions)
            IncludeDisposable = [bool]$IncludeDisposable
            Git = $git
        }
        Write-PwJson -InputObject $metadata -Path $metadataPath
        Set-Content `
            -LiteralPath $checksumPath `
            -Value "$archiveHash  $($metadata.ArchiveName)" `
            -Encoding utf8
    }
    catch {
        foreach ($path in @($archivePath, $metadataPath, $checksumPath)) {
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                Remove-Item -LiteralPath $path -Force
            }
        }

        throw
    }

    $removed = [System.Collections.Generic.List[string]]::new()
    $archives = @(
        Get-ChildItem `
            -LiteralPath $destination `
            -Filter 'Palworld-Workshop-*.7z' `
            -File |
            Sort-Object Name -Descending
    )

    foreach ($expired in @($archives | Select-Object -Skip $settings.RetentionCount)) {
        $expiredBase = [System.IO.Path]::GetFileNameWithoutExtension(
            $expired.Name
        )

        foreach ($extension in @('.7z', '.json', '.sha256')) {
            $expiredPath = Join-Path $destination "$expiredBase$extension"

            if (Test-Path -LiteralPath $expiredPath -PathType Leaf) {
                Remove-Item -LiteralPath $expiredPath -Force
                $removed.Add($expiredPath)
            }
        }
    }

    $plan.Created = $true
    $plan | Add-Member -NotePropertyName ArchiveHash -NotePropertyValue (
        Get-FileHash -LiteralPath $archivePath -Algorithm SHA256
    ).Hash
    $plan | Add-Member -NotePropertyName RemovedByRetention -NotePropertyValue (
        @($removed)
    )
    $plan
}
