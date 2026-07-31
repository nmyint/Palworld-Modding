<#
.SYNOPSIS
    Exports a documentation-focused repository structure.
.DESCRIPTION
    Creates RepositoryStructure.txt and RepositoryInventory.json.
#>
[CmdletBinding()]
param(
    [string]$Root = (Get-Location).Path,
    [string]$DocumentationFolder = "00_Documentation",
    [string]$OutputFolder
)
$IncludeExtensions = @('.md','.txt','.json','.ps1','.psd1','.psm1','.ini','.yaml','.yml','.toml','.code-workspace')
$IgnoreExtensions = @('.zip','.7z','.rar','.pak','.dll','.exe','.bin')
$IgnoreDirectories = @('.git')
$TopLevelOnlyFolders = @('01_Archives','02_Staging','03_Mod_Library','04_Projects','05_Deployment','06_Current_Installation','07_Testing','08_Tools','09_Logs')
$RecursiveFolders = @('00_Documentation','10_Scripts','11_Utilities','12_Research','14_Templates','15_Sandbox','16_Profiles')
$Root = (Resolve-Path $Root).Path
if (!$OutputFolder) { $OutputFolder = Join-Path $Root $DocumentationFolder }
if (!(Test-Path $OutputFolder)) { New-Item -ItemType Directory -Path $OutputFolder | Out-Null }
$TxtOutput = Join-Path $OutputFolder 'RepositoryStructure.txt'
$JsonOutput = Join-Path $OutputFolder 'RepositoryInventory.json'
function Test-IgnoredDirectory { param($Item) return ($Item.PSIsContainer -and ($IgnoreDirectories -contains $Item.Name)) }
function Get-TraversalMode { param($Folder) if ($TopLevelOnlyFolders -contains $Folder.Name) { return 'TopLevelOnly' }; if ($RecursiveFolders -contains $Folder.Name) { return 'Recursive' }; return 'Recursive' }
function Get-RepositoryItems { param([string]$Path) Get-ChildItem -LiteralPath $Path -Force | Where-Object { if (Test-IgnoredDirectory $_) { return $false }; if ($_.PSIsContainer) { return $true }; if ($IgnoreExtensions -contains $_.Extension) { return $false }; return $IncludeExtensions -contains $_.Extension } | Sort-Object @{Expression={$_.PSIsContainer};Descending=$true},Name }
function Write-Tree { param([string]$Path,[string]$Prefix='') foreach ($Item in Get-RepositoryItems $Path) { Add-Content -Path $TxtOutput -Value "$Prefix├── $($Item.Name)"; if ($Item.PSIsContainer -and (Get-TraversalMode $Item) -eq 'Recursive') { Write-Tree $Item.FullName "$Prefix│   " } } }
function Get-Inventory { param([string]$Path) $Results=@(); foreach ($Item in Get-RepositoryItems $Path) { if ($Item.PSIsContainer) { $Results += [PSCustomObject]@{Name=$Item.Name;Type='Directory';Traversal=(Get-TraversalMode $Item);Children=@(if((Get-TraversalMode $Item)-eq 'Recursive'){Get-Inventory $Item.FullName})} } else { $Results += [PSCustomObject]@{Name=$Item.Name;Type='File';Extension=$Item.Extension} } }; return $Results }
@('Palworld Modding Workshop Repository Structure',"Generated: $(Get-Date)","Repository: $(Split-Path $Root -Leaf)",'Root: .','') | Set-Content $TxtOutput
Write-Tree $Root
[PSCustomObject]@{Repository=Split-Path $Root -Leaf;Generated=Get-Date;Root='.';Structure=@(Get-Inventory $Root)} | ConvertTo-Json -Depth 20 | Set-Content $JsonOutput
Write-Host 'Repository structure exported:'
Write-Host $TxtOutput
Write-Host $JsonOutput
