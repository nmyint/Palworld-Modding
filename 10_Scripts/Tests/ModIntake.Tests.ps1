<#
.SYNOPSIS
    Verifies safe mod archive inspection, staging, validation, and promotion.
#>

Set-StrictMode -Version Latest

$moduleManifest = Join-Path $PSScriptRoot '..\Modules\PalworldModding.psd1'

Describe 'PalworldModding mod intake' {

    BeforeAll {
        Remove-Module PalworldModding -Force -ErrorAction SilentlyContinue
        Import-Module $moduleManifest -Force

        $global:PwIntakeRoot = Join-Path $TestDrive 'Workshop'
        $global:PwIntakePaths = [PSCustomObject]@{
            Root = $global:PwIntakeRoot
            Archives = Join-Path $global:PwIntakeRoot '01_Archives'
            Staging = Join-Path $global:PwIntakeRoot '02_Staging'
            ModLibrary = Join-Path $global:PwIntakeRoot '03_Mod_Library'
            Deployment = Join-Path $global:PwIntakeRoot '05_Deployment'
            CurrentInstallation = Join-Path `
                $global:PwIntakeRoot `
                '06_Current_Installation'
        }
        $global:PwGameRoot = Join-Path $TestDrive 'Game'

        foreach ($path in $global:PwIntakePaths.PSObject.Properties.Value) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }

        InModuleScope PalworldModding {
            Mock Get-PwPaths {
                $global:PwIntakePaths
            }

            Mock Get-PwDeployment {
                [PSCustomObject]@{
                    ActiveProfile = 'Stable'
                    GameInstallRoot = $global:PwGameRoot
                }
            }
        }

        $safeContent = Join-Path $TestDrive 'SafeContent'
        $pakRoot = Join-Path $safeContent 'Pal\Content\Paks\~mods'
        New-Item -ItemType Directory -Path $pakRoot -Force | Out-Null
        Set-Content `
            -LiteralPath (Join-Path $pakRoot 'WorkshopTest.pak') `
            -Value 'test pak content'
        Set-Content `
            -LiteralPath (Join-Path $safeContent 'README.txt') `
            -Value 'test documentation'
        $global:PwSafeArchive = Join-Path $TestDrive 'WorkshopTest-1.0.zip'
        [System.IO.Compression.ZipFile]::CreateFromDirectory(
            $safeContent,
            $global:PwSafeArchive
        )
        $global:PwSafe7ZipArchive = Join-Path $TestDrive 'WorkshopTest-1.0.7z'
        $previousLocation = Get-Location

        try {
            Set-Location -LiteralPath $safeContent
            & 'C:\Program Files\7-Zip\7z.exe' `
                a `
                -t7z `
                -mx=9 `
                -- `
                $global:PwSafe7ZipArchive `
                '.' |
                Out-Null

            if ($LASTEXITCODE -ne 0) {
                throw 'The test 7z archive could not be created.'
            }
        }
        finally {
            Set-Location -LiteralPath $previousLocation
        }

        $updatedContent = Join-Path $TestDrive 'UpdatedContent'
        $updatedPakRoot = Join-Path $updatedContent 'Pal\Content\Paks\~mods'
        New-Item -ItemType Directory -Path $updatedPakRoot -Force | Out-Null
        Set-Content `
            -LiteralPath (Join-Path $updatedPakRoot 'WorkshopTest.pak') `
            -Value 'conflicting pak content'
        $global:PwConflictArchive = Join-Path $TestDrive 'WorkshopTest-2.0.zip'
        [System.IO.Compression.ZipFile]::CreateFromDirectory(
            $updatedContent,
            $global:PwConflictArchive
        )

        $global:PwUnsafeArchive = Join-Path $TestDrive 'Unsafe.zip'
        $unsafeStream = [System.IO.File]::Create($global:PwUnsafeArchive)
        $unsafeZip = [System.IO.Compression.ZipArchive]::new(
            $unsafeStream,
            [System.IO.Compression.ZipArchiveMode]::Create
        )
        $unsafeEntry = $unsafeZip.CreateEntry('../escape.txt')
        $unsafeWriter = [System.IO.StreamWriter]::new($unsafeEntry.Open())
        $unsafeWriter.Write('unsafe')
        $unsafeWriter.Dispose()
        $unsafeZip.Dispose()
        $unsafeStream.Dispose()

        $global:PwUnsupportedArchive = Join-Path $TestDrive 'Unsupported.rar'
        Set-Content -LiteralPath $global:PwUnsupportedArchive -Value 'not a rar'
    }

    AfterAll {
        Remove-Variable PwIntakeRoot -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable PwIntakePaths -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable PwSafeArchive -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable PwSafe7ZipArchive `
            -Scope Global `
            -ErrorAction SilentlyContinue
        Remove-Variable PwConflictArchive -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable PwUnsafeArchive -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable PwUnsupportedArchive `
            -Scope Global `
            -ErrorAction SilentlyContinue
        Remove-Variable PwGameRoot -Scope Global -ErrorAction SilentlyContinue
    }

    It 'inspects a safe ZIP without extracting it' {
        $result = Get-PwModArchiveInfo -Path $global:PwSafeArchive

        $result.Supported | Should Be $true
        $result.IsSafe | Should Be $true
        $result.FileCount | Should Be 2
        @($result.Entries | Where-Object Category -eq 'Pak').Count |
            Should Be 1
        (
            $result.Entries |
                Where-Object Category -eq 'Pak' |
                Select-Object -ExpandProperty DeploymentRelativePath
        ) | Should Be 'Pal\Content\Paks\~mods\WorkshopTest.pak'
    }

    It 'rejects archive path traversal' {
        $result = Get-PwModArchiveInfo -Path $global:PwUnsafeArchive

        $result.IsSafe | Should Be $false
        @($result.Errors).Count | Should BeGreaterThan 0
    }

    It 'inspects a safe 7z archive without extracting it' {
        $result = Get-PwModArchiveInfo -Path $global:PwSafe7ZipArchive

        $result.Supported | Should Be $true
        $result.IsSafe | Should Be $true
        $result.Format | Should Be '7Z'
        $result.FileCount | Should Be 2
    }

    It 'reports unsupported archive formats clearly' {
        $result = Get-PwModArchiveInfo -Path $global:PwUnsupportedArchive

        $result.Supported | Should Be $false
        $result.Format | Should Be 'RAR'
    }

    It 'supports WhatIf when staging an archive' {
        $result = Import-PwModArchive `
            -Path $global:PwSafeArchive `
            -Name 'WorkshopTestWhatIf' `
            -Version '1.0' `
            -WhatIf

        $result.Staged | Should Be $false
        Test-Path -LiteralPath $result.PackageRoot | Should Be $false
    }

    It 'archives and stages a verified package' {
        $result = Import-PwModArchive `
            -Path $global:PwSafeArchive `
            -Name 'WorkshopTest' `
            -Version '1.0' `
            -Author 'Test Author' `
            -SourceUri 'https://example.invalid/mod' `
            -Confirm:$false

        $result.Staged | Should Be $true
        Test-Path -LiteralPath $result.OriginalArchive | Should Be $true
        Test-Path -LiteralPath $result.PackageArchive | Should Be $true
        (Test-PwModPackage -Name 'WorkshopTest' -Version '1.0').IsValid |
            Should Be $true
    }

    It 'archives and stages a verified 7z package' {
        $result = Import-PwModArchive `
            -Path $global:PwSafe7ZipArchive `
            -Name 'SevenZipTest' `
            -Version '1.0' `
            -Confirm:$false

        $result.Staged | Should Be $true
        $manifest = Get-Content -LiteralPath $result.ManifestPath -Raw |
            ConvertFrom-Json
        $manifest.OriginalFormat | Should Be '7Z'
        (Test-PwModPackage -Name 'SevenZipTest' -Version '1.0').IsValid |
            Should Be $true
    }

    It 'previews package promotion without writing to the library' {
        $plan = Publish-PwModPackage -Name 'WorkshopTest' -Version '1.0'

        $plan.CanPublish | Should Be $true
        $plan.ConflictCount | Should Be 0
        $plan.DeployableCount | Should Be 1
        Test-Path -LiteralPath $plan.LibraryRoot | Should Be $false
    }

    It 'publishes a package into the library and deployment output' {
        $result = Publish-PwModPackage `
            -Name 'WorkshopTest' `
            -Version '1.0' `
            -Apply `
            -Confirm:$false

        $result.Published | Should Be $true
        Test-Path -LiteralPath $result.LibraryRoot | Should Be $true
        Test-Path -LiteralPath $result.LibraryArchive | Should Be $true
        Test-Path -LiteralPath $result.DeploymentArchive | Should Be $true
        Test-Path -LiteralPath (
            Join-Path $result.LibraryRoot 'Source'
        ) | Should Be $false
        (
            Test-PwModPackage `
                -Name 'WorkshopTest' `
                -Version '1.0' `
                -Area ModLibrary
        ).IsValid | Should Be $true
        Test-Path -LiteralPath (
            Join-Path `
                $global:PwIntakePaths.Deployment `
                'Pal\Content\Paks\~mods\WorkshopTest.pak'
        ) | Should Be $true
    }

    It 'detects a conflicting deployment mapping' {
        Import-PwModArchive `
            -Path $global:PwConflictArchive `
            -Name 'WorkshopTest' `
            -Version '2.0' `
            -Confirm:$false |
            Out-Null

        $plan = Publish-PwModPackage -Name 'WorkshopTest' -Version '2.0'

        $plan.CanPublish | Should Be $false
        $plan.ConflictCount | Should Be 1
    }

    It 'rejects deployment mappings that escape the deployment root' {
        $staged = Import-PwModArchive `
            -Path $global:PwSafeArchive `
            -Name 'UnsafeMapping' `
            -Version '1.0' `
            -Confirm:$false
        $manifest = Get-Content -LiteralPath $staged.ManifestPath -Raw |
            ConvertFrom-Json
        $pakEntry = $manifest.Entries |
            Where-Object Category -eq 'Pak' |
            Select-Object -First 1
        $pakEntry.DeploymentRelativePath = '..\outside.pak'
        $manifest |
            ConvertTo-Json -Depth 10 |
            Set-Content -LiteralPath $staged.ManifestPath

        $result = Test-PwModPackage -Name 'UnsafeMapping' -Version '1.0'

        $result.IsValid | Should Be $false
        ($result.Errors -join ' ') | Should Match 'Unsafe deployment mapping'
    }

    It 'rejects files that are not recorded in the package manifest' {
        $sourceRoot = Join-Path (
            Join-Path $global:PwIntakePaths.Staging 'WorkshopTest\1.0'
        ) 'Source'
        Set-Content `
            -LiteralPath (Join-Path $sourceRoot 'Unexpected.txt') `
            -Value 'not in manifest'

        $result = Test-PwModPackage -Name 'WorkshopTest' -Version '1.0'

        $result.IsValid | Should Be $false
        ($result.Errors -join ' ') | Should Match 'unlisted file'
    }

    It 'records a known-good installation before cleaning temporary copies' {
        $deploymentPal = Join-Path $global:PwIntakePaths.Deployment 'Pal'
        $gamePal = Join-Path $global:PwGameRoot 'Pal'
        New-Item -ItemType Directory -Path $gamePal -Force | Out-Null
        Copy-Item `
            -Path (Join-Path $deploymentPal '*') `
            -Destination $gamePal `
            -Recurse `
            -Force

        $preview = Complete-PwModInstallation `
            -Name 'WorkshopTest' `
            -Version '1.0' `
            -GameValidated

        $preview.CanComplete | Should Be $true
        $preview.Applied | Should Be $false

        $result = Complete-PwModInstallation `
            -Name 'WorkshopTest' `
            -Version '1.0' `
            -GameValidated `
            -Notes 'Passed startup and load test.' `
            -Apply `
            -Confirm:$false

        $result.Applied | Should Be $true
        Test-Path -LiteralPath $result.RecordPath | Should Be $true
        Test-Path -LiteralPath $result.Cleanup.StagingRoot | Should Be $false
        Test-Path -LiteralPath $result.Cleanup.DeploymentArchive |
            Should Be $false
        Test-Path -LiteralPath (
            Join-Path `
                $global:PwIntakePaths.Deployment `
                'Pal\Content\Paks\~mods'
        ) | Should Be $true
        Test-Path -LiteralPath (
            Join-Path `
                $global:PwIntakePaths.ModLibrary `
                'WorkshopTest-1.0\package.7z'
        ) | Should Be $true

        $record = Get-Content -LiteralPath $result.RecordPath -Raw |
            ConvertFrom-Json
        $record.Status | Should Be 'KnownGood'
        $record.ValidatedInGame | Should Be $true
        $record.Files[0].Status | Should Be 'Verified'
    }
}
