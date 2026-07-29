<#
.SYNOPSIS
    Verifies workshop profile management and deployment integration.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'
$workshopRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$testProfileName = 'Sprint44ModSets'
$testProfilePath = Join-Path $workshopRoot "16_Profiles\$testProfileName.json"

Describe 'PalworldModding profiles' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force

        if (Test-Path -LiteralPath $testProfilePath) {
            Remove-Item -LiteralPath $testProfilePath -Force
        }

        $profile = Get-PwProfile -Name 'Stable' |
            ConvertTo-Json -Depth 20 |
            ConvertFrom-Json
        $profile.Name = $testProfileName
        $profile.Description = 'Sprint 4.4 test profile'

        if ($profile.PSObject.Properties.Name -contains 'ModSets') {
            $profile.ModSets = @()
        }
        else {
            $profile | Add-Member -NotePropertyName ModSets -NotePropertyValue @()
        }

        $profile |
            ConvertTo-Json -Depth 20 |
            Set-Content -LiteralPath $testProfilePath -Encoding utf8
    }

    AfterAll {
        if (Test-Path -LiteralPath $testProfilePath) {
            Remove-Item -LiteralPath $testProfilePath -Force
        }
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

    It 'stores and previews profile mod sets' {
        $catalogKeys = @(
            Get-PwPersistentModCatalog |
                Select-Object -ExpandProperty Mods |
                Select-Object -First 1 |
                Select-Object -ExpandProperty CatalogKey
        )

        $catalogKeys.Count | Should BeGreaterThan 0

        Set-PwProfileModSet `
            -Name $testProfileName `
            -SetName 'Core' `
            -Description 'Core gameplay and compatibility mods' `
            -CatalogKeys $catalogKeys `
            -Activate `
            -Confirm:$false | Out-Null

        $modSets = @(Get-PwProfileModSets -Name $testProfileName)
        $modSets.Count | Should Be 1
        $modSets[0].Name | Should Be 'Core'
        $modSets[0].IsActive | Should Be $true

        $preview = Get-PwProfileModSetPreview -Name $testProfileName
        $preview.Profile | Should Be $testProfileName
        $preview.ModSet | Should Be 'Core'
        $preview.ModCount | Should Be 1
        $preview.Mods[0].CatalogKey | Should Be $catalogKeys[0]
    }
}
