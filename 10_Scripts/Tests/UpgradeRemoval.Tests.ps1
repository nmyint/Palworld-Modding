<#
.SYNOPSIS
    Verifies preview-only upgrade and removal planning.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding upgrade and removal planning' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'builds a preview-only removal plan from a curated manifest' {
        $plan = Get-PwModRemovalPlan `
            -CatalogKey 'palminimap' `
            -ProfileName 'Stable'

        $plan.PlanType | Should Be 'Removal'
        $plan.PreviewOnly | Should Be $true
        $plan.Version | Should Be '1.2.5'
        $plan.FileCount | Should BeGreaterThan 0
        @($plan.Files | Where-Object RelativePath -match '^Pal[\\/]').Count |
            Should Be 0
    }

    It 'compares two manifest-backed versions without changing files' {
        $plan = Get-PwModUpgradePlan `
            -CatalogKey 'palminimap' `
            -CurrentVersion '1.2.5' `
            -CandidateVersion '1.2.5' `
            -ProfileName 'Stable'

        $plan.PlanType | Should Be 'Upgrade'
        $plan.PreviewOnly | Should Be $true
        $plan.UnchangedCount | Should Be $plan.FileCount
        $plan.CreateCount | Should Be 0
        $plan.UpdateCount | Should Be 0
        $plan.RemoveCount | Should Be 0
        $plan.BackupRequired | Should Be $false
    }
}
