<#
.SYNOPSIS
    Provides the interactive pw-git menu.
#>
Set-StrictMode -Version Latest
function Invoke-PwGitMenuCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][object]$Context,
        [string[]]$Arguments
    )
    $definition = Get-PwGitCommandDefinition -Name $Name
    if ($null -eq $definition) {
        throw "Unsupported pw-git menu command: $Name"
    }
    $commandPath = Join-Path $script:PwGitCommandsRoot $definition.File
    if (-not (Test-Path -LiteralPath $commandPath -PathType Leaf)) {
        throw "The pw-git '$Name' command has not been implemented. Expected: $commandPath"
    }
    . $commandPath
    $commandFunction = Get-Command $definition.Function -CommandType Function -ErrorAction SilentlyContinue
    if ($null -eq $commandFunction) {
        throw "Command file '$commandPath' did not define '$($definition.Function)'."
    }
    & $definition.Function -Context $Context -Arguments @($Arguments)
}
function Show-PwGitMenu {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Context)
    try {
        while ($true) {
            Write-PwGitSection -Title 'pw-git'
            Write-Host "Repository : $($Context.RepositoryRoot)"
            Write-Host "Branch     : $(Get-PwGitBranch)"
            Write-Host ''
            Write-Host '1. Check repository health'
            Write-Host '2. Show repository status'
            Write-Host '3. Compare local and repository'
            Write-Host '4. Pull from repository'
            Write-Host '5. Pull selected files'
            Write-Host '6. Push all local changes'
            Write-Host '7. Push selected files'
            Write-Host '8. Create local commit from staged files'
            Write-Host '9. Show repository history'
            Write-Host 'H. Show command help'
            Write-Host 'Q. Quit'
            Write-Host ''
            $choice = Read-Host 'Choose an action'
            if (Test-PwGitQuitInput -Value $choice) {
                return
            }
            if ([string]::IsNullOrWhiteSpace($choice)) {
                continue
            }
            try {
                switch ($choice.Trim().ToUpperInvariant()) {
                    '1' { Invoke-PwGitMenuCommand -Name 'check' -Context $Context }
                    '2' { Invoke-PwGitMenuCommand -Name 'status' -Context $Context }
                    '3' { Invoke-PwGitMenuCommand -Name 'compare' -Context $Context }
                    '4' { Invoke-PwGitMenuCommand -Name 'pull' -Context $Context }
                    '5' { Invoke-PwGitMenuCommand -Name 'pull-selected' -Context $Context }
                    '6' { Invoke-PwGitMenuCommand -Name 'push' -Context $Context }
                    '7' {
                        [string[]]$selectedFiles = @(Select-PwGitFiles)
                        if ($selectedFiles.Count -eq 0) {
                            Write-Host '[INFO] No files were selected.'
                        }
                        else {
                            Invoke-PwGitMenuCommand -Name 'push' -Context $Context -Arguments $selectedFiles
                        }
                    }
                    '8' { Invoke-PwGitMenuCommand -Name 'commit' -Context $Context }
                    '9' {
                        $countText = Read-Host 'Number of commits to show [15, Q to quit]'
                        if (Test-PwGitQuitInput -Value $countText) {
                            return
                        }
                        if ([string]::IsNullOrWhiteSpace($countText)) {
                            Invoke-PwGitMenuCommand -Name 'log' -Context $Context
                        }
                        else {
                            Invoke-PwGitMenuCommand -Name 'log' -Context $Context -Arguments @($countText.Trim())
                        }
                    }
                    'H' { Show-PwGitHelp }
                    default { Write-Warning "Unknown menu choice: '$choice'." }
                }
            }
            catch [System.OperationCanceledException] {
                throw
            }
            catch {
                Write-Host ''
                Write-Warning $_.Exception.Message
            }
            Write-Host ''
            $pauseInput = Read-Host 'Press Enter to return to the menu, or Q to quit'
            if (Test-PwGitQuitInput -Value $pauseInput) {
                return
            }
        }
    }
    catch [System.OperationCanceledException] {
        if ($_.Exception.Message -ne 'PWGIT_QUIT') {
            throw
        }
    }
}
