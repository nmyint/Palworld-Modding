<#
.SYNOPSIS
    Palworld Modding Workshop PowerShell Module
.DESCRIPTION
    Loads workshop configuration, context, diagnostic, path, deployment, and tool
    commands and exports the supported public API.
#>

Set-StrictMode -Version Latest

# ============================================================
# Configuration
# ============================================================

. "$PSScriptRoot\..\Config\Json.ps1"
. "$PSScriptRoot\..\Config\WorkshopConfig.ps1"

# ============================================================
# Core
# ============================================================

. "$PSScriptRoot\..\Core\Bootstrap.ps1"

# ============================================================
# Commands
# ============================================================

. "$PSScriptRoot\..\Commands\WorkshopInfo.ps1"
. "$PSScriptRoot\..\Commands\Environment.ps1"
. "$PSScriptRoot\..\Commands\Paths.ps1"
. "$PSScriptRoot\..\Commands\Profiles.ps1"
. "$PSScriptRoot\..\Commands\Deployment.ps1"
. "$PSScriptRoot\..\Commands\DeploymentActions.ps1"
. "$PSScriptRoot\..\Commands\ModIntake.ps1"
. "$PSScriptRoot\..\Commands\ModCatalog.ps1"
. "$PSScriptRoot\..\Commands\PersistentCatalog.ps1"
. "$PSScriptRoot\..\Commands\StagingReconciliation.ps1"
. "$PSScriptRoot\..\Commands\NexusUpdates.ps1"
. "$PSScriptRoot\..\Commands\SourceUpdates.ps1"
. "$PSScriptRoot\..\Commands\CatalogMetadata.ps1"
. "$PSScriptRoot\..\Commands\Recovery.ps1"
. "$PSScriptRoot\..\Commands\WorkshopBackup.ps1"
. "$PSScriptRoot\..\Commands\WorkshopMenu.ps1"
. "$PSScriptRoot\..\Commands\Tools.ps1"

# ============================================================
# Module Exports
# ============================================================

Export-ModuleMember -Function @(

    # Core
    'Initialize-PwWorkshop',
    'Get-PwContext',
    'Reset-PwContext',

    # Configuration
    'Get-PwWorkshopConfig',
    'Save-PwWorkshopConfig',
    'Test-PwWorkshopConfig',

    # Workshop
    'Get-PwVersion',
    'Get-PwWorkshopInfo',

    # Environment
    'Test-PwEnvironment',

    # Paths
    'Get-PwPaths',

    # Profiles
    'Get-PwProfile',
    'Get-PwProfiles',
    'Get-PwProfileModSets',
    'Get-PwProfileModSetPreview',
    'New-PwProfile',
    'Set-PwProfileModSet',
    'Test-PwProfile',
    'Set-PwActiveProfile',

    # Deployment
    'Get-PwDeployment',
    'Get-PwDeploymentPlan',
    'Backup-PwDeployment',
    'Invoke-PwDeployment',

    # Mod intake
    'Get-PwModArchiveInfo',
    'Import-PwModArchive',
    'Test-PwModPackage',
    'Publish-PwModPackage',
    'Complete-PwModInstallation',

    # Mod catalog
    'Get-PwNexusArchiveMetadata',
    'Get-PwStagedModSnapshot',
    'Get-PwModCatalog',
    'Get-PwPersistentModCatalog',
    'Get-PwModCatalogSyncPlan',
    'Update-PwModCatalog',
    'Set-PwModCatalogMetadata',
    'Get-PwStagingReconciliation',
    'Get-PwCompatibilityReport',
    'Get-PwNexusApiIdentity',
    'Get-PwModUpdateReport',
    'Open-PwNexusModPage',
    'Save-PwNexusModUpdate',
    'Get-PwUpdateSources',
    'Get-PwSourceUpdateReport',
    'Set-PwGitHubSourceBaseline',
    'Get-PwNexusCatalogMetadataReport',
    'Get-PwNexusModIdentity',
    'Get-PwGitHubSourcesFromText',
    'Update-PwNexusCatalogMetadata',

    # Recovery and diagnostics
    'Test-PwBackup',
    'Get-PwRestorePlan',
    'Restore-PwDeployment',
    'Get-PwDeploymentHistory',
    'Get-PwInstallationInventory',
    'Get-PwDiagnostics',

    # External workshop backup
    'New-PwWorkshopBackup',

    # Interactive interface
    'Start-PwWorkshop',

    # Tools
    'Get-PwTool',
    'Get-PwTools'

)
