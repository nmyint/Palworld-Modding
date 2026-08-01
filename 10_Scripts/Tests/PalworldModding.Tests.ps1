<#
.SYNOPSIS
    Verifies the PalworldModding module and workshop foundation.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'
$workshopRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

Describe 'PalworldModding module' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'has a valid module manifest' {
        { Test-ModuleManifest -Path $moduleManifest -ErrorAction Stop } |
            Should Not Throw
    }

    It 'reports the in-progress Sprint 4.5 module version' {
        Get-PwVersion | Should Be ([version]'0.4.9')
    }

    It 'exports the expected public commands' {
        $expectedCommands = @(
            'Get-PwContext'
            'Get-PwDeployment'
            'Get-PwDeploymentPlan'
            'Test-PwDeploymentReadiness'
            'Get-PwProfileAssemblyPlan'
            'Build-PwProfileDeployment'
            'Build-PwProfileExperiment'
            'Test-PwProfileDeploymentAssembly'
            'Get-PwModArchiveInfo'
            'Get-PwModCatalog'
            'Get-PwCompatibilityReport'
            'Get-PwStagingReconciliation'
            'Get-PwModCatalogSyncPlan'
            'Get-PwModUpdateReport'
            'Get-PwNexusCatalogMetadataReport'
            'Get-PwNexusModIdentity'
            'Get-PwNexusModFiles'
            'Get-PwCurrentGameOnlyMods'
            'Get-PwCurrentGameModAdoptionPlan'
            'Import-PwCurrentGameMod'
            'Get-PwModRemovalPlan'
            'Get-PwModUpgradePlan'
            'Get-PwGitHubSourcesFromText'
            'Get-PwSourceUpdateReport'
            'Get-PwUpdateSources'
            'Get-PwNexusApiIdentity'
            'Get-PwNexusArchiveMetadata'
            'Get-PwPaths'
            'Get-PwProfile'
            'Get-PwProfileModDownloadPlan'
            'Get-PwProfileModSetPreview'
            'Get-PwProfileModSets'
            'Get-PwProfiles'
            'Get-PwPersistentModCatalog'
            'Get-PwTool'
            'Get-PwTools'
            'Get-PwVersion'
            'Get-PwWorkshopConfig'
            'Get-PwWorkshopDashboard'
            'Get-PwWorkshopInfo'
            'Initialize-PwWorkshop'
            'Import-PwModArchive'
            'Invoke-PwDeployment'
            'New-PwProfile'
            'New-PwWorkshopBackup'
            'Open-PwNexusModPage'
            'Backup-PwDeployment'
            'Publish-PwModPackage'
            'Complete-PwModInstallation'
            'Get-PwDeploymentHistory'
            'Get-PwDiagnostics'
            'Get-PwInstallationInventory'
            'Get-PwRestorePlan'
            'Get-PwStagedModSnapshot'
            'Restore-PwDeployment'
            'Test-PwBackup'
            'Reset-PwContext'
            'Save-PwWorkshopConfig'
            'Save-PwNexusModUpdate'
            'Save-PwModUpdateFromReport'
            'Save-PwProfileModDownloads'
            'Set-PwActiveProfile'
            'Set-PwModCatalogMetadata'
            'New-PwModCatalogRecord'
            'Set-PwGitHubSourceBaseline'
            'Set-PwProfileModSet'
            'Start-PwWorkshop'
            'Test-PwEnvironment'
            'Test-PwModPackage'
            'Test-PwProfile'
            'Test-PwWorkshopConfig'
            'Update-PwModCatalog'
            'Update-PwNexusCatalogMetadata'
        )

        $actualCommands = Get-Command -Module PalworldModding |
            Select-Object -ExpandProperty Name |
            Sort-Object

        @($actualCommands).Count | Should Be $expectedCommands.Count

        foreach ($command in $expectedCommands) {
            ($actualCommands -contains $command) | Should Be $true
        }
    }

    It 'initializes a context for the repository workshop root' {
        Reset-PwContext
        $context = Initialize-PwWorkshop

        $context.WorkshopRoot | Should Be $workshopRoot
        $context.ConfigPath | Should Be (
            Join-Path $workshopRoot '.config\Workshop.json'
        )
        $context.Config.Workshop.Name | Should Be 'Palworld Modding Workshop'
        $context.Started | Should Not BeNullOrEmpty
    }

    It 'loads valid workshop configuration' {
        Test-PwWorkshopConfig | Should Be $true

        $configuration = Get-PwWorkshopConfig
        $configuration.SchemaVersion | Should Be '1.0'
        $configuration.Paths.Root | Should Be '.'
        $configuration.Git.DefaultBranch | Should Be 'main'
    }

    It 'returns detailed workshop configuration validation' {
        $result = Test-PwWorkshopConfig -Detailed

        $result.IsValid | Should Be $true
        @($result.Errors).Count | Should Be 0
        $result.Path | Should Be (
            Join-Path $workshopRoot '.config\Workshop.json'
        )
    }

    It 'resolves every configured workshop path beneath the root' {
        $paths = Get-PwPaths

        $paths.Root | Should Be $workshopRoot

        foreach ($property in $paths.PSObject.Properties) {
            if ($property.Name -eq 'Root') {
                continue
            }

            $property.Value.StartsWith(
                "$workshopRoot\",
                [System.StringComparison]::OrdinalIgnoreCase
            ) | Should Be $true
        }
    }

    It 'reports the local workshop environment as available' {
        $environment = Test-PwEnvironment

        $environment.WorkshopRootExists | Should Be $true
        $environment.ConfigExists | Should Be $true
        $environment.GitAvailable | Should Be $true
        $environment.PowerShellVersion.Major | Should BeGreaterThan 6
        $environment.ConfigValid | Should Be $true
        $environment.MeetsPowerShellRequirement | Should Be $true
        $environment.SevenZipAvailable | Should Be $true
        $environment.SevenZipPath | Should Be (
            'C:\Program Files\7-Zip\7z.exe'
        )
        @($environment.MissingPaths).Count | Should Be 0
        $environment.ModuleLoaded | Should Be $true
        $environment.IsReady | Should Be $true
    }

    It 'rejects structurally incomplete workshop configuration' {
        $result = Test-PwWorkshopConfig `
            -Configuration ([PSCustomObject]@{}) `
            -Detailed

        $result.IsValid | Should Be $false
        @($result.Errors).Count | Should BeGreaterThan 0
    }

    It 'refuses to save structurally incomplete configuration' {
        $threw = $false

        try {
            Save-PwWorkshopConfig `
                -Configuration ([PSCustomObject]@{}) `
                -WhatIf
        }
        catch {
            $threw = $true
        }

        $threw | Should Be $true
    }
}
