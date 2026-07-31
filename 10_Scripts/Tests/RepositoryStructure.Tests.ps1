Describe 'Repository structure documentation freshness' {
    It 'contains repository provenance metadata' {
        $path = Join-Path $PSScriptRoot '../../00_Documentation/RepositoryInventory.json'
        if (Test-Path $path) {
            $inventory = Get-Content $path -Raw | ConvertFrom-Json
            $inventory.Metadata.CommitSHA | Should Not BeNullOrEmpty
        }
    }
    It 'contains module manifest in inventory output' {
        $path = Join-Path $PSScriptRoot '../../00_Documentation/RepositoryStructure.txt'
        if (Test-Path $path) {
            (Get-Content $path -Raw) | Should Match 'PalworldModding.psd1'
        }
    }
}
