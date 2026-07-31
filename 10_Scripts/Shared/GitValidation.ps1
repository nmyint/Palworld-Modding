<#
.SYNOPSIS
    Repository state validation helpers for pw-git.

    PowerShell 7.6.4 compatible.
#>

Set-StrictMode -Version Latest

function Test-PwGitDetachedHead {
    [CmdletBinding()]
    param()

    [string]::IsNullOrWhiteSpace((Get-PwGitBranch))
}

function Test-PwGitRemote {
    [CmdletBinding()]
    param()

    $result = Invoke-PwGitNative -Arguments @('remote', 'get-url', 'origin') -AllowFailure -PassThru
    $result.ExitCode -eq 0 -and -not [string]::IsNullOrWhite