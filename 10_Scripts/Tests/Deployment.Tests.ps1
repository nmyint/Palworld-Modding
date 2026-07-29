<#
.SYNOPSIS
    Verifies safe deployment planning, backup, and apply behavior.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding deployment' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force
    }

    It 'reports the Stable installation as deployable' {
        $deployment = Get-PwDeployment

        $deployment.ActiveProfile | Should Be 'Stable'
        $deployment.CanDeploy | Should Be $true
    }

    It 'ignores placeholder files in the workshop deployment output' {
        $plan = Get-PwDeploymentPlan

        @(
            $plan.Files |
                Where-Object RelativePath -match '(^|[\\/])\.gitkeep$'
        ).Count | Should Be 0
    }

    It 'returns a preview without applying changes by default' {
        $plan = Invoke-PwDeployment

        $plan.PSObject.Properties.Name -contains 'Applied' |
            Should Be $false
        @($plan.Files).Count | Should BeGreaterThan -1
    }

    It 'reports PalSchema requirements and expected destinations' {
        InModuleScope PalworldModding {
            $assembly = [PSCustomObject]@{
                Manifest = [PSCustomObject]@{
                    Packages = @(
                        [PSCustomObject]@{
                            CatalogKey = 'hybridmod'
                            ExpectedDestinations = @(
                                [PSCustomObject]@{
                                    Framework = 'PalSchema'
                                    Root = (
                                        'Pal\Binaries\Win64\ue4ss\Mods\' +
                                            'PalSchema\mods'
                                    )
                                    PayloadNames = @('SchemaPayload')
                                    FileCount = 1
                                }
                            )
                        }
                    )
                }
                Files = @(
                    [PSCustomObject]@{
                        CatalogKey = 'hybridmod'
                        RelativePath = (
                            'Pal\Binaries\Win64\ue4ss\Mods\PalSchema\' +
                                'mods\SchemaPayload\raw\data.json'
                        )
                    }
                )
            }
            $plan = [PSCustomObject]@{
                DestinationRoot = $TestDrive
                Files = @(
                    [PSCustomObject]@{
                        RelativePath = (
                            'Binaries\Win64\ue4ss\Mods\PalSchema\' +
                                'dlls\main.dll'
                        )
                    }
                )
            }

            $notices = @(
                Get-PwDeploymentRequirementNotices `
                    -Assembly $assembly `
                    -Plan $plan
            )

            $notices.Count | Should Be 1
            $notices[0].Requirement | Should Be 'PalSchema'
            $notices[0].RequirementPresent | Should Be $true
            $notices[0].DestinationVerified | Should Be $true
            $notices[0].ManualReviewRecommended | Should Be $false

            $plan.Files = @()
            $missingRequirement = @(
                Get-PwDeploymentRequirementNotices `
                    -Assembly $assembly `
                    -Plan $plan
            )
            $missingRequirement[0].Severity | Should Be 'Warning'
            $missingRequirement[0].ManualReviewRecommended | Should Be $true
        }
    }

    Context 'with isolated deployment fixtures' {

        BeforeAll {
            $global:PwTestSource = Join-Path $TestDrive 'Source'
            $global:PwTestDestination = Join-Path $TestDrive 'Destination'
            $global:PwTestBackupRoot = Join-Path $TestDrive 'Backups'
            $global:PwTestLogPath = Join-Path $TestDrive 'deployment-log.json'

            New-Item -ItemType Directory -Path $global:PwTestSource -Force |
                Out-Null
            New-Item -ItemType Directory -Path $global:PwTestDestination -Force |
                Out-Null

            Set-Content `
                -LiteralPath (Join-Path $global:PwTestSource 'Create.txt') `
                -Value 'new file'
            Set-Content `
                -LiteralPath (Join-Path $global:PwTestSource 'Update.txt') `
                -Value 'new content'
            Set-Content `
                -LiteralPath (Join-Path $global:PwTestSource 'Same.txt') `
                -Value 'same content'
            Set-Content `
                -LiteralPath (Join-Path $global:PwTestSource '.gitkeep') `
                -Value ''

            Set-Content `
                -LiteralPath (Join-Path $global:PwTestDestination 'Update.txt') `
                -Value 'old content'
            Set-Content `
                -LiteralPath (Join-Path $global:PwTestDestination 'Same.txt') `
                -Value 'same content'

            InModuleScope PalworldModding {
                $global:PwTestPlan = New-PwDeploymentPlan `
                    -ProfileName 'Test' `
                    -SourceRoot $global:PwTestSource `
                    -DestinationRoot $global:PwTestDestination
            }
        }

        AfterAll {
            Remove-Variable PwTestSource -Scope Global -ErrorAction SilentlyContinue
            Remove-Variable PwTestDestination `
                -Scope Global `
                -ErrorAction SilentlyContinue
            Remove-Variable PwTestBackupRoot `
                -Scope Global `
                -ErrorAction SilentlyContinue
            Remove-Variable PwTestLogPath `
                -Scope Global `
                -ErrorAction SilentlyContinue
            Remove-Variable PwTestPlan -Scope Global -ErrorAction SilentlyContinue
            Remove-Variable PwTestBackup -Scope Global -ErrorAction SilentlyContinue
            Remove-Variable PwTestResult -Scope Global -ErrorAction SilentlyContinue
            Remove-Variable PwStalePlan -Scope Global -ErrorAction SilentlyContinue
            Remove-Variable PwStaleSource -Scope Global -ErrorAction SilentlyContinue
            Remove-Variable PwStaleDestination `
                -Scope Global `
                -ErrorAction SilentlyContinue
        }

        It 'classifies create, update, and unchanged files by hash' {
            $global:PwTestPlan.CreateCount | Should Be 1
            $global:PwTestPlan.UpdateCount | Should Be 1
            $global:PwTestPlan.UnchangedCount | Should Be 1
            @($global:PwTestPlan.Files).Count | Should Be 3
        }

        It 'backs up only files that will be overwritten' {
            $global:PwTestBackup = Backup-PwDeployment `
                -Plan $global:PwTestPlan `
                -BackupRoot $global:PwTestBackupRoot `
                -Confirm:$false

            $global:PwTestBackup.Created | Should Be $true
            @($global:PwTestBackup.Files).Count | Should Be 1
            Test-Path -LiteralPath $global:PwTestBackup.ManifestPath |
                Should Be $true
            Get-Content -LiteralPath $global:PwTestBackup.Files[0].BackupPath |
                Should Be 'old content'
        }

        It 'applies only planned create and update actions when explicitly approved' {
            InModuleScope PalworldModding {
                Mock Get-PwDeploymentPlan {
                    $global:PwTestPlan
                }
                Mock Write-PwDeploymentLog {
                    $global:PwTestLogPath
                }
                Mock Test-PwDeploymentReadiness {
                    [PSCustomObject]@{
                        ReadyToDeploy = $true
                        Errors = @()
                    }
                }

                $global:PwTestResult = Invoke-PwDeployment `
                    -Apply `
                    -SkipBackup `
                    -Confirm:$false
            }

            $global:PwTestResult.Applied | Should Be $true
            @($global:PwTestResult.Files).Count | Should Be 2
            $global:PwTestResult.Status | Should Be 'Succeeded'
            $global:PwTestResult.Files[0].VerifiedHash |
                Should Not BeNullOrEmpty
            Get-Content `
                -LiteralPath (
                    Join-Path $global:PwTestDestination 'Create.txt'
                ) |
                Should Be 'new file'
            Get-Content `
                -LiteralPath (
                    Join-Path $global:PwTestDestination 'Update.txt'
                ) |
                Should Be 'new content'
        }

        It 'rejects a deployment plan when a source changes before apply' {
            $global:PwStaleSource = Join-Path $TestDrive 'StaleSource'
            $global:PwStaleDestination = Join-Path $TestDrive 'StaleDestination'
            New-Item `
                -ItemType Directory `
                -Path $global:PwStaleSource `
                -Force |
                Out-Null
            New-Item `
                -ItemType Directory `
                -Path $global:PwStaleDestination `
                -Force |
                Out-Null
            $staleFile = Join-Path $global:PwStaleSource 'Changed.txt'
            Set-Content -LiteralPath $staleFile -Value 'planned content'

            InModuleScope PalworldModding {
                $global:PwStalePlan = New-PwDeploymentPlan `
                    -ProfileName 'Test' `
                    -SourceRoot $global:PwStaleSource `
                    -DestinationRoot $global:PwStaleDestination
            }

            Set-Content -LiteralPath $staleFile -Value 'changed after planning'
            (Get-FileHash -LiteralPath $staleFile).Hash |
                Should Not Be $global:PwStalePlan.Files[0].SourceHash

            InModuleScope PalworldModding {
                $threw = $false

                try {
                    Assert-PwDeploymentFileState `
                        -File $global:PwStalePlan.Files[0]
                }
                catch {
                    $threw = $true
                }

                $threw | Should Be $true
            }

            Test-Path -LiteralPath (
                Join-Path $global:PwStaleDestination 'Changed.txt'
            ) | Should Be $false
        }
    }
}
