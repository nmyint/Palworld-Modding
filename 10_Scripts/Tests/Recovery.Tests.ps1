<#
.SYNOPSIS
    Verifies backup validation, restoration, inventory, history, and diagnostics.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding recovery and diagnostics' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force

        $global:PwRecoveryRoot = Join-Path $TestDrive 'Workshop'
        $global:PwRecoveryDestination = Join-Path $TestDrive 'Game\Pal'
        $global:PwRecoveryPaths = [PSCustomObject]@{
            Root = $global:PwRecoveryRoot
            Backups = Join-Path $global:PwRecoveryRoot '13_Backups'
            Logs = Join-Path $global:PwRecoveryRoot '09_Logs'
            CurrentInstallation = Join-Path `
                $global:PwRecoveryRoot `
                '06_Current_Installation'
        }
        $global:PwRecoveryBackup = Join-Path `
            $global:PwRecoveryPaths.Backups `
            'Deployments\20260729-Test'
        $relativePath = 'Content\Paks\~mods\RecoveryTest.pak'
        $backupFile = Join-Path (
            Join-Path $global:PwRecoveryBackup 'Pal'
        ) $relativePath
        $destinationFile = Join-Path `
            $global:PwRecoveryDestination `
            $relativePath

        New-Item `
            -ItemType Directory `
            -Path (Split-Path -Parent $backupFile) `
            -Force |
            Out-Null
        New-Item `
            -ItemType Directory `
            -Path (Split-Path -Parent $destinationFile) `
            -Force |
            Out-Null
        Set-Content -LiteralPath $backupFile -Value 'known good'
        Set-Content -LiteralPath $destinationFile -Value 'current broken state'
        $backupHash = (
            Get-FileHash -LiteralPath $backupFile -Algorithm SHA256
        ).Hash
        $destinationHash = (
            Get-FileHash -LiteralPath $destinationFile -Algorithm SHA256
        ).Hash
        $manifest = [PSCustomObject]@{
            SchemaVersion = '1.0'
            Profile = 'Test'
            CreatedAt = Get-Date
            SourceRoot = Join-Path $TestDrive 'Source'
            DestinationRoot = $global:PwRecoveryDestination
            Files = @(
                [PSCustomObject]@{
                    RelativePath = $relativePath
                    OriginalPath = $destinationFile
                    BackupPath = $backupFile
                    Hash = $backupHash
                }
            )
        }
        $manifest |
            ConvertTo-Json -Depth 10 |
            Set-Content -LiteralPath (
                Join-Path $global:PwRecoveryBackup 'manifest.json'
            )
        $global:PwRecoveryExpected = [PSCustomObject]@{
            RelativePath = $relativePath
            BackupFile = $backupFile
            BackupHash = $backupHash
            DestinationFile = $destinationFile
            DestinationHash = $destinationHash
        }

        InModuleScope PalworldModding {
            Mock Get-PwPaths {
                $global:PwRecoveryPaths
            }

            Mock Test-PwEnvironment {
                [PSCustomObject]@{
                    IsReady = $true
                }
            }
        }
    }

    AfterAll {
        Remove-Variable PwRecoveryRoot -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable `
            PwRecoveryDestination `
            -Scope Global `
            -ErrorAction SilentlyContinue
        Remove-Variable PwRecoveryPaths -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable PwRecoveryBackup -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable PwRecoveryExpected -Scope Global -ErrorAction SilentlyContinue
    }

    It 'validates a complete deployment backup and its hashes' {
        $result = Test-PwBackup -Path $global:PwRecoveryBackup

        $result.IsValid | Should Be $true
        @($result.Files).Count | Should Be 1
        $result.Files[0].Status | Should Be 'Verified'
    }

    It 'rejects a manifest containing path traversal' {
        $unsafeRoot = Join-Path $TestDrive 'UnsafeBackup'
        New-Item -ItemType Directory -Path $unsafeRoot -Force | Out-Null
        [PSCustomObject]@{
            SchemaVersion = '1.0'
            Profile = 'Test'
            CreatedAt = Get-Date
            DestinationRoot = $global:PwRecoveryDestination
            Files = @(
                [PSCustomObject]@{
                    RelativePath = '..\escape.pak'
                    Hash = 'BAD'
                }
            )
        } |
            ConvertTo-Json -Depth 10 |
            Set-Content -LiteralPath (Join-Path $unsafeRoot 'manifest.json')

        $result = Test-PwBackup -Path $unsafeRoot

        $result.IsValid | Should Be $false
        ($result.Errors -join ' ') | Should Match 'unsafe'
    }

    It 'previews restore actions without changing the target' {
        $plan = Restore-PwDeployment -Path $global:PwRecoveryBackup

        $plan.UpdateCount | Should Be 1
        $plan.CanRestore | Should Be $true
        (
            Get-FileHash `
                -LiteralPath $global:PwRecoveryExpected.DestinationFile
        ).Hash | Should Be $global:PwRecoveryExpected.DestinationHash
    }

    It 'restores verified files and preserves the pre-restore state' {
        $result = Restore-PwDeployment `
            -Path $global:PwRecoveryBackup `
            -Apply `
            -Confirm:$false

        $result.Applied | Should Be $true
        $result.Status | Should Be 'Succeeded'
        Test-Path -LiteralPath $result.SafetyBackup | Should Be $true
        Test-Path -LiteralPath $result.LogPath | Should Be $true
        (Test-PwBackup -Path $result.SafetyBackup).IsValid |
            Should Be $true
        (
            Get-FileHash `
                -LiteralPath $global:PwRecoveryExpected.DestinationFile
        ).Hash | Should Be $global:PwRecoveryExpected.BackupHash
    }

    It 'reads deployment and restore history records' {
        $deploymentRoot = Join-Path `
            $global:PwRecoveryPaths.Logs `
            'Deployments'
        New-Item -ItemType Directory -Path $deploymentRoot -Force | Out-Null
        [PSCustomObject]@{
            SchemaVersion = '1.0'
            Profile = 'Test'
            Status = 'Succeeded'
            AppliedAt = Get-Date
            Files = @()
        } |
            ConvertTo-Json -Depth 10 |
            Set-Content -LiteralPath (
                Join-Path $deploymentRoot 'deployment.json'
            )

        $history = @(Get-PwDeploymentHistory)

        @($history | Where-Object Type -eq 'Deployment').Count |
            Should Be 1
        @($history | Where-Object Type -eq 'Restore').Count |
            Should Be 1
    }

    It 'reports hash-verified known-good installation inventory' {
        $recordRoot = Join-Path `
            $global:PwRecoveryPaths.CurrentInstallation `
            'Mods\RecoveryTest'
        New-Item -ItemType Directory -Path $recordRoot -Force | Out-Null
        [PSCustomObject]@{
            SchemaVersion = '1.0'
            Name = 'RecoveryTest'
            Version = '1.0'
            Profile = 'Test'
            ValidatedAt = Get-Date
            Files = @(
                [PSCustomObject]@{
                    RelativePath = $global:PwRecoveryExpected.RelativePath
                    InstalledPath = $global:PwRecoveryExpected.DestinationFile
                    ExpectedHash = $global:PwRecoveryExpected.BackupHash
                }
            )
        } |
            ConvertTo-Json -Depth 10 |
            Set-Content -LiteralPath (Join-Path $recordRoot '1.0.json')

        $inventory = @(Get-PwInstallationInventory)

        $inventory.Count | Should Be 1
        $inventory[0].Status | Should Be 'Verified'
    }

    It 'combines backup, inventory, and history health diagnostics' {
        $result = Get-PwDiagnostics

        $result.BackupCount | Should Be 2
        $result.ValidBackupCount | Should Be 2
        $result.InventoryCount | Should Be 1
        $result.HistoryCount | Should Be 2
        $result.IsHealthy | Should Be $true
    }
}
