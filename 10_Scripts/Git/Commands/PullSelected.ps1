Set-StrictMode -Version Latest

function Select-PwGitUpstreamFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Items
    )

    if ($Items.Count -eq 0) {
        return @()
    }

    Write-Host 'Select files by number. Use commas or ranges (example: 1,3-5).'
    Write-Host ''

    for ($index = 0; $index -lt $Items.Count; $index++) {
        Write-Host ('{0,3}. [{1}] {2}' -f ($index + 1), $Items[$index].Status, $Items[$index].Path)
    }

    Write-Host ''
    $selection = Read-Host 'Selection'
    if ([string]::IsNullOrWhiteSpace($selection)) {
        return @()
    }

    $selectedIndexes = [System.Collections.Generic.HashSet[int]]::new()

    foreach ($token in ($selection -split ',')) {
        $trimmedToken = $token.Trim()

        if ($trimmedToken -match '^(\d+)-(\d+)$') {
            $start = [int]$Matches[1]
            $end = [int]$Matches[2]

            if ($start -gt $end) {
                $temporary = $start
                $start = $end
                $end = $temporary
            }

            foreach ($number in $start..$end) {
                if ($number -lt 1 -or $number -gt $Items.Count) {
                    throw "Selection '$number' is outside the available range."
                }

                [void]$selectedIndexes.Add($number - 1)
            }

            continue
        }

        if ($trimmedToken -match '^\d+$') {
            $number = [int]$trimmedToken
            if ($number -lt 1 -or $number -gt $Items.Count) {
                throw "Selection '$number' is outside the available range."
            }

            [void]$selectedIndexes.Add($number - 1)
            continue
        }

        throw "Invalid file selection token: '$trimmedToken'."
    }

    @(
        $selectedIndexes |
            Sort-Object |
            ForEach-Object { $Items[$_].Path }
    )
}

function Get-PwGitUpstreamChangedFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Upstream
    )

    $items = [System.Collections.Generic.List[object]]::new()
    $lines = @(Invoke-PwGitNative -Arguments @('diff', '--name-status', 'HEAD', $Upstream, '--'))

    foreach ($line in $lines) {
        $text = [string]$line
        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }

        $parts = $text -split "`t"
        if ($parts.Count -lt 2) {
            continue
        }

        $status = $parts[0]
        $path = if ($status -match '^[RC]' -and $parts.Count -ge 3) {
            $parts[2]
        }
        else {
            $parts[1]
        }

        $items.Add([pscustomobject]@{
            Status = $status
            Path   = $path
        })
    }

    @($items)
}

function Invoke-PwGitPullSelected {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Context,

        [string[]]$Arguments
    )

    Write-PwGitSection -Title 'Pull Selected Files'

    $upstream = Assert-PwGitUpstream
    Write-Host "Refreshing $upstream before file selection."
    Invoke-PwGitNative -Arguments @('fetch', '--prune') |
        ForEach-Object {
            if (-not [string]::IsNullOrWhiteSpace([string]$_)) {
                Write-Host $_
            }
        }

    $availableItems = @(Get-PwGitUpstreamChangedFiles -Upstream $upstream)
    if ($availableItems.Count -eq 0) {
        Write-Host '[ OK ] No files differ between local HEAD and the upstream branch.'
        return
    }

    $requestedPaths = @(
        @($Arguments) |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
            ForEach-Object { ([string]$_).Trim() }
    )

    $selectedPaths = if ($requestedPaths.Count -gt 0) {
        $availablePaths = @($availableItems.Path)
        foreach ($path in $requestedPaths) {
            if ($availablePaths -notcontains $path) {
                throw "'$path' does not differ between local HEAD and $upstream."
            }
        }

        $requestedPaths
    }
    else {
        @(Select-PwGitUpstreamFiles -Items $availableItems)
    }

    if ($selectedPaths.Count -eq 0) {
        Write-Host '[INFO] No files were selected.'
        return
    }

    $localChanges = @(Get-PwGitStatusLines)
    $overwrittenChanges = @(
        foreach ($statusLine in $localChanges) {
            $text = [string]$statusLine
            if ($text.Length -lt 4) {
                continue
            }

            $localPath = $text.Substring(3).Trim()
            if ($localPath -match ' -> ') {
                $localPath = ($localPath -split ' -> ', 2)[1]
            }

            if ($selectedPaths -contains $localPath) {
                $text
            }
        }
    )

    Write-Host ''
    Write-Host "Selected files will be restored from $upstream:"
    $selectedPaths | ForEach-Object { Write-Host "  $_" }

    if ($overwrittenChanges.Count -gt 0) {
        Write-Host ''
        Write-Warning 'The following selected files contain local working-tree or staged changes that will be overwritten:'
        $overwrittenChanges | ForEach-Object { Write-Host "  $_" }
    }

    Write-Host ''
    Write-Warning 'This operation updates only the selected files. It does not merge or advance the current branch.'

    if (-not (Confirm-PwGitAction -Prompt "Replace the selected files with their versions from $upstream?")) {
        Write-Host '[INFO] Pull selected files cancelled. No files were changed.'
        return
    }

    Invoke-PwGitNative -Arguments @(
        'restore',
        "--source=$upstream",
        '--staged',
        '--worktree',
        '--'
    ) + $selectedPaths | Out-Null

    Write-Host '[ OK ] Selected files were updated from the upstream branch.'
    Write-Host '[INFO] The branch commit history was not changed.'
}
