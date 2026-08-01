$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$exporterPath = Join-Path $repositoryRoot '10_Scripts\Utilities\Export-PwRepositoryStructure.ps1'
Describe 'Repository structure exporter' {
    It 'handles a directory containing exactly one included child under strict mode' {
        Set-StrictMode -Version Latest
        $fixtureRoot = Join-Path $TestDrive 'single-child-repository'
        $singleChildDirectory = Join-Path $fixtureRoot 'Docs'
        $outputFolder = Join-Path $TestDrive 'generated-output'
        New-Item -ItemType Directory -Path $singleChildDirectory -Force | Out-Null
        New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $singleChildDirectory 'Only.md') -Value '# Only child'
        Set-Content -LiteralPath (Join-Path $outputFolder 'RepositoryStructure.txt') -Value 'stale structure'
        Set-Content -LiteralPath (Join-Path $outputFolder 'RepositoryInventory.json') -Value '{"stale":true}'
        { & $exporterPath -Root $fixtureRoot -OutputFolder $outputFolder | Out-Null } | Should Not Throw
        $structurePath = Join-Path $outputFolder 'RepositoryStructure.txt'
        $inventoryPath = Join-Path $outputFolder 'RepositoryInventory.json'
        (Test-Path -LiteralPath $structurePath -PathType Leaf) | Should Be $true
        (Test-Path -LiteralPath $inventoryPath -PathType Leaf) | Should Be $true
        $structure = Get-Content -LiteralPath $structurePath -Raw
        ($structure -match 'Only.md') | Should Be $true
        ($structure -match 'stale structure') | Should Be $false
        $inventory = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json
        $docsDirectory = @($inventory.Structure | Where-Object { $_.Name -eq 'Docs' } | Select-Object -First 1)
        $docsDirectory.Count | Should Be 1
        @($docsDirectory[0].Children).Count | Should Be 1
        [string]$docsDirectory[0].Children[0].Name | Should Be 'Only.md'
        $temporaryArtifacts = @(Get-ChildItem -LiteralPath $outputFolder -Force -File | Where-Object {
            $_.Name -match '^\.Repository(Structure|Inventory)\..*\.(tmp|bak)$'
        })
        $temporaryArtifacts.Count | Should Be 0
    }
    It 'excludes ignored local cache state from generated maps' {
        $fixtureRoot = Join-Path $TestDrive 'cache-exclusion-repository'
        $cacheDirectory = Join-Path $fixtureRoot '.cache'
        $docsDirectory = Join-Path $fixtureRoot 'Docs'
        $outputFolder = Join-Path $TestDrive 'cache-exclusion-output'
        New-Item -ItemType Directory -Path $cacheDirectory -Force | Out-Null
        New-Item -ItemType Directory -Path $docsDirectory -Force | Out-Null
        New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $cacheDirectory 'NexusMetadata.json') -Value '{"local":true}'
        Set-Content -LiteralPath (Join-Path $docsDirectory 'Tracked.md') -Value '# Tracked'
        & $exporterPath -Root $fixtureRoot -OutputFolder $outputFolder | Out-Null
        $structure = Get-Content -LiteralPath (Join-Path $outputFolder 'RepositoryStructure.txt') -Raw
        $inventory = Get-Content -LiteralPath (Join-Path $outputFolder 'RepositoryInventory.json') -Raw | ConvertFrom-Json
        ($structure -match '(?m)^.*\.cache$') | Should Be $false
        ($structure -match 'NexusMetadata.json') | Should Be $false
        @($inventory.Structure | Where-Object Name -eq '.cache').Count | Should Be 0
        ($structure -match 'Tracked.md') | Should Be $true
    }
    It 'writes temporary outputs before replacing tracked files' {
        $source = Get-Content -LiteralPath $exporterPath -Raw
        (($source -match '\$TxtTemp') -and
            ($source -match '\$JsonTemp') -and
            ($source -match 'Move-Item -LiteralPath \$TxtTemp -Destination \$TxtOutput') -and
            ($source -match 'Move-Item -LiteralPath \$JsonTemp -Destination \$JsonOutput')) | Should Be $true
    }
}
Describe 'Repository structure documentation freshness' {
    It 'contains repository provenance metadata' {
        $path = Join-Path $PSScriptRoot '../../00_Documentation/RepositoryInventory.json'
        if (Test-Path $path) {
            $inventory = Get-Content $path -Raw | ConvertFrom-Json
            (-not [string]::IsNullOrWhiteSpace([string]$inventory.Metadata.CommitSHA)) | Should Be $true
        }
    }
    It 'contains module manifest in inventory output' {
        $path = Join-Path $PSScriptRoot '../../00_Documentation/RepositoryStructure.txt'
        if (Test-Path $path) {
            ((Get-Content $path -Raw) -match 'PalworldModding.psd1') | Should Be $true
        }
    }
}
