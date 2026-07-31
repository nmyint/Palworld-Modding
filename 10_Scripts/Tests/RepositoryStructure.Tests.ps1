$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$exporterPath = Join-Path $repositoryRoot '10_Scripts\Utilities\Export-PwRepositoryStructure.ps1'
Describe 'Repository structure exporter' {
    It 'handles a directory containing exactly one included child under strict mode' {
        Set-StrictMode -Version Latest
        $fixtureRoot = Join-Path $TestDrive 'single-child-repository'
        $singleChildDirectory = Join-Path $fixtureRoot 'Docs'
        $outputFolder = Join-Path $TestDrive 'generated-output'
        New-Item -ItemType Directory -Path $singleChildDirectory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $singleChildDirectory 'Only.md') -Value '# Only child'
        { & $exporterPath -Root $fixtureRoot -OutputFolder $outputFolder | Out-Null } | Should Not Throw
        $structurePath = Join-Path $outputFolder 'RepositoryStructure.txt'
        $inventoryPath = Join-Path $outputFolder 'RepositoryInventory.json'
        (Test-Path -LiteralPath $structurePath -PathType Leaf) | Should Be $true
        (Test-Path -LiteralPath $inventoryPath -PathType Leaf) | Should Be $true
        ((Get-Content -LiteralPath $structurePath -Raw) -match 'Only.md') | Should Be $true
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
