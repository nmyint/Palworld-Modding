<#
.SYNOPSIS
    Verifies offline Nexus filename, staging, catalog, and menu discovery.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding mod catalog' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force

        $global:PwCatalogRoot = Join-Path $TestDrive 'Workshop'
        $global:PwCatalogPaths = [PSCustomObject]@{
            Root = $global:PwCatalogRoot
            Archives = Join-Path $global:PwCatalogRoot '01_Archives'
            Staging = Join-Path $global:PwCatalogRoot '02_Staging'
        }
        New-Item `
            -ItemType Directory `
            -Path $global:PwCatalogPaths.Archives `
            -Force |
            Out-Null
        New-Item `
            -ItemType Directory `
            -Path $global:PwCatalogPaths.Staging `
            -Force |
            Out-Null

        $archiveContent = Join-Path $TestDrive 'ArchiveContent'
        $archiveModRoot = Join-Path $archiveContent 'ExampleInstall\Scripts'
        New-Item -ItemType Directory -Path $archiveModRoot -Force |
            Out-Null
        Set-Content `
            -LiteralPath (Join-Path $archiveModRoot 'main.lua') `
            -Value 'print("catalog fixture")'
        $global:PwCatalogArchive = Join-Path `
            $global:PwCatalogPaths.Archives `
            'Example Mod 1234 1.2.3 2026-07-28T08-43Z AbCd1234.zip'
        [System.IO.Compression.ZipFile]::CreateFromDirectory(
            $archiveContent,
            $global:PwCatalogArchive
        )

        $trickyContent = Join-Path $TestDrive 'TrickyContent'
        New-Item -ItemType Directory -Path $trickyContent -Force |
            Out-Null
        Set-Content `
            -LiteralPath (Join-Path $trickyContent 'README.txt') `
            -Value 'fixture'
        $global:PwCatalogTrickyArchive = Join-Path `
            $global:PwCatalogPaths.Archives `
            (
                'BuildFlight v0.10.4 Public Beta 5 4144 0.10.4 ' +
                    '2026-07-27T19-23Z ZdSPKTjlO.zip'
            )
        [System.IO.Compression.ZipFile]::CreateFromDirectory(
            $trickyContent,
            $global:PwCatalogTrickyArchive
        )

        $stagedMod = Join-Path `
            $global:PwCatalogPaths.Staging `
            'ExampleInstall\Scripts'
        $orphanMod = Join-Path `
            $global:PwCatalogPaths.Staging `
            'OrphanMod\Scripts'
        New-Item -ItemType Directory -Path $stagedMod -Force | Out-Null
        New-Item -ItemType Directory -Path $orphanMod -Force | Out-Null
        Set-Content `
            -LiteralPath (Join-Path $stagedMod 'main.lua') `
            -Value 'print("catalog fixture")'
        Set-Content `
            -LiteralPath (
                Join-Path `
                    $global:PwCatalogPaths.Staging `
                    'ExampleInstall\enabled.txt'
            ) `
            -Value ''
        Set-Content `
            -LiteralPath (Join-Path $orphanMod 'main.lua') `
            -Value 'print("orphan")'
        Set-Content `
            -LiteralPath (
                Join-Path $global:PwCatalogPaths.Staging 'mods.txt'
            ) `
            -Value 'OrphanMod : 0'
        Set-Content `
            -LiteralPath (
                Join-Path $global:PwCatalogPaths.Staging 'mods.json'
            ) `
            -Value '[{"broken": true}'

        InModuleScope PalworldModding {
            Mock Get-PwPaths {
                $global:PwCatalogPaths
            }

            Mock Initialize-PwWorkshop {
                [PSCustomObject]@{
                    Initialized = $true
                }
            }
        }
    }

    AfterAll {
        Remove-Variable PwCatalogRoot -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable PwCatalogPaths -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable PwCatalogArchive -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable `
            PwCatalogTrickyArchive `
            -Scope Global `
            -ErrorAction SilentlyContinue
    }

    It 'parses Nexus metadata fields from the right side of filenames' {
        $result = Get-PwNexusArchiveMetadata `
            -Path $global:PwCatalogTrickyArchive `
            -SkipContentInspection

        $result.IsParsed | Should Be $true
        $result.Name | Should Be 'BuildFlight v0.10.4 Public Beta 5'
        $result.NexusModId | Should Be 4144
        $result.ArchiveVersion | Should Be '0.10.4'
        $result.DownloadToken | Should Be 'ZdSPKTjlO'
        $result.NexusUrl | Should Be (
            'https://www.nexusmods.com/palworld/mods/4144'
        )
    }

    It 'discovers install names from safe archive contents' {
        $result = Get-PwNexusArchiveMetadata `
            -Path $global:PwCatalogArchive

        $result.IsSafe | Should Be $true
        @($result.InstallNames) -contains 'ExampleInstall' | Should Be $true
        @($result.Categories) -contains 'Lua' | Should Be $true
    }

    It 'inventories marker and legacy enablement without writing files' {
        $beforeHash = (
            Get-FileHash `
                -LiteralPath (
                    Join-Path $global:PwCatalogPaths.Staging 'mods.txt'
                )
        ).Hash
        $result = @(Get-PwStagedModSnapshot)

        $result.Count | Should Be 2
        (
            $result |
                Where-Object Name -eq 'ExampleInstall'
        ).Enabled | Should Be $true
        (
            $result |
                Where-Object Name -eq 'OrphanMod'
        ).Enabled | Should Be $false
        (
            Get-FileHash `
                -LiteralPath (
                    Join-Path $global:PwCatalogPaths.Staging 'mods.txt'
                )
        ).Hash | Should Be $beforeHash
    }

    It 'matches archives by internal install name and reports anomalies' {
        $result = Get-PwModCatalog
        $matched = $result.Mods |
            Where-Object Name -eq 'ExampleInstall'
        $orphan = $result.Mods |
            Where-Object Name -eq 'OrphanMod'

        $result.ModCount | Should Be 2
        $matched.ArchiveMatchStatus | Should Be 'Matched'
        $matched.LatestCandidateVersion | Should Be '1.2.3'
        $orphan.ArchiveMatchStatus | Should Be 'MissingArchive'
        $result.ModsJsonValid | Should Be $false
        ($result.Warnings -join ' ') | Should Match 'malformed JSON'
    }

    It 'exposes catalog discovery through the one-command menu API' {
        $result = Start-PwWorkshop -Action Catalog

        $result.ModCount | Should Be 2
        $result.ArchiveCount | Should Be 2
    }

    It 'renders the main menu responsively within terminal dimensions' {
        InModuleScope PalworldModding {
            $compactLayout = @(
                Get-PwWorkshopMenuLayout `
                    -Profile 'Stable' `
                    -EnvironmentStatus 'Ready' `
                    -Width 48 `
                    -Height 18
            )
            $wideLayout = @(
                Get-PwWorkshopMenuLayout `
                    -Profile 'Testing' `
                    -EnvironmentStatus 'Needs attention' `
                    -Width 110 `
                    -Height 32
            )

            $compactLayout.Count | Should Be 16
            $wideLayout.Count | Should Be 30

            foreach ($line in $compactLayout) {
                $line.Text.Length | Should Be 48
            }

            foreach ($line in $wideLayout) {
                $line.Text.Length | Should Be 110
            }
        }
    }
}
