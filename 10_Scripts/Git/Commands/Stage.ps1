<#
.SYNOPSIS
    Stages selected repository files.
#>
Set-StrictMode -Version Latest
function Invoke-PwGitStage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Context,
        [string[]]$Arguments
    )
    Write-PwGitSection -Title 'Stage Selected Files'
    $files = @(Get-PwGitSelectableFiles)
    if ($files.Count -eq 0) {
        Write-Host '[INFO] No unstaged files available.'
        return
    }
    $selected = @(Select-PwGitItems -Items $files)
    if ($selected.Count -eq 0) {
        Write-Host '[INFO] No files selected.'
        return
    }
    $paths = @($selected | ForEach-Object { $_.Path })
    Invoke-PwGitNative -Arguments (@('add','--') + $paths) | Out-Null
    Write-Host '[ OK ] Selected files staged.'
}
