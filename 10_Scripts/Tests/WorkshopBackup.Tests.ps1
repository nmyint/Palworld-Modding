<#
.SYNOPSIS
    Verifies external workshop backup creation, exclusions, and retention.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding external workshop backup' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force

        $global:PwBackupTestRoot = Join-Path $TestDrive 'Workshop'
        $global:PwBackupDestination = Join-Path $TestDrive 'ExternalBackups'
        $global:PwBackupTestPaths = [PSCustomObject]@{
            Root = $global:PwBackupTestRoot
        }

        foreach ($path in @(
            '01_Archives',
            '02_Staging',
            '03_Mod_Library\Example-1.0',
            '10_Scripts',
            '13_Backups'
        )) {
            New-Item `
                -ItemType Directory `
                -Path (Join-Path $global:PwBackupTestRoot $path) `
                -Force |
                Out-Null
        }

        Set-Content `
            -LiteralPath (
                Join-Path $global:PwBackupTestRoot '01_Archives\Original.zip'
            ) `
            -Value 'original archive'
        Set-Content `
            -LiteralPath (
                Join-Path $global:PwBackupTestRoot '02_Staging\Temporary.txt'
            ) `
            -Value 'temporary'
        Set-Content `
            -LiteralPath (
                Join-Path `
                    $global:PwBackupTestRoot `
                    '03_Mod_Library\Example-1.0\package.7z'
            ) `
            -Value 'curated package'
        Set-Content `
            -LiteralPath (
                Join-Path $global:PwBackupTestRoot '10_Scripts\Workshop.ps1'
            ) `
            -Value 'Get-Date'
        Set-Content `
            -LiteralPath (
                Join-Path $global:PwBackupTestRoot '13_Backups\Recursive.7z'
            ) `
            -Value 'do not include'

        InModuleScope PalworldModding {
            Mock Get-PwPaths {
                $global:PwBackupTestPaths
            }
        }
    }

    AfterAll {
        Remove-Variable PwBackupTestRoot -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable `
            PwBackupDestination `
            -Scope Global `
            -ErrorAction SilentlyContinue
        Remove-Variable PwBackupTestPaths `
            -Scope Global `
            -ErrorAction SilentlyContinue
        Remove-Variable PwFirstWorkshopBackup `
            -Scope Global `
            -ErrorAction SilentlyContinue
    }

    It 'supports a non-mutating WhatIf preview' {
        $result = New-PwWorkshopBackup `
            -DestinationRoot $global:PwBackupDestination `
            -WhatIf

        $result.Created | Should Be $false
        Test-Path -LiteralPath $result.ArchivePath | Should Be $false
    }

    It 'backs up durable files and excludes disposable files' {
        $global:PwFirstWorkshopBackup = New-PwWorkshopBackup `
            -DestinationRoot $global:PwBackupDestination `
            -RetentionCount 2 `
            -Confirm:$false

        $global:PwFirstWorkshopBackup.Created | Should Be $true
        Test-Path `
            -LiteralPath $global:PwFirstWorkshopBackup.ArchivePath |
            Should Be $true
        Test-Path `
            -LiteralPath $global:PwFirstWorkshopBackup.MetadataPath |
            Should Be $true
        Test-Path `
            -LiteralPath $global:PwFirstWorkshopBackup.ChecksumPath |
            Should Be $true

        $listing = & 'C:\Program Files\7-Zip\7z.exe' `
            l `
            -slt `
            -ba `
            -- `
            $global:PwFirstWorkshopBackup.ArchivePath
        ($listing -join "`n") | Should Match '01_Archives'
        ($listing -join "`n") | Should Match '03_Mod_Library'
        ($listing -join "`n") | Should Match '10_Scripts'
        ($listing -join "`n") | Should Not Match '02_Staging'
        ($listing -join "`n") | Should Not Match '13_Backups'
    }

    It 'removes expired backup sets according to retention' {
        Start-Sleep -Milliseconds 20
        $result = New-PwWorkshopBackup `
            -DestinationRoot $global:PwBackupDestination `
            -RetentionCount 1 `
            -Confirm:$false

        $result.Created | Should Be $true
        Test-Path -LiteralPath $result.ArchivePath | Should Be $true
        Test-Path `
            -LiteralPath $global:PwFirstWorkshopBackup.ArchivePath |
            Should Be $false
        @($result.RemovedByRetention).Count | Should Be 3
    }
}
