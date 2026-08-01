<#
.SYNOPSIS
    Exports a documentation-focused repository structure.
.DESCRIPTION
    Creates RepositoryStructure.txt and RepositoryInventory.json from one repository model.
#>
[CmdletBinding()]
param(
    [string]$Root = (Get-Location).Path,
    [string]$DocumentationFolder = '00_Documentation',
    [string]$OutputFolder
)
$IncludeExtensions = @('.md', '.txt', '.json', '.ps1', '.psd1', '.psm1', '.ini', '.yaml', '.yml', '.toml', '.code-workspace')
$IgnoreExtensions = @('.zip', '.7z', '.rar', '.pak', '.dll', '.exe', '.bin')
$IgnoreDirectories = @('.git', '.cache')
$TopLevelOnlyFolders = @('01_Archives', '02_Staging', '03_Mod_Library', '04_Projects', '05_Deployment', '06_Current_Installation', '07_Testing', '08_Tools', '09_Logs')
$RecursiveFolders = @('00_Documentation', '10_Scripts', '11_Utilities', '12_Research', '14_Templates', '15_Sandbox', '16_Profiles')
$Root = (Resolve-Path -LiteralPath $Root).Path
if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
    $OutputFolder = Join-Path $Root $DocumentationFolder
}
if (-not (Test-Path -LiteralPath $OutputFolder -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}
$TxtOutput = Join-Path $OutputFolder 'RepositoryStructure.txt'
$JsonOutput = Join-Path $OutputFolder 'RepositoryInventory.json'
$tempSuffix = [guid]::NewGuid().ToString('N')
$TxtTemp = Join-Path $OutputFolder ".RepositoryStructure.$tempSuffix.tmp"
$JsonTemp = Join-Path $OutputFolder ".RepositoryInventory.$tempSuffix.tmp"
$TxtBackup = Join-Path $OutputFolder ".RepositoryStructure.$tempSuffix.bak"
$JsonBackup = Join-Path $OutputFolder ".RepositoryInventory.$tempSuffix.bak"
$txtExisted = Test-Path -LiteralPath $TxtOutput -PathType Leaf
$jsonExisted = Test-Path -LiteralPath $JsonOutput -PathType Leaf
function Get-TraversalMode {
    param($Folder)
    if ($TopLevelOnlyFolders -contains $Folder.Name) {
        return 'TopLevelOnly'
    }
    return 'Recursive'
}
function Get-RepositoryItems {
    param([string]$Path)
    Get-ChildItem -LiteralPath $Path -Force | Where-Object {
        if ($_.PSIsContainer -and $IgnoreDirectories -contains $_.Name) {
            return $false
        }
        if ($_.PSIsContainer) {
            return $true
        }
        if ($IgnoreExtensions -contains $_.Extension) {
            return $false
        }
        return $IncludeExtensions -contains $_.Extension
    } | Sort-Object @{ Expression = { $_.PSIsContainer }; Descending = $true }, Name
}
function New-RepositoryModel {
    param([string]$Path)
    $items = @()
    foreach ($item in @(Get-RepositoryItems -Path $Path)) {
        if ($item.PSIsContainer) {
            $mode = Get-TraversalMode -Folder $item
            $children = if ($mode -eq 'Recursive') {
                @(New-RepositoryModel -Path $item.FullName)
            }
            else {
                @()
            }
            $items += [pscustomobject]@{
                Name = $item.Name
                Type = 'Directory'
                Traversal = $mode
                Children = @($children)
            }
            continue
        }
        $items += [pscustomobject]@{
            Name = $item.Name
            Type = 'File'
            Extension = $item.Extension
        }
    }
    return @($items)
}
function Get-Stats {
    param($Items)
    $directories = 0
    $files = 0
    $documents = 0
    $powerShellScripts = 0
    foreach ($item in @($Items)) {
        if ($item.Type -eq 'Directory') {
            $directories++
            $childStats = Get-Stats -Items @($item.Children)
            $directories += $childStats.Directories
            $files += $childStats.Files
            $documents += $childStats.Documents
            $powerShellScripts += $childStats.PowerShellScripts
            continue
        }
        $files++
        if ($IncludeExtensions -contains $item.Extension) {
            $documents++
        }
        if ($item.Extension -in @('.ps1', '.psm1')) {
            $powerShellScripts++
        }
    }
    [pscustomobject]@{
        Directories = $directories
        Files = $files
        Documents = $documents
        PowerShellScripts = $powerShellScripts
    }
}
function Write-Tree {
    param(
        $Items,
        [string]$Prefix = ''
    )
    foreach ($item in @($Items)) {
        Add-Content -LiteralPath $TxtTemp -Value "$Prefix├── $($item.Name)"
        if ($item.Type -ne 'Directory') {
            continue
        }
        $children = @($item.Children)
        if ($children.Count -gt 0) {
            Write-Tree -Items $children -Prefix "$Prefix│   "
        }
    }
}
$model = @(New-RepositoryModel -Path $Root)
$statistics = Get-Stats -Items $model
$gitBranch = git -C $Root branch --show-current 2>$null
$gitCommit = git -C $Root rev-parse HEAD 2>$null
$metadata = [pscustomobject]@{
    Repository = Split-Path $Root -Leaf
    Root = '.'
    Branch = $gitBranch
    CommitSHA = $gitCommit
    Generated = Get-Date
}
try {
    @(
        'Palworld Modding Workshop Repository Structure'
        "Generated: $($metadata.Generated)"
        "Repository: $($metadata.Repository)"
        'Root: .'
        "Branch: $($metadata.Branch)"
        "CommitSHA: $($metadata.CommitSHA)"
        ''
        'Statistics:'
        "Directories: $($statistics.Directories)"
        "Files: $($statistics.Files)"
        "Documents: $($statistics.Documents)"
        "PowerShell Scripts: $($statistics.PowerShellScripts)"
        ''
    ) | Set-Content -LiteralPath $TxtTemp
    Write-Tree -Items $model
    [pscustomobject]@{
        Metadata = $metadata
        Statistics = $statistics
        Structure = $model
    } | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $JsonTemp
    if (-not (Test-Path -LiteralPath $TxtTemp -PathType Leaf)) {
        throw "Temporary structure output was not created: $TxtTemp"
    }
    if (-not (Test-Path -LiteralPath $JsonTemp -PathType Leaf)) {
        throw "Temporary inventory output was not created: $JsonTemp"
    }
    if ($txtExisted) {
        Copy-Item -LiteralPath $TxtOutput -Destination $TxtBackup -Force
    }
    if ($jsonExisted) {
        Copy-Item -LiteralPath $JsonOutput -Destination $JsonBackup -Force
    }
    Move-Item -LiteralPath $TxtTemp -Destination $TxtOutput -Force
    Move-Item -LiteralPath $JsonTemp -Destination $JsonOutput -Force
}
catch {
    if ($txtExisted -and (Test-Path -LiteralPath $TxtBackup -PathType Leaf)) {
        Copy-Item -LiteralPath $TxtBackup -Destination $TxtOutput -Force
    }
    elseif (-not $txtExisted) {
        Remove-Item -LiteralPath $TxtOutput -Force -ErrorAction SilentlyContinue
    }
    if ($jsonExisted -and (Test-Path -LiteralPath $JsonBackup -PathType Leaf)) {
        Copy-Item -LiteralPath $JsonBackup -Destination $JsonOutput -Force
    }
    elseif (-not $jsonExisted) {
        Remove-Item -LiteralPath $JsonOutput -Force -ErrorAction SilentlyContinue
    }
    throw
}
finally {
    Remove-Item -LiteralPath $TxtTemp, $JsonTemp, $TxtBackup, $JsonBackup -Force -ErrorAction SilentlyContinue
}
Write-Host 'Repository structure exported:'
Write-Host $TxtOutput
Write-Host $JsonOutput
