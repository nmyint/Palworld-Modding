<#
.SYNOPSIS
    Exports a documentation-focused repository structure.
.DESCRIPTION
    Creates RepositoryStructure.txt and RepositoryInventory.json.
    Root level directories are listed. Container folders can be top-level only or recursive.
#>

[CmdletBinding()]
param(
    [string]$Root = (Get-Location).Path,
    [string]$DocumentationFolder = "00_Documentation",
    [string]$OutputFolder
)

$IncludeExtensions = @('.md','.txt','.json','.ps1','.psm1','.ini','.yaml','.yml','.toml','.code-workspace')
$IgnoreExtensions = @('.zip','.7z','.rar','.pak','.dll','.exe','.bin')

$TopLevelOnlyFolders = @(
    '01_Archives','02_Staging','03_Mod_Library','04_Projects','05_Deployment',
    '06_Current_Installation','07_Testing','08_Tools','09_Logs'
)

$RecursiveFolders = @(
    '00_Documentation','10_Scripts','11_Utilities','12_Research',
    '14_Templates','15_Sandbox','16_Profiles'
)

$Root = (Resolve-Path $Root).Path
if (!$OutputFolder) { $OutputFolder = Join-Path $Root $DocumentationFolder }
if (!(Test-Path $OutputFolder)) { New-Item -ItemType Directory -Path $OutputFolder | Out-Null }

$TxtOutput = Join-Path $OutputFolder 'RepositoryStructure.txt'
$JsonOutput = Join-Path $OutputFolder 'RepositoryInventory.json'
Remove-Item $TxtOutput,$JsonOutput -Force -ErrorAction SilentlyContinue

function Get-TraversalMode {
    param($Folder)
    if ($TopLevelOnlyFolders -contains $Folder.Name) { return 'TopLevelOnly' }
    if ($RecursiveFolders -contains $Folder.Name) { return 'Recursive' }
    return 'Recursive'
}

function Get-RepositoryItems {
    param([string]$Path,[bool]$RootLevel=$false)
    Get-ChildItem -LiteralPath $Path -Force | Where-Object {
        if ($_.Name.StartsWith('.')) { return $false }
        if ($_.PSIsContainer) { return $true }
        if ($IgnoreExtensions -contains $_.Extension) { return $false }
        return $IncludeExtensions -contains $_.Extension
    } | Sort-Object @{Expression={$_.PSIsContainer};Descending=$true},Name
}

function Write-Tree {
    param([string]$Path,[string]$Prefix='',[bool]$RootLevel=$false)
    $Items = Get-RepositoryItems -Path $Path -RootLevel $RootLevel
    for ($i=0;$i -lt $Items.Count;$i++) {
        $Item=$Items[$i]
        if ($i -eq $Items.Count-1) { $Branch='└── '; $NewPrefix="$Prefix    " } else { $Branch='├── '; $NewPrefix="$Prefix│   " }
        Add-Content -Path $TxtOutput -Value "$Prefix$Branch$($Item.Name)"
        if ($Item.PSIsContainer) {
            if ((Get-TraversalMode $Item) -eq 'Recursive') {
                Write-Tree -Path $Item.FullName -Prefix $NewPrefix
            }
        }
    }
}

function Get-Inventory {
    param([string]$Path,[bool]$RootLevel=$false)
    $Results=@()
    foreach ($Item in Get-RepositoryItems -Path $Path -RootLevel $RootLevel) {
        if ($Item.PSIsContainer) {
            $Mode=Get-TraversalMode $Item
            $Results += [PSCustomObject]@{
                Name=$Item.Name
                Type='Directory'
                Traversal=$Mode
                Children=if ($Mode -eq 'Recursive') { @(Get-Inventory $Item.FullName) } else { @() }
            }
        } else {
            $Results += [PSCustomObject]@{Name=$Item.Name;Type='File';Extension=$Item.Extension}
        }
    }
    return $Results
}

$Files=Get-ChildItem -Path $Root -Recurse -File -Force
$Statistics=[PSCustomObject]@{
    Directories=(Get-ChildItem $Root -Recurse -Directory | Measure-Object).Count
    Documents=($Files | Where-Object {$IncludeExtensions -contains $_.Extension} | Measure-Object).Count
    PowerShellScripts=($Files | Where-Object {$_.Extension -in @('.ps1','.psm1')} | Measure-Object).Count
}

@(
'Palworld Modding Workshop Repository Structure',
"Generated: $(Get-Date)",
"Repository: $(Split-Path $Root -Leaf)",
"Root: $Root",
'',
'Statistics:',
"Directories: $($Statistics.Directories)",
"Documents: $($Statistics.Documents)",
"PowerShell Scripts: $($Statistics.PowerShellScripts)",
''
) | Set-Content $TxtOutput

Add-Content -Path $TxtOutput -Value $Root
Write-Tree -Path $Root -RootLevel $true

[PSCustomObject]@{
    Repository=Split-Path $Root -Leaf
    Generated=Get-Date
    Root=$Root
    Statistics=$Statistics
    Structure=@(Get-Inventory $Root $true)
} | ConvertTo-Json -Depth 20 | Set-Content $JsonOutput

Write-Host 'Repository structure exported:'
Write-Host $TxtOutput
Write-Host $JsonOutput
