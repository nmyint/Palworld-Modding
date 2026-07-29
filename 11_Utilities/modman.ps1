<#
.SYNOPSIS
    Lightweight UE4SS mod enabler, disabler, and load-order manager.
.DESCRIPTION
    Uses disabled.txt as the authoritative disabled marker. The absence of that
    marker means a mod is enabled. Regenerates mods.txt and mods.json atomically
    while preserving the existing UE4SS load order. The built-in Keybinds entry
    is always enabled and pinned beneath UE4SS's protected footer.

    Interactive keys:
      R       Refresh and rewrite the state files
      T       Toggle a mod by number
      U       Move a mod up in the load order
      D       Move a mod down in the load order
      Q       Quit

    Number keys also begin a direct toggle selection.
#>

[CmdletBinding()]
param(
    [string]$ModsDir = $PSScriptRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:LogFile = Join-Path $PSScriptRoot 'modmanager.log'
$script:BackupDir = Join-Path $PSScriptRoot 'backup'
$script:GeneratedNames = @(
    'backup',
    '.git',
    '.vscode',
    '__pycache__'
)

function Write-ModManagerLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    try {
        $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
        Add-Content `
            -LiteralPath $script:LogFile `
            -Value "[$stamp] $Message" `
            -Encoding utf8
    }
    catch {
        Write-Warning "Could not write the mod-manager log: $($_.Exception.Message)"
    }
}

function Resolve-ModsDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolved = [System.IO.Path]::GetFullPath($Path)

    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        throw "Mods directory does not exist: $resolved"
    }

    $resolved
}

function Ensure-BackupDirectory {
    if (-not (Test-Path -LiteralPath $script:BackupDir -PathType Container)) {
        New-Item `
            -Path $script:BackupDir `
            -ItemType Directory `
            -Force |
            Out-Null
        Write-ModManagerLog "Created backup folder: $script:BackupDir"
    }
}

function Backup-ModStateFiles {
    param(
        [Parameter(Mandatory)]
        [string]$ModsDirectory
    )

    Ensure-BackupDirectory
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'

    foreach ($name in @('mods.txt', 'mods.json')) {
        $source = Join-Path $ModsDirectory $name

        if (Test-Path -LiteralPath $source -PathType Leaf) {
            $extension = [System.IO.Path]::GetExtension($name)
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($name)
            $destination = Join-Path `
                $script:BackupDir `
                "${baseName}_${stamp}${extension}"
            Copy-Item `
                -LiteralPath $source `
                -Destination $destination `
                -Force
        }
    }
}

function Get-SavedLoadOrder {
    param(
        [Parameter(Mandatory)]
        [string]$ModsDirectory
    )

    $order = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $jsonPath = Join-Path $ModsDirectory 'mods.json'
    $textPath = Join-Path $ModsDirectory 'mods.txt'

    if (Test-Path -LiteralPath $jsonPath -PathType Leaf) {
        try {
            foreach ($entry in @(
                Get-Content -LiteralPath $jsonPath -Raw |
                    ConvertFrom-Json
            )) {
                $name = [string]$entry.Name

                if (
                    -not [string]::IsNullOrWhiteSpace($name) -and
                    $seen.Add($name)
                ) {
                    $order.Add($name)
                }
            }
        }
        catch {
            Write-ModManagerLog (
                "Ignored invalid mods.json while recovering load order: " +
                $_.Exception.Message
            )
        }
    }

    if (Test-Path -LiteralPath $textPath -PathType Leaf) {
        foreach ($line in Get-Content -LiteralPath $textPath) {
            if ($line -match '^\s*([^;][^:]+?)\s*:\s*[01]\s*$') {
                $name = $matches[1].Trim()

                if ($seen.Add($name)) {
                    $order.Add($name)
                }
            }
        }
    }

    @($order)
}

function Get-ModList {
    param(
        [Parameter(Mandatory)]
        [string]$ModsDirectory,

        [string[]]$PreferredOrder = @()
    )

    $directories = @(
        Get-ChildItem -LiteralPath $ModsDirectory -Directory -Force |
            Where-Object {
                $_.Name -notin $script:GeneratedNames -and
                -not $_.Name.StartsWith('.')
            }
    )
    $byName = @{}

    foreach ($directory in $directories) {
        $byName[$directory.Name] = $directory
    }

    $orderedNames = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($name in $PreferredOrder) {
        if ($byName.ContainsKey($name) -and $seen.Add($name)) {
            $orderedNames.Add($name)
        }
    }

    foreach ($name in @($byName.Keys | Sort-Object)) {
        if ($seen.Add($name)) {
            $orderedNames.Add($name)
        }
    }

    # UE4SS requires its built-in Keybinds entry to remain at the bottom.
    $orderedNames = @(
        $orderedNames |
            Where-Object {
                -not $_.Equals(
                    'Keybinds',
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            }
    ) + @(
        $orderedNames |
            Where-Object {
                $_.Equals(
                    'Keybinds',
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            }
    )

    @(
        foreach ($name in $orderedNames) {
            $directory = $byName[$name]
            $disabledPath = Join-Path $directory.FullName 'disabled.txt'
            $legacyEnabledPath = Join-Path $directory.FullName 'enabled.txt'
            $isPinned = $directory.Name.Equals(
                'Keybinds',
                [System.StringComparison]::OrdinalIgnoreCase
            )

            if (Test-Path -LiteralPath $legacyEnabledPath -PathType Leaf) {
                Remove-Item -LiteralPath $legacyEnabledPath -Force
                Write-ModManagerLog (
                    "Removed legacy enabled.txt marker for: $($directory.Name)"
                )
            }

            if (
                $isPinned -and
                (Test-Path -LiteralPath $disabledPath -PathType Leaf)
            ) {
                Remove-Item -LiteralPath $disabledPath -Force
                Write-ModManagerLog (
                    'Removed disabled.txt from the required Keybinds mod.'
                )
            }

            [PSCustomObject]@{
                Name = $directory.Name
                Path = $directory.FullName
                Enabled = $isPinned -or -not (
                    Test-Path -LiteralPath $disabledPath -PathType Leaf
                )
                Pinned = $isPinned
            }
        }
    )
}

function Set-AtomicTextFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines
    )

    $temporaryPath = Join-Path `
        (Split-Path -Parent $Path) `
        ('.{0}.{1}.tmp' -f (
            [System.IO.Path]::GetFileName($Path)
        ), [guid]::NewGuid().ToString('N'))

    try {
        Set-Content `
            -LiteralPath $temporaryPath `
            -Value $Lines `
            -Encoding utf8
        Move-Item `
            -LiteralPath $temporaryPath `
            -Destination $Path `
            -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Update-ModStateFiles {
    param(
        [Parameter(Mandatory)]
        [string]$ModsDirectory,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Mods
    )

    Backup-ModStateFiles -ModsDirectory $ModsDirectory
    $textPath = Join-Path $ModsDirectory 'mods.txt'
    $jsonPath = Join-Path $ModsDirectory 'mods.json'
    $ordinaryTextLines = @(
        foreach ($mod in $Mods) {
            if (-not $mod.Pinned) {
                '{0} : {1}' -f (
                    $mod.Name
                ), $(if ($mod.Enabled) { 1 } else { 0 })
            }
        }
    )
    $pinnedTextLines = @(
        foreach ($mod in $Mods) {
            if ($mod.Pinned) {
                '{0} : 1' -f $mod.Name
            }
        }
    )
    $textLines = @($ordinaryTextLines)

    if ($pinnedTextLines.Count -gt 0) {
        $textLines += @(
            ''
            ''
            ''
            ''
            '; Built-in keybinds, do not move up!'
        )
        $textLines += $pinnedTextLines
    }

    $jsonRecords = @(
        foreach ($mod in $Mods) {
            [PSCustomObject]@{
                Name = [string]$mod.Name
                Enabled = [bool]$mod.Enabled
                Pinned = [bool]$mod.Pinned
            }
        }
    )
    $json = ConvertTo-Json -InputObject @($jsonRecords) -Depth 3

    # Validate serialized JSON before replacing either public state file.
    $null = $json | ConvertFrom-Json
    Set-AtomicTextFile -Path $textPath -Lines $textLines
    Set-AtomicTextFile -Path $jsonPath -Lines @($json)
    Write-ModManagerLog (
        "Refreshed mods.txt and mods.json with $($Mods.Count) mod(s)."
    )
}

function Get-ConsoleWidth {
    try {
        $width = $Host.UI.RawUI.WindowSize.Width

        if ($width -ge 20) {
            return $width
        }
    }
    catch {
        # Non-interactive hosts use the fallback width.
    }

    80
}

function Show-ModsGrid {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Mods
    )

    Write-Host ''

    if ($Mods.Count -eq 0) {
        Write-Host 'No mod folders found.' -ForegroundColor Yellow
        Write-Host ''
        return
    }

    $cellWidth = 34
    $columns = [math]::Max(
        1,
        [math]::Min(
            4,
            [math]::Min(
                $Mods.Count,
                [math]::Floor((Get-ConsoleWidth) / $cellWidth)
            )
        )
    )
    $rows = [math]::Ceiling($Mods.Count / $columns)

    for ($row = 0; $row -lt $rows; $row++) {
        for ($column = 0; $column -lt $columns; $column++) {
            $index = ($column * $rows) + $row

            if ($index -ge $Mods.Count) {
                continue
            }

            $mod = $Mods[$index]
            $state = if ($mod.Pinned) {
                'PIN'
            }
            elseif ($mod.Enabled) {
                'ON'
            }
            else {
                'OFF'
            }
            $availableNameWidth = [math]::Max(1, $cellWidth - 12)
            $displayName = [string]$mod.Name

            if ($displayName.Length -gt $availableNameWidth) {
                $displayName = $displayName.Substring(
                    0,
                    $availableNameWidth - 1
                ) + '…'
            }

            $text = '{0,3}. {1} [{2}]' -f (
                $index + 1
            ), $displayName, $state
            $color = if ($mod.Enabled) { 'Green' } else { 'DarkGray' }
            Write-Host `
                $text.PadRight($cellWidth) `
                -NoNewline `
                -ForegroundColor $color
        }

        Write-Host ''
    }

    Write-Host ''
}

function Toggle-Mod {
    param(
        [Parameter(Mandatory)]
        [object]$Mod
    )

    if ($Mod.Pinned) {
        throw "$($Mod.Name) is a required UE4SS built-in and cannot be toggled."
    }

    $disabledPath = Join-Path $Mod.Path 'disabled.txt'

    if ($Mod.Enabled) {
        New-Item `
            -Path $disabledPath `
            -ItemType File `
            -Force |
            Out-Null
        $Mod.Enabled = $false
        Write-ModManagerLog "Disabled mod: $($Mod.Name)"
    }
    else {
        if (Test-Path -LiteralPath $disabledPath -PathType Leaf) {
            Remove-Item -LiteralPath $disabledPath -Force
        }

        $Mod.Enabled = $true
        Write-ModManagerLog "Enabled mod: $($Mod.Name)"
    }
}

function Read-ModNumber {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter(Mandatory)]
        [int]$Maximum,

        [string]$InitialText = ''
    )

    $inputText = if ([string]::IsNullOrWhiteSpace($InitialText)) {
        Read-Host $Prompt
    }
    else {
        $additionalText = Read-Host "$Prompt [$InitialText]"

        if ([string]::IsNullOrWhiteSpace($additionalText)) {
            $InitialText
        }
        else {
            $InitialText + $additionalText
        }
    }
    $number = 0

    if (
        [int]::TryParse($inputText, [ref]$number) -and
        $number -ge 1 -and
        $number -le $Maximum
    ) {
        return $number
    }

    $null
}

function Move-Mod {
    param(
        [Parameter(Mandatory)]
        [object[]]$Mods,

        [Parameter(Mandatory)]
        [int]$Index,

        [Parameter(Mandatory)]
        [ValidateSet(-1, 1)]
        [int]$Direction
    )

    $target = $Index + $Direction

    if ($target -lt 0 -or $target -ge $Mods.Count) {
        return $false
    }

    if ($Mods[$Index].Pinned -or $Mods[$target].Pinned) {
        return $false
    }

    $temporary = $Mods[$target]
    $Mods[$target] = $Mods[$Index]
    $Mods[$Index] = $temporary
    $true
}

function Read-MenuKey {
    Write-Host ' [R]efresh  [T]oggle  Move [U]p/[D]own  [Q]uit'
    Write-Host ''

    try {
        $key = [Console]::ReadKey($true)
        [string]$key.KeyChar
    }
    catch {
        Read-Host 'Select an action'
    }
}

function Show-Menu {
    param(
        [Parameter(Mandatory)]
        [string]$ModsDirectory,

        [Parameter(Mandatory)]
        [object[]]$Mods,

        [string]$Message = ''
    )

    try {
        Clear-Host
    }
    catch {
        # Redirected and non-console hosts may not support screen clearing.
    }
    Write-Host '=== Lightweight UE4SS Mod Manager ===' -ForegroundColor Cyan
    Write-Host "Mods folder: $ModsDirectory" -ForegroundColor DarkCyan
    Write-Host 'Order shown below is the mods.txt load order.' `
        -ForegroundColor DarkCyan
    Show-ModsGrid -Mods $Mods

    if (-not [string]::IsNullOrWhiteSpace($Message)) {
        Write-Host $Message -ForegroundColor Yellow
        Write-Host ''
    }
}

$ModsDir = Resolve-ModsDirectory -Path $ModsDir
$script:LogFile = Join-Path $ModsDir 'modmanager.log'
$script:BackupDir = Join-Path $ModsDir 'backup'
$savedOrder = Get-SavedLoadOrder -ModsDirectory $ModsDir
$mods = @(Get-ModList -ModsDirectory $ModsDir -PreferredOrder $savedOrder)
$running = $true
$menuMessage = ''

Update-ModStateFiles -ModsDirectory $ModsDir -Mods $mods
Write-ModManagerLog "Script started. ModsDir = $ModsDir"

while ($running) {
    Show-Menu `
        -ModsDirectory $ModsDir `
        -Mods $mods `
        -Message $menuMessage
    $menuMessage = ''
    $selection = (Read-MenuKey).Trim()

    try {
        switch -Regex ($selection) {
            '^[Qq]$' {
                $running = $false
            }
            '^[Rr]$' {
                $currentOrder = @($mods | ForEach-Object Name)
                $mods = @(
                    Get-ModList `
                        -ModsDirectory $ModsDir `
                        -PreferredOrder $currentOrder
                )
                Update-ModStateFiles -ModsDirectory $ModsDir -Mods $mods
                $menuMessage = 'Mod list refreshed.'
            }
            '^[Tt]$' {
                if ($mods.Count -eq 0) {
                    $menuMessage = 'No mods are available to toggle.'
                    continue
                }

                $number = Read-ModNumber `
                    -Prompt 'Enter mod number to toggle' `
                    -Maximum $mods.Count

                if ($null -eq $number) {
                    $menuMessage = 'Invalid mod number.'
                    continue
                }

                Toggle-Mod -Mod $mods[$number - 1]
                Update-ModStateFiles -ModsDirectory $ModsDir -Mods $mods
                $menuMessage = "Toggled $($mods[$number - 1].Name)."
            }
            '^[UuDd]$' {
                if ($mods.Count -eq 0) {
                    $menuMessage = 'No mods are available to move.'
                    continue
                }

                $number = Read-ModNumber `
                    -Prompt 'Enter mod number to move' `
                    -Maximum $mods.Count

                if ($null -eq $number) {
                    $menuMessage = 'Invalid mod number.'
                    continue
                }

                $direction = if ($selection -match '^[Uu]$') { -1 } else { 1 }
                $name = $mods[$number - 1].Name

                if (Move-Mod `
                    -Mods $mods `
                    -Index ($number - 1) `
                    -Direction $direction
                ) {
                    Update-ModStateFiles -ModsDirectory $ModsDir -Mods $mods
                    $menuMessage = "Moved $name in the load order."
                }
                else {
                    $menuMessage = "$name is already at that edge."
                }
            }
            '^\d$' {
                if ($mods.Count -eq 0) {
                    $menuMessage = 'No mods are available to toggle.'
                    continue
                }

                $number = Read-ModNumber `
                    -Prompt 'Complete mod number, or press Enter' `
                    -Maximum $mods.Count `
                    -InitialText $selection

                if ($null -eq $number) {
                    $menuMessage = 'Invalid mod number.'
                    continue
                }

                Toggle-Mod -Mod $mods[$number - 1]
                Update-ModStateFiles -ModsDirectory $ModsDir -Mods $mods
                $menuMessage = "Toggled $($mods[$number - 1].Name)."
            }
            default {
                $menuMessage = 'Use R, T, U, D, Q, or a mod number.'
            }
        }
    }
    catch {
        $menuMessage = "Action failed: $($_.Exception.Message)"
        Write-ModManagerLog $menuMessage
    }
}

Write-ModManagerLog 'Script exited.'
