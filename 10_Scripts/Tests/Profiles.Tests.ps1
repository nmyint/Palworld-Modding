<#
.SYNOPSIS
    Verifies workshop profile management and deployment integration.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'
$workshopRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

Describe 'PalworldModding profiles' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'loads the Stable profile' {
        $profile = Get-PwProfile -Name 'Stable'

        $profile.SchemaVersion | Should Be '1.0'
        $profile.Name | Should Be 'Stable'
        $profile.Game.Platform | Should Be 'Steam'
    }

    It 'discovers the Stable profile' {
        $profileNames = Get-PwProfiles |
            Select-Object -ExpandProperty Name

        ($profileNames -contains 'Stable') | Should Be $true
    }

    It 'reports Stable as valid and locally ready' {
        $result = Test-PwProfile -Name 'Stable'

        $result.IsValid | Should Be $true
        $result.IsReady | Should Be $true
        @($result.Errors).Count | Should Be 0
        @($result.Warnings).Count | Should Be 0
    }

    It 'resolves deployment settings from the active profile' {
        $deployment = Get-PwDeployment

        $deployment.ActiveProfile | Should Be 'Stable'
        $deployment.TargetRoot | Should Be (
            Join-Path $workshopRoot '05_Deployment\Pal'
        )
        $deployment.GameInstallRoot | Should Be 'D:\Games\Palworld'
        $deployment.GameExecutable | Should Be (
            'D:\Games\Palworld\Pal\Binaries\Win64\Palworld-Win64-Shipping.exe'
        )
        $deployment.SavedRoot | Should Be (
            'C:\Users\noelm\AppData\Local\Pal\Saved'
        )
        $deployment.IsReady | Should Be $true
    }

    It 'supports WhatIf when creating a profile' {
        $profileName = 'Sprint32WhatIf'
        $profilePath = Join-Path $workshopRoot "16_Profiles\$profileName.json"

        New-PwProfile -Name $profileName -WhatIf | Out-Null

        Test-Path -LiteralPath $profilePath | Should Be $false
    }

    It 'rejects unsafe profile names' {
        $threw = $false

        try {
            Get-PwProfile -Name '..\Outside' | Out-Null
        }
        catch {
            $threw = $true
        }

        $threw | Should Be $true
    }

    It 'supports WhatIf when selecting the active profile' {
        $activeBefore = (Get-PwWorkshopConfig).Deployment.ActiveProfile

        Set-PwActiveProfile -Name 'Stable' -WhatIf | Out-Null

        (Get-PwWorkshopConfig).Deployment.ActiveProfile |
            Should Be $activeBefore
    }
}
