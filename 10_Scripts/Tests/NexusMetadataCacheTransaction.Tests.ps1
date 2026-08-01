<#
.SYNOPSIS
    Verifies atomic Nexus metadata cache preview behavior.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding Nexus metadata cache transaction safety' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'does not create cache directories or temporary files during WhatIf' {
        InModuleScope PalworldModding {
            $cacheRoot = Join-Path $TestDrive 'cache'
            $cachePath = Join-Path $cacheRoot 'NexusMetadata.json'
            $cache = New-PwEmptyNexusMetadataCache

            {
                Write-PwNexusMetadataCache `
                    -Cache $cache `
                    -Path $cachePath `
                    -WhatIf
            } | Should Not Throw

            Test-Path -LiteralPath $cacheRoot | Should Be $false
            Test-Path -LiteralPath $cachePath | Should Be $false
            @(
                Get-ChildItem `
                    -LiteralPath $TestDrive `
                    -Recurse `
                    -Force `
                    -ErrorAction SilentlyContinue |
                    Where-Object Name -Like '.NexusMetadata-*.tmp'
            ).Count | Should Be 0
        }
    }
}
