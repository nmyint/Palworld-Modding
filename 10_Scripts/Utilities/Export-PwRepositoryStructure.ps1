<#
.SYNOPSIS
    Exports a documentation-focused repository structure.
.DESCRIPTION
    Creates RepositoryStructure.txt and RepositoryInventory.json from one repository model.
#>
[CmdletBinding()]
param([string]$Root=(Get-Location).Path,[string]$DocumentationFolder='00_Documentation',[string]$OutputFolder)
$IncludeExtensions=@('.md','.txt','.json','.ps1','.psd1','.psm1','.ini','.yaml','.yml','.toml','.code-workspace')
$IgnoreExtensions=@('.zip','.7z','.rar','.pak','.dll','.exe','.bin')
$IgnoreDirectories=@('.git')
$TopLevelOnlyFolders=@('01_Archives','02_Staging','03_Mod_Library','04_Projects','05_Deployment','06_Current_Installation','07_Testing','08_Tools','09_Logs')
$RecursiveFolders=@('00_Documentation','10_Scripts','11_Utilities','12_Research','14_Templates','15_Sandbox','16_Profiles')
$Root=(Resolve-Path $Root).Path
if(!$OutputFolder){$OutputFolder=Join-Path $Root $DocumentationFolder}
if(!(Test-Path $OutputFolder)){New-Item -ItemType Directory -Path $OutputFolder|Out-Null}
$TxtOutput=Join-Path $OutputFolder 'RepositoryStructure.txt'
$JsonOutput=Join-Path $OutputFolder 'RepositoryInventory.json'
function Get-TraversalMode{param($Folder);if($TopLevelOnlyFolders -contains $Folder.Name){return 'TopLevelOnly'};return 'Recursive'}
function Get-RepositoryItems{param($Path);Get-ChildItem -LiteralPath $Path -Force|Where-Object{if($_.PSIsContainer -and $IgnoreDirectories -contains $_.Name){return $false};if($_.PSIsContainer){return $true};if($IgnoreExtensions -contains $_.Extension){return $false};return $IncludeExtensions -contains $_.Extension}|Sort-Object @{Expression={$_.PSIsContainer};Descending=$true},Name}
function New-RepositoryModel{param($Path);$Items=@();foreach($Item in Get-RepositoryItems $Path){if($Item.PSIsContainer){$mode=Get-TraversalMode $Item;$Items+=[PSCustomObject]@{Name=$Item.Name;Type='Directory';Traversal=$mode;Children=if($mode -eq 'Recursive'){@(New-RepositoryModel $Item.FullName)}else{@()}}}else{$Items+=[PSCustomObject]@{Name=$Item.Name;Type='File';Extension=$Item.Extension}}};return $Items}
function Get-Stats{param($Items);$dirs=0;$files=0;$docs=0;$ps=0;foreach($Item in $Items){if($Item.Type -eq 'Directory'){$dirs++;$child=Get-Stats $Item.Children;$dirs+=$child.Directories;$files+=$child.Files;$docs+=$child.Documents;$ps+=$child.PowerShellScripts}else{$files++;if($IncludeExtensions -contains $Item.Extension){$docs++};if($Item.Extension -in '.ps1','.psm1'){$ps++}}};return [PSCustomObject]@{Directories=$dirs;Files=$files;Documents=$docs;PowerShellScripts=$ps}}
function Write-Tree{param($Items,$Prefix='');foreach($Item in $Items){Add-Content -Path $TxtOutput -Value "$Prefix├── $($Item.Name)";if($Item.Type -eq 'Directory' -and $Item.Children.Count -gt 0){Write-Tree $Item.Children "$Prefix│   "}}}
$Model=@(New-RepositoryModel $Root)
$Statistics=Get-Stats $Model
$GitBranch=(git -C $Root branch --show-current 2>$null)
$GitCommit=(git -C $Root rev-parse HEAD 2>$null)
$Metadata=[PSCustomObject]@{Repository=Split-Path $Root -Leaf;Root='.';Branch=$GitBranch;CommitSHA=$GitCommit;Generated=(Get-Date)}
@('Palworld Modding Workshop Repository Structure',"Generated: $($Metadata.Generated)","Repository: $($Metadata.Repository)",'Root: .',"Branch: $($Metadata.Branch)","CommitSHA: $($Metadata.CommitSHA)",'')|Set-Content $TxtOutput
Add-Content $TxtOutput 'Statistics:'
Add-Content $TxtOutput "Directories: $($Statistics.Directories)"
Add-Content $TxtOutput "Files: $($Statistics.Files)"
Add-Content $TxtOutput "Documents: $($Statistics.Documents)"
Add-Content $TxtOutput "PowerShell Scripts: $($Statistics.PowerShellScripts)"
Add-Content $TxtOutput ''
Write-Tree $Model
[PSCustomObject]@{Metadata=$Metadata;Statistics=$Statistics;Structure=$Model}|ConvertTo-Json -Depth 50|Set-Content $JsonOutput
Write-Host 'Repository structure exported:'
Write-Host $TxtOutput
Write-Host $JsonOutput
