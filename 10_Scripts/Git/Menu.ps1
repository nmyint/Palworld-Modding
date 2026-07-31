<#
.SYNOPSIS
    Provides the responsive interactive Pw-Git menu.
#>
Set-StrictMode -Version Latest
function Get-PwGitTerminalSize {
    [CmdletBinding()]
    param()
    try {
        $terminalWidth = [Console]::WindowWidth
        $terminalHeight = [Console]::WindowHeight
    }
    catch {
        $terminalWidth = 80
        $terminalHeight = 24
    }
    if ($terminalWidth -lt 1) {
        $terminalWidth = 80
    }
    if ($terminalHeight -lt 1) {
        $terminalHeight = 24
    }
    [pscustomobject]@{
        Width = [math]::Max(44, [math]::Min(110, $terminalWidth - 1))
        Height = [math]::Max(18, [math]::Min(40, $terminalHeight))
    }
}
function New-PwGitMenuLine {
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Text = '',
        [ValidateSet('Left', 'Center')][string]$Alignment = 'Left',
        [ConsoleColor]$Color = [ConsoleColor]::Gray,
        [Parameter(Mandatory)][ValidateRange(44, 110)][int]$Width
    )
    $contentWidth = $Width - 4
    $content = if ($null -eq $Text) { '' } else { $Text }
    if ($content.Length -gt $contentWidth) {
        $content = $content.Substring(0, $contentWidth - 3) + '...'
    }
    $leftPadding = if ($Alignment -eq 'Center') { [math]::Floor(($contentWidth - $content.Length) / 2) } else { 0 }
    $rightPadding = $contentWidth - $content.Length - $leftPadding
    [pscustomobject]@{
        Text = '| ' + (' ' * $leftPadding) + $content + (' ' * $rightPadding) + ' |'
        Color = $Color
    }
}
function Get-PwGitMenuLayout {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Context,
        [ValidateRange(44, 110)][int]$Width = 80,
        [ValidateRange(18, 40)][int]$Height = 24
    )
    $branch = Get-PwGitBranch
    $upstream = Get-PwGitUpstream
    $state = Get-PwGitChangeState
    $repositoryName = Split-Path -Leaf ([string]$Context.RepositoryRoot)
    $border = '+' + ('-' * ($Width - 2)) + '+'
    $divider = '-' * ($Width - 4)
    $content = @(
        New-PwGitMenuLine -Text 'PW-GIT' -Alignment Center -Color Cyan -Width $Width
        New-PwGitMenuLine -Text 'Safe Git Operations Console' -Alignment Center -Color DarkCyan -Width $Width
        New-PwGitMenuLine -Text $divider -Color DarkGray -Width $Width
        New-PwGitMenuLine -Text "Repository : $repositoryName" -Width $Width
        New-PwGitMenuLine -Text "Branch     : $branch" -Width $Width
        New-PwGitMenuLine -Text "Upstream   : $(if ($upstream) { $upstream } else { '<not configured>' })" -Width $Width
        New-PwGitMenuLine -Text "Changes    : staged $($state.Staged) | unstaged $($state.Unstaged) | untracked $($state.Untracked) | conflicts $($state.Conflicts)" -Width $Width
        New-PwGitMenuLine -Text $divider -Color DarkGray -Width $Width
        New-PwGitMenuLine -Text '  [1] Check repository health' -Width $Width
        New-PwGitMenuLine -Text '  [2] Show repository status' -Width $Width
        New-PwGitMenuLine -Text '  [3] Compare local and repository' -Width $Width
        New-PwGitMenuLine -Text '  [4] Pull from repository' -Width $Width
        New-PwGitMenuLine -Text '  [5] Pull selected files' -Width $Width
        New-PwGitMenuLine -Text '  [6] Push all local changes' -Width $Width
        New-PwGitMenuLine -Text '  [7] Push selected files' -Width $Width
        New-PwGitMenuLine -Text '  [8] Create local commit from staged files' -Width $Width
        New-PwGitMenuLine -Text '  [9] Show repository history' -Width $Width
        New-PwGitMenuLine -Text '  [H] Show command help' -Width $Width
        New-PwGitMenuLine -Text '  [Q] Quit' -Color Yellow -Width $Width
        New-PwGitMenuLine -Width $Width
        New-PwGitMenuLine -Text 'Press 1-9, H, or Q.' -Color DarkGray -Width $Width
    )
    if ($Height -lt 24) {
        $content = @(
            New-PwGitMenuLine -Text 'PW-GIT' -Alignment Center -Color Cyan -Width $Width
            New-PwGitMenuLine -Text "Repo: $repositoryName | Branch: $branch" -Width $Width
            New-PwGitMenuLine -Text "S:$($state.Staged) U:$($state.Unstaged) ?: $($state.Untracked) X:$($state.Conflicts) | $(if ($upstream) { $upstream } else { 'no upstream' })" -Width $Width
            New-PwGitMenuLine -Text $divider -Color DarkGray -Width $Width
            New-PwGitMenuLine -Text ' [1] Check   [2] Status   [3] Compare' -Width $Width
            New-PwGitMenuLine -Text ' [4] Pull    [5] Pull selected' -Width $Width
            New-PwGitMenuLine -Text ' [6] Push    [7] Push selected' -Width $Width
            New-PwGitMenuLine -Text ' [8] Commit  [9] History' -Width $Width
            New-PwGitMenuLine -Text ' [H] Help    [Q] Quit' -Color Yellow -Width $Width
            New-PwGitMenuLine -Text 'Press 1-9, H, or Q.' -Color DarkGray -Width $Width
        )
    }
    $targetRenderedRows = if ($Height -le 18) { $Height } else { $Height - 2 }
    $extraRows = [math]::Max(0, $targetRenderedRows - ($content.Count + 2))
    $topPadding = [math]::Floor($extraRows / 2)
    $bottomPadding = $extraRows - $topPadding
    $layout = [System.Collections.Generic.List[object]]::new()
    $layout.Add([pscustomobject]@{ Text = $border; Color = [ConsoleColor]::Cyan })
    for ($index = 0; $index -lt $topPadding; $index++) {
        $layout.Add((New-PwGitMenuLine -Width $Width))
    }
    foreach ($line in $content) {
        $layout.Add($line)
    }
    for ($index = 0; $index -lt $bottomPadding; $index++) {
        $layout.Add((New-PwGitMenuLine -Width $Width))
    }
    $layout.Add([pscustomobject]@{ Text = $border; Color = [ConsoleColor]::Cyan })
    @($layout)
}
function Write-PwGitMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Context,
        [Parameter(Mandatory)][object]$Terminal
    )
    $layout = Get-PwGitMenuLayout -Context $Context -Width $Terminal.Width -Height $Terminal.Height
    foreach ($line in $layout) {
        Write-Host $line.Text -ForegroundColor $line.Color
    }
}
function Read-PwGitMenuSelection {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$RenderedTerminal)
    try {
        $null = [Console]::KeyAvailable
    }
    catch {
        return Read-Host 'Select'
    }
    while ($true) {
        $currentTerminal = Get-PwGitTerminalSize
        if ($currentTerminal.Width -ne $RenderedTerminal.Width -or $currentTerminal.Height -ne $RenderedTerminal.Height) {
            return '__RESIZE__'
        }
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            $selection = $key.KeyChar.ToString().ToUpperInvariant()
            if ($selection -in @('1', '2', '3', '4', '5', '6', '7', '8', '9', 'H', 'Q')) {
                return $selection
            }
        }
        Start-Sleep -Milliseconds 100
    }
}
function Invoke-PwGitMenuCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][object]$Context,
        [string[]]$Arguments
    )
    $definition = Get-PwGitCommandDefinition -Name $Name
    if ($null -eq $definition) {
        throw "Unsupported Pw-Git menu command: $Name"
    }
    $commandPath = Join-Path $script:PwGitCommandsRoot $definition.File
    if (-not (Test-Path -LiteralPath $commandPath -PathType Leaf)) {
        throw "The Pw-Git '$Name' command has not been implemented. Expected: $commandPath"
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
            Clear-Host
            $renderedTerminal = Get-PwGitTerminalSize
            Write-PwGitMenu -Context $Context -Terminal $renderedTerminal
            $choice = Read-PwGitMenuSelection -RenderedTerminal $renderedTerminal
            if ($choice -eq '__RESIZE__') {
                continue
            }
            if (Test-PwGitQuitInput -Value $choice) {
                return
            }
            Clear-Host
            try {
                switch ($choice) {
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
                }
            }
            catch [System.OperationCanceledException] {
                throw
            }
            catch {
                Write-Host $_.Exception.Message -ForegroundColor Red
            }
            Write-Host ''
            $pauseInput = Read-Host 'Press Enter to return to Pw-Git, or Q to quit'
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
