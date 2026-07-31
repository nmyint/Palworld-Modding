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
function New-PwGitMenuLayout {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Content,
        [Parameter(Mandatory)][ValidateRange(44, 110)][int]$Width,
        [Parameter(Mandatory)][ValidateRange(18, 40)][int]$Height
    )
    $border = '+' + ('-' * ($Width - 2)) + '+'
    $targetRenderedRows = if ($Height -le 18) { $Height } else { $Height - 2 }
    $extraRows = [math]::Max(0, $targetRenderedRows - ($Content.Count + 2))
    $topPadding = [math]::Floor($extraRows / 2)
    $bottomPadding = $extraRows - $topPadding
    $layout = [System.Collections.Generic.List[object]]::new()
    $layout.Add([pscustomobject]@{ Text = $border; Color = [ConsoleColor]::Cyan })
    for ($index = 0; $index -lt $topPadding; $index++) {
        $layout.Add((New-PwGitMenuLine -Width $Width))
    }
    foreach ($line in $Content) {
        $layout.Add($line)
    }
    for ($index = 0; $index -lt $bottomPadding; $index++) {
        $layout.Add((New-PwGitMenuLine -Width $Width))
    }
    $layout.Add([pscustomobject]@{ Text = $border; Color = [ConsoleColor]::Cyan })
    @($layout)
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
        New-PwGitMenuLine -Text '  [3] Fetch repository updates' -Width $Width
        New-PwGitMenuLine -Text '  [4] Compare local and repository' -Width $Width
        New-PwGitMenuLine -Text '  [5] Pull from repository' -Width $Width
        New-PwGitMenuLine -Text '  [6] Pull selected files' -Width $Width
        New-PwGitMenuLine -Text '  [7] Stage selected files' -Width $Width
        New-PwGitMenuLine -Text '  [8] Commit staged files' -Width $Width
        New-PwGitMenuLine -Text '  [9] Push committed changes' -Width $Width
        New-PwGitMenuLine -Text '  [H] Advanced operations' -Color Yellow -Width $Width
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
            New-PwGitMenuLine -Text ' [1] Check    [2] Status    [3] Fetch' -Width $Width
            New-PwGitMenuLine -Text ' [4] Compare  [5] Pull      [6] Pull selected' -Width $Width
            New-PwGitMenuLine -Text ' [7] Stage    [8] Commit    [9] Push' -Width $Width
            New-PwGitMenuLine -Text ' [H] Advanced             [Q] Quit' -Color Yellow -Width $Width
            New-PwGitMenuLine -Text 'Press 1-9, H, or Q.' -Color DarkGray -Width $Width
        )
    }
    New-PwGitMenuLayout -Content $content -Width $Width -Height $Height
}
function Get-PwGitAdvancedMenuLayout {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Context,
        [ValidateRange(44, 110)][int]$Width = 80,
        [ValidateRange(18, 40)][int]$Height = 24
    )
    $branch = Get-PwGitBranch
    $repositoryName = Split-Path -Leaf ([string]$Context.RepositoryRoot)
    $divider = '-' * ($Width - 4)
    $content = @(
        New-PwGitMenuLine -Text 'PW-GIT' -Alignment Center -Color Cyan -Width $Width
        New-PwGitMenuLine -Text 'Advanced Git Operations' -Alignment Center -Color DarkCyan -Width $Width
        New-PwGitMenuLine -Text $divider -Color DarkGray -Width $Width
        New-PwGitMenuLine -Text "Repository : $repositoryName" -Width $Width
        New-PwGitMenuLine -Text "Branch     : $branch" -Width $Width
        New-PwGitMenuLine -Text $divider -Color DarkGray -Width $Width
        New-PwGitMenuLine -Text '  [1] Unstage selected files' -Width $Width
        New-PwGitMenuLine -Text '  [2] Discard local changes' -Width $Width
        New-PwGitMenuLine -Text '  [3] Stash changes' -Width $Width
        New-PwGitMenuLine -Text '  [4] Restore stash' -Width $Width
        New-PwGitMenuLine -Text '  [5] Repository history' -Width $Width
        New-PwGitMenuLine -Text '  [6] Branch information' -Width $Width
        New-PwGitMenuLine -Text '  [7] Refresh repository structure' -Width $Width
        New-PwGitMenuLine -Text '  [B] Back' -Color Yellow -Width $Width
        New-PwGitMenuLine -Text '  [Q] Quit' -Color Yellow -Width $Width
        New-PwGitMenuLine -Width $Width
        New-PwGitMenuLine -Text 'Press 1-7, B, Enter, or Q.' -Color DarkGray -Width $Width
    )
    if ($Height -lt 22) {
        $content = @(
            New-PwGitMenuLine -Text 'ADVANCED GIT OPERATIONS' -Alignment Center -Color Cyan -Width $Width
            New-PwGitMenuLine -Text "Repo: $repositoryName | Branch: $branch" -Width $Width
            New-PwGitMenuLine -Text $divider -Color DarkGray -Width $Width
            New-PwGitMenuLine -Text ' [1] Unstage    [2] Discard    [3] Stash' -Width $Width
            New-PwGitMenuLine -Text ' [4] Restore    [5] History    [6] Branch info' -Width $Width
            New-PwGitMenuLine -Text ' [7] Refresh structure' -Width $Width
            New-PwGitMenuLine -Text ' [B] Back       [Q] Quit' -Color Yellow -Width $Width
            New-PwGitMenuLine -Text 'Press 1-7, B, Enter, or Q.' -Color DarkGray -Width $Width
        )
    }
    New-PwGitMenuLayout -Content $content -Width $Width -Height $Height
}
function Write-PwGitMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Context,
        [Parameter(Mandatory)][object]$Terminal,
        [ValidateSet('Main', 'Advanced')][string]$Page = 'Main'
    )
    $layout = if ($Page -eq 'Advanced') {
        Get-PwGitAdvancedMenuLayout -Context $Context -Width $Terminal.Width -Height $Terminal.Height
    }
    else {
        Get-PwGitMenuLayout -Context $Context -Width $Terminal.Width -Height $Terminal.Height
    }
    foreach ($line in $layout) {
        Write-Host $line.Text -ForegroundColor $line.Color
    }
}
function Read-PwGitMenuSelection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$RenderedTerminal,
        [Parameter(Mandatory)][string[]]$ValidSelections,
        [string]$EnterSelection
    )
    try {
        $null = [Console]::KeyAvailable
    }
    catch {
        while ($true) {
            $selection = (Read-Host 'Select').Trim().ToUpperInvariant()
            if ([string]::IsNullOrWhiteSpace($selection) -and -not [string]::IsNullOrWhiteSpace($EnterSelection)) {
                return $EnterSelection
            }
            if ($selection -in $ValidSelections) {
                return $selection
            }
        }
    }
    while ($true) {
        $currentTerminal = Get-PwGitTerminalSize
        if ($currentTerminal.Width -ne $RenderedTerminal.Width -or $currentTerminal.Height -ne $RenderedTerminal.Height) {
            return '__RESIZE__'
        }
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [ConsoleKey]::Enter -and -not [string]::IsNullOrWhiteSpace($EnterSelection)) {
                return $EnterSelection
            }
            $selection = $key.KeyChar.ToString().ToUpperInvariant()
            if ($selection -in $ValidSelections) {
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
function Invoke-PwGitUnstageSelected {
    [CmdletBinding()]
    param()
    [string[]]$stagedPaths = @(Get-PwGitStagedPaths)
    if ($stagedPaths.Count -eq 0) {
        Write-Host '[INFO] No staged files available.'
        return
    }
    [object[]]$items = @(
        foreach ($path in $stagedPaths) {
            [pscustomobject]@{ Status = 'S'; Path = $path }
        }
    )
    [object[]]$selected = @(Select-PwGitItems -Items $items)
    if ($selected.Count -eq 0) {
        Write-Host '[INFO] No files selected.'
        return
    }
    [string[]]$paths = @($selected | ForEach-Object { [string]$_.Path })
    if (-not (Confirm-PwGitAction -Prompt 'Unstage the selected files?')) {
        Write-Host '[INFO] Unstage cancelled.'
        return
    }
    Invoke-PwGitNative -Arguments (@('restore', '--staged', '--') + $paths) | Out-Null
    Write-Host '[ OK ] Selected files unstaged.'
}
function Invoke-PwGitDiscardLocalChanges {
    [CmdletBinding()]
    param()
    if (Test-PwGitConflicts) {
        throw 'Discard is unavailable while merge conflicts are present. Resolve the conflicts first.'
    }
    [object[]]$items = @(
        foreach ($item in @(Get-PwGitSelectableFiles)) {
            $code = [string]$item.Status
            if ($code -ne '??' -and $code.Length -ge 2 -and $code[1] -ne ' ') {
                $item
            }
        }
    )
    if ($items.Count -eq 0) {
        Write-Host '[INFO] No tracked unstaged changes are available to discard.'
        return
    }
    [object[]]$selected = @(Select-PwGitItems -Items $items)
    if ($selected.Count -eq 0) {
        Write-Host '[INFO] No files selected.'
        return
    }
    [string[]]$paths = @($selected | ForEach-Object { [string]$_.Path })
    Write-Host '[WARN] This permanently discards the selected unstaged working-tree changes.' -ForegroundColor Yellow
    if (-not (Confirm-PwGitAction -Prompt 'Discard the selected local changes?')) {
        Write-Host '[INFO] Discard cancelled.'
        return
    }
    Invoke-PwGitNative -Arguments (@('restore', '--worktree', '--') + $paths) | Out-Null
    Write-Host '[ OK ] Selected local changes discarded.'
}
function Invoke-PwGitStashChanges {
    [CmdletBinding()]
    param()
    if (Test-PwGitClean) {
        Write-Host '[INFO] No local changes are available to stash.'
        return
    }
    if (Test-PwGitConflicts) {
        throw 'Stash is unavailable while merge conflicts are present.'
    }
    if (-not (Confirm-PwGitAction -Prompt 'Stash tracked and untracked local changes?')) {
        Write-Host '[INFO] Stash cancelled.'
        return
    }
    $message = 'Pw-Git stash {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Write-PwGitOutput -InputObject @(Invoke-PwGitNative -Arguments @('stash', 'push', '--include-untracked', '-m', $message))
    Write-Host '[ OK ] Local changes stashed.'
}
function Invoke-PwGitRestoreStash {
    [CmdletBinding()]
    param()
    [string[]]$stashLines = @(
        Invoke-PwGitNative -Arguments @('stash', 'list', '--format=%gd%x09%s') |
            ForEach-Object { [string]$_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
    if ($stashLines.Count -eq 0) {
        Write-Host '[INFO] No stashes are available.'
        return
    }
    [object[]]$items = @(
        foreach ($line in $stashLines) {
            $parts = $line -split "`t", 2
            $reference = $parts[0].Trim()
            $subject = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }
            [pscustomobject]@{ Ref = $reference; Subject = $subject }
        }
    )
    [object[]]$selected = @(Select-PwGitItems -Items $items -StatusProperty 'Ref' -PathProperty 'Subject')
    if ($selected.Count -eq 0) {
        Write-Host '[INFO] No stash selected.'
        return
    }
    if ($selected.Count -gt 1) {
        throw 'Restore one stash at a time.'
    }
    $reference = [string]$selected[0].Ref
    Write-Host '[INFO] Restore uses git stash apply --index; the stash entry is retained.'
    if (-not (Confirm-PwGitAction -Prompt "Restore ${reference}?")) {
        Write-Host '[INFO] Restore cancelled.'
        return
    }
    Write-PwGitOutput -InputObject @(Invoke-PwGitNative -Arguments @('stash', 'apply', '--index', $reference))
    Write-Host "[ OK ] ${reference} restored and retained in the stash list."
}
function Invoke-PwGitHistoryPrompt {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Context)
    $countText = Read-Host 'Number of commits to show [15, Enter/B back, Q quit]'
    if (Test-PwGitQuitInput -Value $countText) {
        Stop-PwGitUx
    }
    if (Test-PwGitBackInput -Value $countText) {
        Stop-PwGitMenu
    }
    if ([string]::IsNullOrWhiteSpace($countText)) {
        Invoke-PwGitMenuCommand -Name 'log' -Context $Context
        return
    }
    Invoke-PwGitMenuCommand -Name 'log' -Context $Context -Arguments @($countText.Trim())
}
function Show-PwGitBranchInformation {
    [CmdletBinding()]
    param()
    Write-PwGitSection -Title 'Branch Information'
    $branch = Get-PwGitBranch
    $upstream = Get-PwGitUpstream
    $origin = Get-PwGitOriginUrl
    Write-Host "Current branch : $(if ([string]::IsNullOrWhiteSpace($branch)) { '<detached HEAD>' } else { $branch })"
    Write-Host "Upstream       : $(if ($upstream) { $upstream } else { '<not configured>' })"
    Write-Host "Origin         : $(if ($origin) { $origin } else { '<not configured>' })"
    if ($upstream) {
        $divergence = Get-PwGitDivergence -Upstream $upstream
        Write-Host "Ahead          : $($divergence.Ahead)"
        Write-Host "Behind         : $($divergence.Behind)"
    }
    Write-Host ''
    Write-PwGitOutput -InputObject @(Invoke-PwGitNative -Arguments @('branch', '-vv'))
}
function Invoke-PwGitPushCommittedChanges {
    [CmdletBinding()]
    param()
    Write-PwGitSection -Title 'Push Committed Changes'
    Assert-PwGitWritableState
    if (-not (Test-PwGitRemote)) {
        throw 'No origin remote configured.'
    }
    $upstream = Assert-PwGitUpstream
    Write-PwGitOutput -InputObject @(Invoke-PwGitNative -Arguments @('fetch', '--prune'))
    $comparison = Get-PwGitAheadBehind -Upstream $upstream
    if ($comparison.Behind -gt 0) {
        throw "Local branch is $($comparison.Behind) commit(s) behind ${upstream}. Pull or reconcile before pushing."
    }
    if ($comparison.Ahead -eq 0) {
        Write-Host '[INFO] No unpushed commits were found.'
        return
    }
    $state = Get-PwGitChangeState
    if ($state.Staged -gt 0 -or $state.Unstaged -gt 0 -or $state.Untracked -gt 0) {
        Write-Host '[INFO] Working-tree changes will not be included; only existing commits will be pushed.'
    }
    if (-not (Confirm-PwGitAction -Prompt "Push $($comparison.Ahead) commit(s) to ${upstream}?")) {
        Write-Host '[INFO] Push cancelled.'
        return
    }
    Write-PwGitOutput -InputObject @(Invoke-PwGitNative -Arguments @('push'))
    Write-Host '[ OK ] Committed changes pushed.'
}
function Show-PwGitAdvancedMenu {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Context)
    while ($true) {
        Clear-Host
        $renderedTerminal = Get-PwGitTerminalSize
        Write-PwGitMenu -Context $Context -Terminal $renderedTerminal -Page Advanced
        $choice = Read-PwGitMenuSelection -RenderedTerminal $renderedTerminal -ValidSelections @('1', '2', '3', '4', '5', '6', '7', 'B', 'Q') -EnterSelection 'B'
        if ($choice -eq '__RESIZE__') {
            continue
        }
        if (Test-PwGitQuitInput -Value $choice) {
            Stop-PwGitUx
        }
        if (Test-PwGitBackInput -Value $choice) {
            return
        }
        Clear-Host
        try {
            switch ($choice) {
                '1' { Invoke-PwGitUnstageSelected }
                '2' { Invoke-PwGitDiscardLocalChanges }
                '3' { Invoke-PwGitStashChanges }
                '4' { Invoke-PwGitRestoreStash }
                '5' { Invoke-PwGitHistoryPrompt -Context $Context }
                '6' { Show-PwGitBranchInformation }
                '7' { Invoke-PwGitMenuCommand -Name 'refresh-structure' -Context $Context }
            }
        }
        catch [System.OperationCanceledException] {
            if ($_.Exception.Message -eq 'PWGIT_BACK') {
                continue
            }
            throw
        }
        catch {
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
        Write-Host ''
        $pauseInput = Read-Host 'Press Enter or B to return to Advanced, or Q to quit'
        if (Test-PwGitQuitInput -Value $pauseInput) {
            Stop-PwGitUx
        }
    }
}
function Show-PwGitMenu {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Context)
    try {
        while ($true) {
            Clear-Host
            $renderedTerminal = Get-PwGitTerminalSize
            Write-PwGitMenu -Context $Context -Terminal $renderedTerminal
            $choice = Read-PwGitMenuSelection -RenderedTerminal $renderedTerminal -ValidSelections @('1', '2', '3', '4', '5', '6', '7', '8', '9', 'H', 'Q')
            if ($choice -eq '__RESIZE__') {
                continue
            }
            if (Test-PwGitQuitInput -Value $choice) {
                return
            }
            Clear-Host
            $pauseAfterCommand = $true
            try {
                switch ($choice) {
                    '1' { Invoke-PwGitMenuCommand -Name 'check' -Context $Context }
                    '2' { Invoke-PwGitMenuCommand -Name 'status' -Context $Context }
                    '3' { Invoke-PwGitMenuCommand -Name 'fetch' -Context $Context }
                    '4' { Invoke-PwGitMenuCommand -Name 'compare' -Context $Context }
                    '5' { Invoke-PwGitMenuCommand -Name 'pull' -Context $Context }
                    '6' { Invoke-PwGitMenuCommand -Name 'pull-selected' -Context $Context }
                    '7' { Invoke-PwGitMenuCommand -Name 'stage' -Context $Context }
                    '8' { Invoke-PwGitMenuCommand -Name 'commit' -Context $Context }
                    '9' { Invoke-PwGitPushCommittedChanges }
                    'H' {
                        Show-PwGitAdvancedMenu -Context $Context
                        $pauseAfterCommand = $false
                    }
                }
            }
            catch [System.OperationCanceledException] {
                if ($_.Exception.Message -eq 'PWGIT_BACK') {
                    continue
                }
                throw
            }
            catch {
                Write-Host $_.Exception.Message -ForegroundColor Red
            }
            if (-not $pauseAfterCommand) {
                continue
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
