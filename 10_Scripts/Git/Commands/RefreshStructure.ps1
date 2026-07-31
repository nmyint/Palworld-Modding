<#
.SYNOPSIS
    Refreshes the generated repository structure documentation.
#>
Set-StrictMode -Version Latest
function Get-PwGitFileHashValue {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function Invoke-PwGitRefreshStructure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Context,
        [string[]]$Arguments
    )
    Write-PwGitSection -Title 'Refresh Repository Structure'
    $repositoryRoot = [string]$Context.RepositoryRoot
    if ([string]::IsNullOrWhiteSpace($repositoryRoot)) {
        throw 'Pw-Git context did not provide a repository root.'
    }
    $exporterPath = Join-Path $repositoryRoot '10_Scripts\Utilities\Export-PwRepositoryStructure.ps1'
    if (-not (Test-Path -LiteralPath $exporterPath -PathType Leaf)) {
        throw "Repository structure exporter was not found: $exporterPath"
    }
    $relativeOutputs = @(
        '00_Documentation/RepositoryStructure.txt'
        '00_Documentation/RepositoryInventory.json'
    )
    $beforeHashes = @{}
    foreach ($relativePath in $relativeOutputs) {
        $fullPath = Join-Path $repositoryRoot $relativePath
        $beforeHashes[$relativePath] = Get-PwGitFileHashValue -Path $fullPath
    }
    [string[]]$stagedBefore = @(Get-PwGitStagedPaths | Sort-Object)
    & $exporterPath -Root $repositoryRoot
    [string[]]$changedOutputs = @(
        foreach ($relativePath in $relativeOutputs) {
            $fullPath = Join-Path $repositoryRoot $relativePath
            $afterHash = Get-PwGitFileHashValue -Path $fullPath
            if ($null -eq $afterHash) {
                throw "Expected generated output was not created: $fullPath"
            }
            if ($beforeHashes[$relativePath] -ne $afterHash) {
                $relativePath
            }
        }
    )
    [string[]]$stagedAfter = @(Get-PwGitStagedPaths | Sort-Object)
    if (($stagedBefore -join "`n") -ne ($stagedAfter -join "`n")) {
        throw 'Repository structure refresh unexpectedly changed the Git staging state.'
    }
    Write-Host ''
    if ($changedOutputs.Count -eq 0) {
        Write-Host '[INFO] Generated repository structure files are unchanged.'
    }
    else {
        Write-Host 'Generated files changed:'
        foreach ($relativePath in $changedOutputs) {
            Write-Host "  [CHANGED] $relativePath"
        }
    }
    Write-Host ''
    Write-Host 'Git status for generated files:'
    [object[]]$statusOutput = @(Invoke-PwGitNative -Arguments (@('status', '--short', '--') + $relativeOutputs))
    if ($statusOutput.Count -eq 0) {
        Write-Host '  <clean>'
    }
    else {
        foreach ($line in $statusOutput) {
            Write-Host "  $line"
        }
    }
    Write-Host '[INFO] Git staging state was left unchanged.'
}
