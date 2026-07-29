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

    It 'reports the Sprint 3.3 module version' {
        Get-PwVersion | Should Be ([version]'0.3.3')
    }

    It 'exports the expected public commands' {
        $expectedCommands = @(
            'Get-PwContext'
            'Get-PwDeployment'
            'Get-PwDeploymentPlan'
            'Get-PwPaths'
            'Get-PwProfile'
            'Get-PwProfiles'
            'Get-PwTool'
            'Get-PwTools'
            'Get-PwVersion'
            'Get-PwWorkshopConfig'
            'Get-PwWorkshopInfo'
            'Initialize-PwWorkshop'
            'Invoke-PwDeployment'
            'New-PwProfile'
            'Backup-PwDeployment'
            'Reset-PwContext'
            'Save-PwWorkshopConfig'
            'Set-PwActiveProfile'
            'Test-PwEnvironment'
            'Test-PwProfile'
            'Test-PwWorkshopConfig'
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
        $configuration.Paths.Root | Should Be '.'
        $configuration.Git.DefaultBranch | Should Be 'main'
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
        $environment.ModuleLoaded | Should Be $true
    }
}
