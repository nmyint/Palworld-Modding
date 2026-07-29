<#
.SYNOPSIS
    Provides safe workshop deployment operations.
.DESCRIPTION
    Defines commands that preview file changes, back up overwritten files, and
    explicitly apply deployment output to the active Palworld installation.
#>

Set-StrictMode -Version Latest

function New-PwDeploymentPlan {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [Parameter(Mandatory)]
        [string]$DestinationRoot
    )

    $resolvedSource = [System.IO.Path]::GetFullPath($SourceRoot)
    $resolvedDestination = [System.IO.Path]::GetFullPath($DestinationRoot)

    if (-not (Test-Path -LiteralPath $resolvedSource -PathType Container)) {
        throw "Deployment source does not exist: $resolvedSource"
    }

    $files = @(
        Get-ChildItem -LiteralPath $resolvedSource -Recurse -File |
            Where-Object { $_.Name -ne '.gitkeep' } |
            Sort-Object FullName |
            ForEach-Object {
                $relativePath = [System.IO.Path]::GetRelativePath(
                    $resolvedSource,
                    $_.FullName
                )
                $destinationPath = Join-Path $resolvedDestination $relativePath
                $sourceHash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
                $destinationHash = $null
                $action = 'Create'

                if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
                    $destinationHash = (
                        Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256
                    ).Hash
                    $action = if ($sourceHash -eq $destinationHash) {
                        'Unchanged'
                    }
                    else {
                        'Update'
                    }
                }

                [PSCustomObject]@{
                    RelativePath = $relativePath
                    SourcePath = $_.FullName
                    DestinationPath = $destinationPath
                    Action = $action
                    SourceHash = $sourceHash
                    DestinationHash = $destinationHash
                }
            }
    )

    [PSCustomObject]@{
        Profile = $ProfileName
        CreatedAt = Get-Date
        SourceRoot = $resolvedSource
        DestinationRoot = $resolvedDestination
        Files = $files
        CreateCount = @($files | Where-Object Action -eq 'Create').Count
        UpdateCount = @($files | Where-Object Action -eq 'Update').Count
        UnchangedCount = @($files | Where-Object Action -eq 'Unchanged').Count
    }
}

function Assert-PwDeploymentPlan {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Plan
    )

    foreach ($property in @(
        'Profile',
        'SourceRoot',
        'DestinationRoot',
        'Files'
    )) {
        if ($Plan.PSObject.Properties.Name -notcontains $property) {
            throw "Invalid deployment plan: missing property '$property'."
        }
    }
}

function Write-PwDeploymentLog {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $logRoot = Join-Path (Get-PwPaths).Logs 'Deployments'
    $logName = '{0}-{1}.json' -f (
        Get-Date -Format 'yyyyMMdd-HHmmssfff'
    ), $InputObject.Profile
    $logPath = Join-Path $logRoot $logName

    if (-not (Test-Path -LiteralPath $logRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    }

    Write-PwJson -InputObject $InputObject -Path $logPath

    $logPath
}

<#
.SYNOPSIS
    Creates a read-only deployment plan for the active profile.
.DESCRIPTION
    Compares deployment output with the active Palworld installation using SHA-256
    hashes. Placeholder `.gitkeep` files are excluded.
.OUTPUTS
    PSCustomObject containing Create, Update, and Unchanged file actions.
#>
function Get-PwDeploymentPlan {

    [CmdletBinding()]
    param()

    $deployment = Get-PwDeployment

    if (-not $deployment.CanDeploy) {
        throw "Active profile '$($deployment.ActiveProfile)' cannot deploy. " +
            'Verify the game installation and executable paths.'
    }

    New-PwDeploymentPlan `
        -ProfileName $deployment.ActiveProfile `
        -SourceRoot $deployment.TargetRoot `
        -DestinationRoot (Join-Path $deployment.GameInstallRoot 'Pal')
}

<#
.SYNOPSIS
    Backs up files that a deployment plan would overwrite.
.PARAMETER Plan
    Deployment plan returned by `Get-PwDeploymentPlan`.
.PARAMETER BackupRoot
    Optional backup parent directory. Defaults to `13_Backups\Deployments`.
.OUTPUTS
    PSCustomObject describing the backup location and copied files.
#>
function Backup-PwDeployment {

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$Plan,

        [string]$BackupRoot = (
            Join-Path (Get-PwPaths).Backups 'Deployments'
        )
    )

    process {
        Assert-PwDeploymentPlan -Plan $Plan

        $updateFiles = @($Plan.Files | Where-Object Action -eq 'Update')

        if ($updateFiles.Count -eq 0) {
            return [PSCustomObject]@{
                Profile = $Plan.Profile
                Created = $false
                BackupRoot = ''
                ManifestPath = ''
                Files = @()
            }
        }

        $backupName = '{0}-{1}' -f (
            Get-Date -Format 'yyyyMMdd-HHmmssfff'
        ), $Plan.Profile
        $backupPath = Join-Path $BackupRoot $backupName
        $palBackupRoot = Join-Path $backupPath 'Pal'
        $backupFiles = @()

        if ($PSCmdlet.ShouldProcess(
            $backupPath,
            "Back up $($updateFiles.Count) deployment target file(s)"
        )) {
            foreach ($file in $updateFiles) {
                $backupFile = Join-Path $palBackupRoot $file.RelativePath
                $backupDirectory = Split-Path -Parent $backupFile

                if (-not (Test-Path -LiteralPath $backupDirectory)) {
                    New-Item `
                        -ItemType Directory `
                        -Path $backupDirectory `
                        -Force |
                        Out-Null
                }

                Copy-Item `
                    -LiteralPath $file.DestinationPath `
                    -Destination $backupFile `
                    -Force

                $backupFiles += [PSCustomObject]@{
                    RelativePath = $file.RelativePath
                    OriginalPath = $file.DestinationPath
                    BackupPath = $backupFile
                    Hash = $file.DestinationHash
                }
            }

            $manifest = [PSCustomObject]@{
                SchemaVersion = '1.0'
                Profile = $Plan.Profile
                CreatedAt = Get-Date
                SourceRoot = $Plan.SourceRoot
                DestinationRoot = $Plan.DestinationRoot
                Files = $backupFiles
            }
            $manifestPath = Join-Path $backupPath 'manifest.json'
            Write-PwJson -InputObject $manifest -Path $manifestPath

            return [PSCustomObject]@{
                Profile = $Plan.Profile
                Created = $true
                BackupRoot = $backupPath
                ManifestPath = $manifestPath
                Files = $backupFiles
            }
        }

        [PSCustomObject]@{
            Profile = $Plan.Profile
            Created = $false
            BackupRoot = $backupPath
            ManifestPath = ''
            Files = @()
        }
    }
}

<#
.SYNOPSIS
    Previews or applies the active profile's deployment plan.
.DESCRIPTION
    Without `-Apply`, returns a read-only deployment plan. With `-Apply`, requests
    high-impact confirmation, backs up files that will be overwritten, copies only
    Create and Update actions, and writes a structured deployment log. It never
    deletes files from the game installation.
.PARAMETER Apply
    Explicitly enables file writes to the Palworld installation.
.PARAMETER SkipBackup
    Skips automatic overwrite backups. Use only when a backup is unnecessary.
.OUTPUTS
    Deployment plan in preview mode or PSCustomObject deployment result in apply mode.
#>
function Invoke-PwDeployment {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [switch]$Apply,

        [switch]$SkipBackup
    )

    $plan = Get-PwDeploymentPlan

    if (-not $Apply) {
        return $plan
    }

    $actionableFiles = @(
        $plan.Files |
            Where-Object { $_.Action -in @('Create', 'Update') }
    )

    if ($actionableFiles.Count -eq 0) {
        return [PSCustomObject]@{
            Profile = $plan.Profile
            Applied = $false
            Reason = 'No deployment changes were required.'
            Backup = $null
            LogPath = ''
            Files = @()
        }
    }

    if (-not $PSCmdlet.ShouldProcess(
        $plan.DestinationRoot,
        "Deploy $($actionableFiles.Count) file(s) for profile '$($plan.Profile)'"
    )) {
        return [PSCustomObject]@{
            Profile = $plan.Profile
            Applied = $false
            Reason = 'Deployment was not approved.'
            Backup = $null
            LogPath = ''
            Files = @()
        }
    }

    $backup = $null
    $configuration = Get-PwWorkshopConfig
    $backupEnabled = $configuration.Preferences.CreateBackupsBeforeDeployment

    if ($backupEnabled -and -not $SkipBackup -and $plan.UpdateCount -gt 0) {
        $backup = Backup-PwDeployment -Plan $plan -Confirm:$false
    }

    foreach ($file in $actionableFiles) {
        $destinationDirectory = Split-Path -Parent $file.DestinationPath

        if (-not (Test-Path -LiteralPath $destinationDirectory)) {
            New-Item `
                -ItemType Directory `
                -Path $destinationDirectory `
                -Force |
                Out-Null
        }

        Copy-Item `
            -LiteralPath $file.SourcePath `
            -Destination $file.DestinationPath `
            -Force
    }

    $result = [PSCustomObject]@{
        SchemaVersion = '1.0'
        Profile = $plan.Profile
        Applied = $true
        AppliedAt = Get-Date
        SourceRoot = $plan.SourceRoot
        DestinationRoot = $plan.DestinationRoot
        Backup = $backup
        Files = $actionableFiles
    }
    $logPath = Write-PwDeploymentLog -InputObject $result

    [PSCustomObject]@{
        Profile = $plan.Profile
        Applied = $true
        Reason = ''
        Backup = $backup
        LogPath = $logPath
        Files = $actionableFiles
    }
}
