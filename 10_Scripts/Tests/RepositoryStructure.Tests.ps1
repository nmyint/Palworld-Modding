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
