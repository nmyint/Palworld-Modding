<#
.SYNOPSIS
    Exports a documentation-focused repository structure.
.DESCRIPTION
    Creates RepositoryStructure.txt and RepositoryInventory.json.
    Root level directories are always listed. Child levels use exclusions.
#>

[CmdletBinding()]
param(
    [string]$Root = (Get-Location).Path,
    [string]$DocumentationFolder = "00_Documentation",
    [string]$OutputFolder
)

$IncludeExtensions = @('.md','.txt','.json','.ps1','.psm1','.ini','.yaml','.yml','.toml','.code-workspace')
$IgnoreExtensions = @('.zip','.7z','.rar','.pak','.dll','.exe','.bin')
$IgnoreFolders = @('.git','.github','.vscode','01_Archives','Archives','Mods','mods','Content','Binaries','06_Current_Installation','13_Backups','Logs','Temp')

$Root = (Resolve-Path $Root).Path
if (!$OutputFolder) { $OutputFolder = Join-Path $Root $DocumentationFolder }
if (!(Test-Path $OutputFolder)) { New-Item -ItemType Directory -Path $OutputFolder | Out-Null }

$TxtOutput = Join-Path $OutputFolder 'RepositoryStructure.txt'
$JsonOutput = Join-Path $OutputFolder 'RepositoryInventory.json'
Remove-Item $TxtOutput,$JsonOutput -Force -ErrorAction SilentlyContinue

function Test-IgnoreFolder {
    param($Folder)
    return $IgnoreFolders -contains $Folder.Name
}

function Get-RepositoryItems {
    param([string]$Path,[bool]$RootLevel=$false)
    Get-ChildItem -LiteralPath $Path -Force | Where-Object {
        if ($_.Name.StartsWith('.')) { return $false }
        if ($RootLevel -and $_.PSIsContainer) { return $true }
        if ($_.PSIsContainer) { return !(Test-IgnoreFolder $_) }
        if ($IgnoreExtensions -contains $_.Extension) { return $false }
        return $IncludeExtensions -contains $_.Extension
    } | Sort-Object @{Expression={$_.PSIsContainer};Descending=$true},Name
}

function Write-Tree {
    param([string]$Path,[string]$Prefix='',[bool]$RootLevel=$false)
    $Items = Get-RepositoryItems -Path $Path -RootLevel $RootLevel
    for ($i=0; $i -lt $Items.Count; $i++) {
        $Item = $Items[$i]
        if ($i -eq $Items.Count-1) { $Branch='└── '; $NewPrefix="$Prefix    " } else { $Branch='├── '; $NewPrefix="$Prefix│   " }
        Add-Content -Path $TxtOutput -Value "$Prefix$Branch$($Item.Name)"
        if ($Item.PSIsContainer) { Write-Tree -Path $Item.FullName -Prefix $NewPrefix }
    }
}

function Get-Inventory {
    param([string]$Path,[bool]$RootLevel=$false)
    $Results = @()
    foreach ($Item in Get-RepositoryItems -Path $Path -RootLevel $RootLevel) {
        if ($Item.PSIsContainer) {
            $Results += [PSCustomObject]@{ Name=$Item.Name; Type='Directory'; Children=@(Get-Inventory -Path $Item.FullName) }
        } else {
            $Results += [PSCustomObject]@{ Name=$Item.Name; Type='File'; Extension=$Item.Extension }
        }
    }
    return $Results
}

$Files = Get-ChildItem -Path $Root -Recurse -File -Force | Where-Object { !$_.FullName.Contains('\.git\') }
$Statistics = [PSCustomObject]@{
    Directories = (Get-ChildItem $Root -Recurse -Directory | Measure-Object).Count
    Documents = ($Files | Where-Object { $IncludeExtensions -contains $_.Extension } | Measure-Object).Count
    PowerShellScripts = ($Files | Where-Object { $_.Extension -in @('.ps1','.psm1') } | Measure-Object).Count
}

@("Palworld Modding Workshop Repository Structure","Generated: $(Get-Date)","Repository: $(Split-Path $Root -Leaf)","Root: $Root","","Statistics:","Directories: $($Statistics.Directories)","Documents: $($Statistics.Documents)","PowerShell Scripts: $($Statistics.PowerShellScripts)","") | Set-Content $TxtOutput
Add-Content -Path $TxtOutput -Value $Root
Write-Tree -Path $Root -RootLevel $true

[PSCustomObject]@{
    Repository = Split-Path $Root -Leaf
    Generated = Get-Date
    Root = $Root
    Statistics = $Statistics
    Structure = @(Get-Inventory -Path $Root -RootLevel $true)
} | ConvertTo-Json -Depth 20 | Set-Content $JsonOutput

Write-Host "Repository structure exported:"
Write-Host $TxtOutput
Write-Host $JsonOutput
