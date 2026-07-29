<#
.SYNOPSIS
    Provides safe mod archive intake and library promotion.
.DESCRIPTION
    Inspects ZIP archives without extraction, stages validated packages, verifies
    staged content, and promotes approved packages into the mod library and
    deployment output.
#>

Set-StrictMode -Version Latest

function Get-Pw7ZipExecutable {

    [CmdletBinding()]
    param()

    $configuration = Get-PwWorkshopConfig
    $configuredPath = ''

    if (
        $configuration.Tools.PSObject.Properties['SevenZip'] -and
        $configuration.Tools.SevenZip.PSObject.Properties['Path']
    ) {
        $configuredPath = [System.Environment]::ExpandEnvironmentVariables(
            $configuration.Tools.SevenZip.Path
        )
    }

    $candidates = [System.Collections.Generic.List[string]]::new()

    if (-not [string]::IsNullOrWhiteSpace($configuredPath)) {
        $candidates.Add($configuredPath)
    }

    foreach ($registryPath in @(
        'HKLM:\SOFTWARE\7-Zip',
        'HKLM:\SOFTWARE\WOW6432Node\7-Zip',
        'HKCU:\SOFTWARE\7-Zip'
    )) {
        $registration = Get-ItemProperty `
            -Path $registryPath `
            -ErrorAction SilentlyContinue

        if ($registration -and $registration.Path) {
            $candidates.Add((Join-Path $registration.Path '7z.exe'))
        }
    }

    $command = Get-Command 7z -ErrorAction SilentlyContinue

    if ($command) {
        $candidates.Add($command.Source)
    }

    $candidates.Add('C:\Program Files\7-Zip\7z.exe')
    $candidates.Add('C:\Program Files (x86)\7-Zip\7z.exe')

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw '7-Zip command-line executable was not found.'
}

function Test-PwModIdentifier {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    $Value -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'
}

function Get-PwModPackageRoot {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Staging', 'ModLibrary')]
        [string]$Area,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Version
    )

    foreach ($value in @($Name, $Version)) {
        if (-not (Test-PwModIdentifier -Value $value)) {
            throw "Invalid mod identifier '$value'."
        }
    }

    $areaRoot = (Get-PwPaths).$Area

    if ($Area -eq 'ModLibrary') {
        return Join-Path $areaRoot "$Name-$Version"
    }

    Join-Path (Join-Path $areaRoot $Name) $Version
}

function Test-PwArchiveEntryPath {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.Contains("`0")) {
        return $false
    }

    $normalized = $Path.Replace('\', '/')

    if (
        $normalized.StartsWith('/') -or
        $normalized.Contains(':')
    ) {
        return $false
    }

    foreach ($segment in $normalized.Split('/')) {
        if (
            $segment -in @('', '.', '..') -or
            $segment.EndsWith('.') -or
            $segment.EndsWith(' ') -or
            $segment -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$' -or
            $segment.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0
        ) {
            return $false
        }
    }

    $true
}

function Get-PwModEntryCategory {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()

    switch ($extension) {
        { $_ -in @('.pak', '.utoc', '.ucas') } {
            return 'Pak'
        }
        '.lua' {
            return 'Lua'
        }
        '.dll' {
            return 'Native'
        }
        { $_ -in @('.json', '.ini', '.cfg', '.toml', '.yaml', '.yml') } {
            return 'Configuration'
        }
        { $_ -in @('.md', '.txt', '.pdf', '.png', '.jpg', '.jpeg') } {
            return 'Documentation'
        }
        default {
            return 'Other'
        }
    }
}

function Test-PwDeploymentRelativePath {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $normalized = $Path.Replace('\', '/')

    (
        (Test-PwArchiveEntryPath -Path $normalized) -and
        $normalized.StartsWith(
            'Pal/',
            [System.StringComparison]::OrdinalIgnoreCase
        )
    )
}

function Get-PwModDeploymentRelativePath {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Category
    )

    $normalized = $Path.Replace('\', '/').TrimStart([char[]]@('.', '/'))
    $palIndex = $normalized.IndexOf(
        'Pal/',
        [System.StringComparison]::OrdinalIgnoreCase
    )

    if ($palIndex -ge 0) {
        return $normalized.Substring($palIndex).Replace('/', '\')
    }

    if ($normalized.StartsWith(
        'Content/',
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        return "Pal\$($normalized.Replace('/', '\'))"
    }

    if ($normalized.StartsWith(
        'ue4ss/Mods/',
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        return "Pal\Binaries\Win64\$($normalized.Replace('/', '\'))"
    }

    if ($normalized.StartsWith(
        '~mods/',
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        return "Pal\Content\Paks\$($normalized.Replace('/', '\'))"
    }

    if ($normalized.StartsWith(
        'LogicMods/',
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        return "Pal\Content\Paks\$($normalized.Replace('/', '\'))"
    }

    if ($Category -eq 'Pak' -and -not $normalized.Contains('/')) {
        return "Pal\Content\Paks\~mods\$normalized"
    }

    # UE4SS archives commonly contain only <ModName>\Scripts rather than the
    # complete game-relative path. Preserve that accepted folder name while
    # normalizing the package into the live UE4SS Mods layout.
    $segments = @(
        $normalized.Split(
            '/',
            [System.StringSplitOptions]::RemoveEmptyEntries
        )
    )
    if (
        $segments.Count -ge 2 -and
        (
            $Category -in @('Lua', 'Native') -or
            (
                $segments.Count -eq 2 -and
                $segments[1] -match '^(?i:enabled|disabled)\.txt$'
            )
        )
    ) {
        return (
            "Pal\Binaries\Win64\ue4ss\Mods\" +
                $normalized.Replace('/', '\')
        )
    }

    $null
}

function Get-PwModStagingRelativePath {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Entry
    )

    if (
        -not [string]::IsNullOrWhiteSpace(
            [string]$Entry.DeploymentRelativePath
        )
    ) {
        return [string]$Entry.DeploymentRelativePath
    }

    # Keep review-only material available without pretending it has a safe
    # game destination.
    Join-Path '_Review' $Entry.ArchivePath.Replace('/', '\')
}

function Get-PwStreamHash {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.IO.Stream]$Stream
    )

    $algorithm = [System.Security.Cryptography.SHA256]::Create()

    try {
        [System.Convert]::ToHexString($algorithm.ComputeHash($Stream))
    }
    finally {
        $algorithm.Dispose()
    }
}

function Get-Pw7ZipArchiveRecords {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $sevenZip = Get-Pw7ZipExecutable
    $output = @(& $sevenZip l -slt -ba -- $Path 2>&1)

    if ($LASTEXITCODE -ne 0) {
        throw "7-Zip could not inspect '$Path': $($output -join ' ')"
    }

    $records = [System.Collections.Generic.List[object]]::new()
    $record = [ordered]@{}

    foreach ($line in $output) {
        $text = [string]$line

        if ([string]::IsNullOrWhiteSpace($text)) {
            if ($record.Count -gt 0) {
                $records.Add([PSCustomObject]$record)
                $record = [ordered]@{}
            }

            continue
        }

        if ($text -match '^([^=]+?) = (.*)$') {
            $record[$matches[1].Trim()] = $matches[2]
        }
    }

    if ($record.Count -gt 0) {
        $records.Add([PSCustomObject]$record)
    }

    @($records)
}

function Get-Pw7ZipArchiveInfo {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $records = Get-Pw7ZipArchiveRecords -Path $Path
    $entries = [System.Collections.Generic.List[object]]::new()
    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $seenPaths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $fileRecords = @(
        $records |
            Where-Object {
                $_.PSObject.Properties['Path'] -and
                (
                    -not $_.PSObject.Properties['Attributes'] -or
                    $_.Attributes -notmatch 'D'
                )
            }
    )
    $totalUncompressedBytes = (
        $fileRecords |
            ForEach-Object { [long]$_.Size } |
            Measure-Object -Sum
    ).Sum
    $archiveLimitExceeded = $false

    if ($records.Count -gt 10000) {
        $errors.Add('Archive contains more than 10,000 entries.')
        $archiveLimitExceeded = $true
    }

    if ($totalUncompressedBytes -gt 5GB) {
        $errors.Add('Archive expands beyond the 5 GB intake safety limit.')
        $archiveLimitExceeded = $true
    }

    foreach ($record in $records) {
        if (-not $record.PSObject.Properties['Path']) {
            continue
        }

        $entryPath = $record.Path.Replace('\', '/').TrimEnd('/')
        $attributes = if ($record.PSObject.Properties['Attributes']) {
            [string]$record.Attributes
        }
        else {
            ''
        }
        $isDirectory = $attributes -match 'D'
        $pathSafe = Test-PwArchiveEntryPath -Path $entryPath
        $category = if ($isDirectory) {
            'Directory'
        }
        else {
            Get-PwModEntryCategory -Path $entryPath
        }
        $reviewRequired = $category -in @('Native', 'Other')
        $entryErrors = @()
        $entryWarnings = @()

        if (-not $pathSafe) {
            $entryErrors += 'Unsafe archive entry path.'
            $errors.Add("Unsafe archive entry path: $entryPath")
        }

        if (-not $seenPaths.Add($entryPath)) {
            $entryErrors += 'Duplicate archive entry path.'
            $errors.Add("Duplicate archive entry path: $entryPath")
        }

        if (
            $record.PSObject.Properties['Encrypted'] -and
            $record.Encrypted -eq '+'
        ) {
            $entryErrors += 'Encrypted archive entry.'
            $errors.Add("Encrypted archive entry is not supported: $entryPath")
        }

        if (
            $record.PSObject.Properties['Symbolic Link'] -or
            $record.PSObject.Properties['Hard Link']
        ) {
            $entryErrors += 'Archive link entry.'
            $errors.Add("Archive link entry is not supported: $entryPath")
        }

        if ($reviewRequired) {
            $entryWarnings += "Category '$category' requires review."
        }

        $deploymentPath = if ($isDirectory) {
            $null
        }
        else {
            Get-PwModDeploymentRelativePath `
                -Path $entryPath `
                -Category $category
        }
        $length = if ($record.PSObject.Properties['Size']) {
            [long]$record.Size
        }
        else {
            0
        }
        $packedLength = if (
            $record.PSObject.Properties['Packed Size'] -and
            -not [string]::IsNullOrWhiteSpace($record.'Packed Size')
        ) {
            [long]$record.'Packed Size'
        }
        else {
            0
        }

        $entries.Add([PSCustomObject]@{
            ArchivePath = $entryPath
            IsDirectory = $isDirectory
            PathSafe = $pathSafe
            Length = $length
            CompressedLength = $packedLength
            Hash = ''
            Category = $category
            DeploymentRelativePath = $deploymentPath
            ReviewRequired = $reviewRequired
            Errors = $entryErrors
            Warnings = $entryWarnings
        })
    }

    $fileEntries = @($entries | Where-Object { -not $_.IsDirectory })

    if (@($fileEntries | Where-Object ReviewRequired).Count -gt 0) {
        $warnings.Add('Archive contains native or unclassified files.')
    }

    [PSCustomObject]@{
        Path = $Path
        Format = '7Z'
        Supported = $true
        IsSafe = ($errors.Count -eq 0 -and -not $archiveLimitExceeded)
        RequiresReview = @(
            $fileEntries |
                Where-Object ReviewRequired
        ).Count -gt 0
        ArchiveHash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        FileCount = $fileEntries.Count
        TotalUncompressedBytes = $totalUncompressedBytes
        Categories = @(
            $fileEntries |
                Select-Object -ExpandProperty Category -Unique |
                Sort-Object
        )
        Entries = @($entries)
        Errors = @($errors)
        Warnings = @($warnings)
    }
}

function Get-PwModArchiveInfoInternal {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $extension = [System.IO.Path]::GetExtension($resolvedPath).ToLowerInvariant()

    if ($extension -eq '.7z') {
        return Get-Pw7ZipArchiveInfo -Path $resolvedPath
    }

    if ($extension -ne '.zip') {
        return [PSCustomObject]@{
            Path = $resolvedPath
            Format = $extension.TrimStart('.').ToUpperInvariant()
            Supported = $false
            IsSafe = $false
            RequiresReview = $true
            ArchiveHash = (Get-FileHash -LiteralPath $resolvedPath).Hash
            Entries = @()
            Errors = @("Archive format '$extension' is not supported for intake.")
            Warnings = @('Install 7-Zip support in a later sprint for this format.')
        }
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedPath)
    $entries = [System.Collections.Generic.List[object]]::new()
    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $seenPaths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    try {
        $archiveFileEntries = @(
            $archive.Entries |
                Where-Object { -not $_.FullName.Replace('\', '/').EndsWith('/') }
        )
        $totalUncompressedBytes = (
            $archiveFileEntries |
                Measure-Object -Property Length -Sum
        ).Sum
        $archiveLimitExceeded = $false

        if ($archive.Entries.Count -gt 10000) {
            $errors.Add('Archive contains more than 10,000 entries.')
            $archiveLimitExceeded = $true
        }

        if ($totalUncompressedBytes -gt 5GB) {
            $errors.Add('Archive expands beyond the 5 GB intake safety limit.')
            $archiveLimitExceeded = $true
        }

        foreach ($entry in $archive.Entries) {
            $rawEntryPath = $entry.FullName.Replace('\', '/')
            $isDirectory = $rawEntryPath.EndsWith('/')
            $entryPath = $rawEntryPath.TrimEnd('/')
            $pathSafe = Test-PwArchiveEntryPath -Path $entryPath
            $category = if ($isDirectory) {
                'Directory'
            }
            else {
                Get-PwModEntryCategory -Path $entryPath
            }
            $reviewRequired = $category -in @('Native', 'Other')
            $entryErrors = @()
            $entryWarnings = @()

            if (-not $pathSafe) {
                $entryErrors += 'Unsafe archive entry path.'
                $errors.Add("Unsafe archive entry path: $entryPath")
            }

            if (-not $seenPaths.Add($entryPath)) {
                $entryErrors += 'Duplicate archive entry path.'
                $errors.Add("Duplicate archive entry path: $entryPath")
            }

            if (
                -not $isDirectory -and
                $entry.Length -gt 0 -and
                $entry.CompressedLength -eq 0
            ) {
                $entryErrors += 'Invalid compressed size.'
                $errors.Add("Invalid compressed size: $entryPath")
            }
            elseif (
                -not $isDirectory -and
                $entry.CompressedLength -gt 0 -and
                $entry.Length -gt 104857600 -and
                ($entry.Length / $entry.CompressedLength) -gt 1000
            ) {
                $entryErrors += 'Suspicious compression ratio.'
                $errors.Add("Suspicious compression ratio: $entryPath")
            }

            if ($reviewRequired) {
                $entryWarnings += "Category '$category' requires review."
            }

            $hash = ''

            if (
                -not $isDirectory -and
                $pathSafe -and
                $entryErrors.Count -eq 0 -and
                -not $archiveLimitExceeded
            ) {
                try {
                    $stream = $entry.Open()

                    try {
                        $hash = Get-PwStreamHash -Stream $stream
                    }
                    finally {
                        $stream.Dispose()
                    }
                }
                catch {
                    $entryErrors += 'Entry content could not be read.'
                    $errors.Add(
                        "Archive entry could not be read: $entryPath. " +
                            $_.Exception.Message
                    )
                }
            }

            $deploymentPath = if ($isDirectory) {
                $null
            }
            else {
                Get-PwModDeploymentRelativePath `
                    -Path $entryPath `
                    -Category $category
            }

            $entries.Add([PSCustomObject]@{
                ArchivePath = $entryPath
                IsDirectory = $isDirectory
                PathSafe = $pathSafe
                Length = $entry.Length
                CompressedLength = $entry.CompressedLength
                Hash = $hash
                Category = $category
                DeploymentRelativePath = $deploymentPath
                ReviewRequired = $reviewRequired
                Errors = $entryErrors
                Warnings = $entryWarnings
            })
        }
    }
    finally {
        $archive.Dispose()
    }

    $fileEntries = @($entries | Where-Object { -not $_.IsDirectory })

    if (@($fileEntries | Where-Object ReviewRequired).Count -gt 0) {
        $warnings.Add('Archive contains native or unclassified files.')
    }

    $categories = @(
        $fileEntries |
            Select-Object -ExpandProperty Category -Unique |
            Sort-Object
    )

    [PSCustomObject]@{
        Path = $resolvedPath
        Format = 'ZIP'
        Supported = $true
        IsSafe = ($errors.Count -eq 0)
        RequiresReview = @(
            $fileEntries |
                Where-Object ReviewRequired
        ).Count -gt 0
        ArchiveHash = (
            Get-FileHash -LiteralPath $resolvedPath -Algorithm SHA256
        ).Hash
        FileCount = $fileEntries.Count
        TotalUncompressedBytes = $totalUncompressedBytes
        Categories = $categories
        Entries = @($entries)
        Errors = @($errors)
        Warnings = @($warnings)
    }
}

<#
.SYNOPSIS
    Inspects a mod archive without extracting it.
.PARAMETER Path
    Path to a downloaded mod archive.
.OUTPUTS
    PSCustomObject describing archive safety, contents, hashes, and mappings.
#>
function Get-PwModArchiveInfo {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    Get-PwModArchiveInfoInternal -Path $Path
}

function Expand-PwSafeZipArchive {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$DestinationRoot,

        [Parameter(Mandatory)]
        [object]$Inspection
    )

    $resolvedDestination = [System.IO.Path]::GetFullPath($DestinationRoot)
    $destinationPrefix = $resolvedDestination.TrimEnd('\') + '\'
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)

    try {
        foreach ($entry in $archive.Entries) {
            if ($entry.FullName.EndsWith('/')) {
                continue
            }

            $inspectionEntry = $Inspection.Entries |
                Where-Object ArchivePath -eq $entry.FullName.Replace('\', '/') |
                Select-Object -First 1

            if ($null -eq $inspectionEntry -or -not $inspectionEntry.PathSafe) {
                throw "Archive entry was not approved for extraction: $($entry.FullName)"
            }

            $relativePath = $entry.FullName.Replace('/', '\')
            $destinationPath = [System.IO.Path]::GetFullPath(
                (Join-Path $resolvedDestination $relativePath)
            )

            if (-not $destinationPath.StartsWith(
                $destinationPrefix,
                [System.StringComparison]::OrdinalIgnoreCase
            )) {
                throw "Archive entry escaped the staging root: $($entry.FullName)"
            }

            $destinationDirectory = Split-Path -Parent $destinationPath
            New-Item `
                -ItemType Directory `
                -Path $destinationDirectory `
                -Force |
                Out-Null
            $inputStream = $entry.Open()
            $outputStream = [System.IO.File]::Create($destinationPath)

            try {
                $inputStream.CopyTo($outputStream)
            }
            finally {
                $outputStream.Dispose()
                $inputStream.Dispose()
            }

            $extractedHash = (
                Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256
            ).Hash

            if ($extractedHash -ne $inspectionEntry.Hash) {
                throw "Extracted file hash verification failed: $relativePath"
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}

function Expand-PwSafe7ZipArchive {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$DestinationRoot,

        [Parameter(Mandatory)]
        [object]$Inspection
    )

    $sevenZip = Get-Pw7ZipExecutable
    $output = @(
        & $sevenZip x -y "-o$DestinationRoot" -- $Path 2>&1
    )

    if ($LASTEXITCODE -ne 0) {
        throw "7-Zip extraction failed: $($output -join ' ')"
    }

    $expectedPaths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($entry in $Inspection.Entries | Where-Object { -not $_.IsDirectory }) {
        $expectedPaths.Add($entry.ArchivePath) | Out-Null
    }

    $actualPaths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    Get-ChildItem -LiteralPath $DestinationRoot -File -Recurse |
        ForEach-Object {
            if ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                throw "Extracted reparse point is not allowed: $($_.FullName)"
            }

            $relativePath = [System.IO.Path]::GetRelativePath(
                $DestinationRoot,
                $_.FullName
            ).Replace('\', '/')

            if (-not $expectedPaths.Contains($relativePath)) {
                throw "7-Zip extracted an unexpected file: $relativePath"
            }

            $actualPaths.Add($relativePath) | Out-Null
        }

    foreach ($expectedPath in $expectedPaths) {
        if (-not $actualPaths.Contains($expectedPath)) {
            throw "7-Zip did not extract an expected file: $expectedPath"
        }
    }
}

function Expand-PwSafeModArchive {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Inspection,

        [Parameter(Mandatory)]
        [string]$DestinationRoot
    )

    switch ($Inspection.Format) {
        'ZIP' {
            Expand-PwSafeZipArchive `
                -Path $Inspection.Path `
                -DestinationRoot $DestinationRoot `
                -Inspection $Inspection
        }
        '7Z' {
            Expand-PwSafe7ZipArchive `
                -Path $Inspection.Path `
                -DestinationRoot $DestinationRoot `
                -Inspection $Inspection
        }
        default {
            throw "Unsupported archive format '$($Inspection.Format)'."
        }
    }
}

function New-Pw7ZipArchive {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    $sevenZip = Get-Pw7ZipExecutable

    if (Test-Path -LiteralPath $DestinationPath) {
        throw "Refusing to replace an existing 7-Zip archive: $DestinationPath"
    }

    $destinationDirectory = Split-Path -Parent $DestinationPath
    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    $previousLocation = Get-Location

    try {
        Set-Location -LiteralPath $SourceRoot
        $output = @(
            & $sevenZip a -t7z -mx=9 -mmt=on -- $DestinationPath '.' 2>&1
        )

        if ($LASTEXITCODE -ne 0) {
            throw "7-Zip archive creation failed: $($output -join ' ')"
        }
    }
    finally {
        Set-Location -LiteralPath $previousLocation
    }

    if (-not (Test-Path -LiteralPath $DestinationPath -PathType Leaf)) {
        throw "7-Zip did not create the expected archive: $DestinationPath"
    }

    (Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256).Hash
}

<#
.SYNOPSIS
    Imports a validated ZIP or 7z archive into the workshop staging area.
.PARAMETER Path
    Path to the original downloaded ZIP or 7z archive.
.PARAMETER Name
    Stable mod identifier.
.PARAMETER Version
    Mod version identifier.
.PARAMETER Author
    Mod author or publisher.
.PARAMETER SourceUri
    Original download or project URL.
.OUTPUTS
    PSCustomObject containing the staged package paths and manifest.
#>
function Import-PwModArchive {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Version,

        [string]$Author = '',

        [uri]$SourceUri
    )

    $inspection = Get-PwModArchiveInfo -Path $Path

    if (-not $inspection.Supported -or -not $inspection.IsSafe) {
        throw "Archive cannot be staged: $($inspection.Errors -join ' ')"
    }

    $packageRoot = Get-PwModPackageRoot `
        -Area Staging `
        -Name $Name `
        -Version $Version

    if (Test-Path -LiteralPath $packageRoot) {
        throw "Staged package already exists: $packageRoot"
    }

    $archiveRoot = Join-Path (
        Join-Path (Get-PwPaths).Archives $Name
    ) $Version
    $archivePath = Join-Path $archiveRoot (
        Split-Path -Leaf $inspection.Path
    )
    $sourceRoot = Join-Path $packageRoot 'Source'
    $extractedRoot = Join-Path $packageRoot '_Extracted'
    $manifestPath = Join-Path $packageRoot 'manifest.json'
    $sourceUriValue = if ($null -eq $SourceUri) {
        ''
    }
    else {
        $SourceUri.AbsoluteUri
    }
    if ($PSCmdlet.ShouldProcess(
        $packageRoot,
        "Archive and stage mod '$Name' version '$Version'"
    )) {
        New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $extractedRoot -Force | Out-Null
        Copy-Item `
            -LiteralPath $inspection.Path `
            -Destination $archivePath `
            -ErrorAction Stop
        Expand-PwSafeModArchive `
            -Inspection $inspection `
            -DestinationRoot $extractedRoot
        $manifestEntries = @(
            foreach ($entry in $inspection.Entries) {
                if ($entry.IsDirectory) {
                    continue
                }

                $extractedPath = Join-Path $extractedRoot (
                    $entry.ArchivePath.Replace('/', '\')
                )
                $extractedHash = (
                    Get-FileHash -LiteralPath $extractedPath -Algorithm SHA256
                ).Hash

                if (
                    -not [string]::IsNullOrWhiteSpace($entry.Hash) -and
                    $entry.Hash -ne $extractedHash
                ) {
                    throw "Staged file hash verification failed: " +
                        $entry.ArchivePath
                }

                $stagedRelativePath = Get-PwModStagingRelativePath `
                    -Entry $entry
                $stagedRelativePath = $stagedRelativePath.Replace('\', '/')
                $stagedPath = Join-Path $sourceRoot $stagedRelativePath
                $stagedDirectory = Split-Path -Parent $stagedPath
                New-Item `
                    -ItemType Directory `
                    -Path $stagedDirectory `
                    -Force |
                    Out-Null

                if (Test-Path -LiteralPath $stagedPath) {
                    throw (
                        'Multiple archive files normalize to the same staging ' +
                            "path: $stagedRelativePath"
                    )
                }

                Copy-Item `
                    -LiteralPath $extractedPath `
                    -Destination $stagedPath `
                    -ErrorAction Stop

                [PSCustomObject]@{
                    ArchivePath = $entry.ArchivePath
                    StagedRelativePath = $stagedRelativePath
                    Length = $entry.Length
                    Hash = $extractedHash
                    Category = $entry.Category
                    DeploymentRelativePath = $entry.DeploymentRelativePath
                    ReviewRequired = $entry.ReviewRequired
                }
            }
        )
        Remove-Item -LiteralPath $extractedRoot -Recurse -Force
        $stagingArchivePath = Join-Path $packageRoot 'package.7z'
        $stagingArchiveHash = New-Pw7ZipArchive `
            -SourceRoot $sourceRoot `
            -DestinationPath $stagingArchivePath
        $manifest = [PSCustomObject]@{
            SchemaVersion = '1.1'
            Name = $Name
            Version = $Version
            Author = $Author
            SourceUri = $sourceUriValue
            ImportedAt = Get-Date
            OriginalArchive = [System.IO.Path]::GetRelativePath(
                (Get-PwPaths).Root,
                $archivePath
            )
            OriginalFormat = $inspection.Format
            ArchiveHash = $inspection.ArchiveHash
            PackageArchive = 'package.7z'
            PackageArchiveHash = $stagingArchiveHash
            RequiresReview = $inspection.RequiresReview
            Categories = $inspection.Categories
            Entries = $manifestEntries
        }
        Write-PwJson -InputObject $manifest -Path $manifestPath
    }

    [PSCustomObject]@{
        Name = $Name
        Version = $Version
        Staged = Test-Path -LiteralPath $manifestPath -PathType Leaf
        PackageRoot = $packageRoot
        SourceRoot = $sourceRoot
        ManifestPath = $manifestPath
        OriginalArchive = $archivePath
        PackageArchive = Join-Path $packageRoot 'package.7z'
        RequiresReview = $inspection.RequiresReview
        FileCount = $inspection.FileCount
    }
}

<#
.SYNOPSIS
    Validates a staged or curated mod package.
.PARAMETER Name
    Mod identifier.
.PARAMETER Version
    Mod version identifier.
.PARAMETER Area
    Package area to validate.
.OUTPUTS
    PSCustomObject containing validity, review state, errors, and warnings.
#>
function Test-PwModPackage {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Version,

        [ValidateSet('Staging', 'ModLibrary')]
        [string]$Area = 'Staging'
    )

    $packageRoot = Get-PwModPackageRoot `
        -Area $Area `
        -Name $Name `
        -Version $Version
    $manifestPath = Join-Path $packageRoot 'manifest.json'
    $sourceRoot = Join-Path $packageRoot 'Source'
    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $manifest = $null

    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        $errors.Add("Package manifest not found: $manifestPath")
    }
    else {
        try {
            $manifest = Read-PwJson -Path $manifestPath
        }
        catch {
            $errors.Add($_.Exception.Message)
        }
    }

    if ($null -ne $manifest) {
        foreach ($property in @(
            'SchemaVersion',
            'Name',
            'Version',
            'ArchiveHash',
            'PackageArchive',
            'PackageArchiveHash',
            'RequiresReview',
            'Entries'
        )) {
            if (-not $manifest.PSObject.Properties[$property]) {
                $errors.Add("Missing manifest property '$property'.")
            }
        }
    }

    if ($errors.Count -eq 0) {
        if ($manifest.SchemaVersion -notin @('1.0', '1.1')) {
            $errors.Add("Unsupported manifest schema '$($manifest.SchemaVersion)'.")
        }

        if ($manifest.Name -ne $Name -or $manifest.Version -ne $Version) {
            $errors.Add('Manifest identity does not match its package path.')
        }

        $manifestPaths = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )

        foreach ($entry in $manifest.Entries) {
            $entryMissingProperty = $false

            foreach ($property in @(
                'ArchivePath',
                'Length',
                'Hash',
                'Category',
                'DeploymentRelativePath',
                'ReviewRequired'
            )) {
                if (-not $entry.PSObject.Properties[$property]) {
                    $errors.Add("Manifest entry is missing property '$property'.")
                    $entryMissingProperty = $true
                }
            }

            if ($entryMissingProperty) {
                continue
            }

            $stagedRelativePath = if (
                $entry.PSObject.Properties['StagedRelativePath'] -and
                -not [string]::IsNullOrWhiteSpace(
                    [string]$entry.StagedRelativePath
                )
            ) {
                [string]$entry.StagedRelativePath
            }
            else {
                [string]$entry.ArchivePath
            }

            if (-not (Test-PwArchiveEntryPath -Path $entry.ArchivePath)) {
                $errors.Add("Unsafe manifest entry path: $($entry.ArchivePath)")
                continue
            }

            if (-not (Test-PwArchiveEntryPath -Path $stagedRelativePath)) {
                $errors.Add(
                    "Unsafe staged entry path: $stagedRelativePath"
                )
                continue
            }

            if (-not $manifestPaths.Add($stagedRelativePath)) {
                $errors.Add(
                    "Duplicate staged entry path: $stagedRelativePath"
                )
            }

            if (
                -not [string]::IsNullOrWhiteSpace(
                    $entry.DeploymentRelativePath
                ) -and
                -not (
                    Test-PwDeploymentRelativePath `
                        -Path $entry.DeploymentRelativePath
                )
            ) {
                $errors.Add(
                    "Unsafe deployment mapping: $($entry.DeploymentRelativePath)"
                )
            }

            if ($Area -eq 'Staging') {
                $filePath = Join-Path $sourceRoot (
                    $stagedRelativePath.Replace('/', '\')
                )

                if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                    $errors.Add("Package file not found: $stagedRelativePath")
                    continue
                }

                $hash = (
                    Get-FileHash -LiteralPath $filePath -Algorithm SHA256
                ).Hash

                if ($hash -ne $entry.Hash) {
                    $errors.Add("Package file hash mismatch: $stagedRelativePath")
                }
            }
        }

        if (
            $Area -eq 'Staging' -and
            (Test-Path -LiteralPath $sourceRoot -PathType Container)
        ) {
            Get-ChildItem -LiteralPath $sourceRoot -File -Recurse |
                ForEach-Object {
                    $relativePath = [System.IO.Path]::GetRelativePath(
                        $sourceRoot,
                        $_.FullName
                    ).Replace('\', '/')

                    if (-not $manifestPaths.Contains($relativePath)) {
                        $errors.Add("Package contains an unlisted file: $relativePath")
                    }
                }
        }

        $packageArchive = Join-Path $packageRoot $manifest.PackageArchive

        if (-not (
            Test-Path -LiteralPath $packageArchive -PathType Leaf
        )) {
            $errors.Add("Normalized package archive not found: $packageArchive")
        }
        else {
            $packageHash = (
                Get-FileHash `
                    -LiteralPath $packageArchive `
                    -Algorithm SHA256
            ).Hash

            if ($packageHash -ne $manifest.PackageArchiveHash) {
                $errors.Add('Normalized package hash does not match manifest.')
            }

            $packageInspection = Get-PwModArchiveInfo -Path $packageArchive

            if (-not $packageInspection.IsSafe) {
                $errors.Add('Normalized package did not pass safety inspection.')
            }

            $packagePaths = @(
                $packageInspection.Entries |
                    Where-Object { -not $_.IsDirectory } |
                    Select-Object -ExpandProperty ArchivePath
            )

            foreach ($manifestPathValue in $manifestPaths) {
                if ($packagePaths -notcontains $manifestPathValue) {
                    $errors.Add(
                        "Normalized package is missing: $manifestPathValue"
                    )
                }
            }

            foreach ($packagePathValue in $packagePaths) {
                if (-not $manifestPaths.Contains($packagePathValue)) {
                    $errors.Add(
                        "Normalized package contains an unlisted file: " +
                            $packagePathValue
                    )
                }
            }
        }

        if ($manifest.RequiresReview) {
            $warnings.Add('Package contains files that require explicit review.')
        }
    }

    [PSCustomObject]@{
        Name = $Name
        Version = $Version
        Area = $Area
        PackageRoot = $packageRoot
        ManifestPath = $manifestPath
        IsValid = ($errors.Count -eq 0)
        RequiresReview = (
            $null -ne $manifest -and
            $manifest.PSObject.Properties['RequiresReview'] -and
            $manifest.RequiresReview
        )
        Errors = @($errors)
        Warnings = @($warnings)
    }
}

function New-PwModPublishPlan {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Version
    )

    $validation = Test-PwModPackage -Name $Name -Version $Version

    if (-not $validation.IsValid) {
        throw "Staged package is invalid: $($validation.Errors -join ' ')"
    }

    $stagingRoot = $validation.PackageRoot
    $libraryRoot = Get-PwModPackageRoot `
        -Area ModLibrary `
        -Name $Name `
        -Version $Version
    $manifest = Read-PwJson -Path $validation.ManifestPath
    $deploymentRoot = (Get-PwPaths).Deployment
    $deploymentFiles = @(
        foreach ($entry in $manifest.Entries) {
            if ([string]::IsNullOrWhiteSpace($entry.DeploymentRelativePath)) {
                continue
            }

            $stagedPathValue = if (
                $entry.PSObject.Properties['StagedRelativePath'] -and
                -not [string]::IsNullOrWhiteSpace(
                    [string]$entry.StagedRelativePath
                )
            ) {
                $entry.StagedRelativePath.Replace('/', '\')
            }
            else {
                $entry.ArchivePath.Replace('/', '\')
            }
            $sourcePath = Join-Path (
                Join-Path $stagingRoot 'Source'
            ) $stagedPathValue
            $destinationPath = Join-Path `
                $deploymentRoot `
                $entry.DeploymentRelativePath
            $action = 'Create'
            $destinationHash = ''

            if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
                $destinationHash = (
                    Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256
                ).Hash
                $action = if ($destinationHash -eq $entry.Hash) {
                    'Unchanged'
                }
                else {
                    'Conflict'
                }
            }

            [PSCustomObject]@{
                ArchivePath = $entry.ArchivePath
                SourcePath = $sourcePath
                DestinationPath = $destinationPath
                DeploymentRelativePath = $entry.DeploymentRelativePath
                Hash = $entry.Hash
                DestinationHash = $destinationHash
                Action = $action
            }
        }
    )

    [PSCustomObject]@{
        Name = $Name
        Version = $Version
        StagingRoot = $stagingRoot
        LibraryRoot = $libraryRoot
        RequiresReview = $validation.RequiresReview
        DeploymentFiles = $deploymentFiles
        DeployableCount = @(
            $deploymentFiles |
                Where-Object Action -in @('Create', 'Unchanged')
        ).Count
        ConflictCount = @(
            $deploymentFiles |
                Where-Object Action -eq 'Conflict'
        ).Count
        CanPublish = (
            -not (Test-Path -LiteralPath $libraryRoot) -and
            @($deploymentFiles | Where-Object Action -eq 'Conflict').Count -eq 0
        )
    }
}

<#
.SYNOPSIS
    Previews or applies promotion of a staged mod into the curated library.
.DESCRIPTION
    Preview is the default. Applying copies the validated staged package into the
    mod library and copies mapped files into workshop deployment output. It never
    writes to the live Palworld installation.
.PARAMETER Name
    Mod identifier.
.PARAMETER Version
    Mod version identifier.
.PARAMETER Apply
    Explicitly enables writes to the library and deployment output.
.PARAMETER AllowReviewRequired
    Confirms that native or unclassified files have been manually reviewed.
.OUTPUTS
    Publish plan in preview mode or PSCustomObject result in apply mode.
#>
function Publish-PwModPackage {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Version,

        [switch]$Apply,

        [switch]$AllowReviewRequired
    )

    $plan = New-PwModPublishPlan -Name $Name -Version $Version

    if (-not $Apply) {
        return $plan
    }

    if (-not $plan.CanPublish) {
        throw 'Package cannot be published because the library version exists or ' +
            'deployment conflicts were detected.'
    }

    if ($plan.RequiresReview -and -not $AllowReviewRequired) {
        throw 'Package requires manual review. Use -AllowReviewRequired after review.'
    }

    if (-not $PSCmdlet.ShouldProcess(
        $plan.LibraryRoot,
        "Publish mod '$Name' version '$Version'"
    )) {
        return [PSCustomObject]@{
            Name = $Name
            Version = $Version
            Published = $false
            LibraryRoot = $plan.LibraryRoot
            DeploymentFiles = @()
        }
    }

    New-Item -ItemType Directory -Path $plan.LibraryRoot -Force | Out-Null
    $stagingManifest = Read-PwJson -Path (
        Join-Path $plan.StagingRoot 'manifest.json'
    )
    $stagingArchivePath = Join-Path `
        $plan.StagingRoot `
        $stagingManifest.PackageArchive
    $libraryArchivePath = Join-Path $plan.LibraryRoot 'package.7z'
    Copy-Item `
        -LiteralPath $stagingArchivePath `
        -Destination $libraryArchivePath `
        -ErrorAction Stop
    $libraryArchiveHash = (
        Get-FileHash -LiteralPath $libraryArchivePath -Algorithm SHA256
    ).Hash

    if ($libraryArchiveHash -ne $stagingManifest.PackageArchiveHash) {
        throw 'The curated library archive hash changed during promotion.'
    }

    Write-PwJson `
        -InputObject $stagingManifest `
        -Path (Join-Path $plan.LibraryRoot 'manifest.json')

    $libraryValidation = Test-PwModPackage `
        -Name $Name `
        -Version $Version `
        -Area ModLibrary

    if (-not $libraryValidation.IsValid) {
        throw "Curated library package validation failed: " +
            ($libraryValidation.Errors -join ' ')
    }

    $deploymentArchivePath = ''
    $deploymentArchiveHash = ''

    if ($plan.DeploymentFiles.Count -gt 0) {
        $bundleRoot = Join-Path $plan.StagingRoot 'DeploymentBundle'

        foreach ($file in $plan.DeploymentFiles) {
            $bundlePath = Join-Path `
                $bundleRoot `
                $file.DeploymentRelativePath
            $bundleDirectory = Split-Path -Parent $bundlePath
            New-Item `
                -ItemType Directory `
                -Path $bundleDirectory `
                -Force |
                Out-Null
            Copy-Item `
                -LiteralPath $file.SourcePath `
                -Destination $bundlePath `
                -ErrorAction Stop
        }

        $deploymentArchivePath = Join-Path (
            Join-Path (Get-PwPaths).Deployment 'Packages'
        ) "$Name-$Version.7z"
        $deploymentArchiveHash = New-Pw7ZipArchive `
            -SourceRoot $bundleRoot `
            -DestinationPath $deploymentArchivePath
    }

    $publishedFiles = [System.Collections.Generic.List[object]]::new()

    foreach ($file in $plan.DeploymentFiles) {
        if ($file.Action -eq 'Unchanged') {
            continue
        }

        $destinationDirectory = Split-Path -Parent $file.DestinationPath
        New-Item `
            -ItemType Directory `
            -Path $destinationDirectory `
            -Force |
            Out-Null
        Copy-Item `
            -LiteralPath $file.SourcePath `
            -Destination $file.DestinationPath `
            -ErrorAction Stop
        $publishedHash = (
            Get-FileHash -LiteralPath $file.DestinationPath -Algorithm SHA256
        ).Hash

        if ($publishedHash -ne $file.Hash) {
            throw "Published deployment hash mismatch: $($file.ArchivePath)"
        }

        $publishedFiles.Add($file)
    }

    [PSCustomObject]@{
        Name = $Name
        Version = $Version
        Published = $true
        LibraryRoot = $plan.LibraryRoot
        LibraryArchive = $libraryArchivePath
        LibraryArchiveHash = $libraryArchiveHash
        DeploymentArchive = $deploymentArchivePath
        DeploymentArchiveHash = $deploymentArchiveHash
        DeploymentFiles = @($publishedFiles)
    }
}

<#
.SYNOPSIS
    Records a tested mod installation and cleans disposable workshop artifacts.
.DESCRIPTION
    Verifies the curated package and the corresponding files in the active
    Palworld installation. Preview is the default. With -Apply and
    -GameValidated, writes a known-good installation record beneath
    06_Current_Installation, then removes only the matching staging directory,
    deployment package, and hash-matching loose deployment files.

    The original download in 01_Archives and curated package in 03_Mod_Library
    are retained. The established 05_Deployment directory structure is never
    removed or pruned.
.PARAMETER Name
    Mod identifier.
.PARAMETER Version
    Mod version identifier.
.PARAMETER GameValidated
    Confirms that the mod was tested successfully inside Palworld.
.PARAMETER Notes
    Optional validation or compatibility notes stored in the installation record.
.PARAMETER Apply
    Writes metadata and performs the planned cleanup.
.OUTPUTS
    PSCustomObject describing verification, metadata, and cleanup.
#>
function Complete-PwModInstallation {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Version,

        [switch]$GameValidated,

        [string]$Notes = '',

        [switch]$Apply
    )

    foreach ($value in @($Name, $Version)) {
        if (-not (Test-PwModIdentifier -Value $value)) {
            throw "Invalid mod identifier '$value'."
        }
    }

    $paths = Get-PwPaths
    $libraryRoot = Get-PwModPackageRoot `
        -Area ModLibrary `
        -Name $Name `
        -Version $Version
    $manifestPath = Join-Path $libraryRoot 'manifest.json'
    $packageValidation = Test-PwModPackage `
        -Name $Name `
        -Version $Version `
        -Area ModLibrary

    if (-not $packageValidation.IsValid) {
        throw 'The curated package is not valid: ' +
            ($packageValidation.Errors -join ' ')
    }

    $manifest = Read-PwJson -Path $manifestPath
    $deployment = Get-PwDeployment
    $installedFiles = [System.Collections.Generic.List[object]]::new()
    $verificationErrors = [System.Collections.Generic.List[string]]::new()
    $deploymentFiles = [System.Collections.Generic.List[string]]::new()

    foreach ($entry in @(
        $manifest.Entries |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace(
                    [string]$_.DeploymentRelativePath
                )
            }
    )) {
        $relativePath = [string]$entry.DeploymentRelativePath
        if (-not (Test-PwDeploymentRelativePath -Path $relativePath)) {
            throw "Unsafe deployment mapping: $relativePath"
        }

        $safeRelativePath = $relativePath.Replace('/', '\')
        $installedPath = Join-Path $deployment.GameInstallRoot $safeRelativePath
        $installedHash = ''
        $status = 'Missing'

        if (Test-Path -LiteralPath $installedPath -PathType Leaf) {
            $installedHash = (
                Get-FileHash -LiteralPath $installedPath -Algorithm SHA256
            ).Hash
            $status = if ($installedHash -eq [string]$entry.Hash) {
                'Verified'
            }
            else {
                'HashMismatch'
            }
        }

        if ($status -ne 'Verified') {
            $verificationErrors.Add(
                "Installed file $status`: $safeRelativePath"
            )
        }

        $installedFiles.Add([PSCustomObject]@{
            RelativePath = $safeRelativePath
            InstalledPath = $installedPath
            ExpectedHash = [string]$entry.Hash
            InstalledHash = $installedHash
            Status = $status
        })

        $deploymentFile = Join-Path $paths.Deployment $safeRelativePath

        if (
            Test-Path -LiteralPath $deploymentFile -PathType Leaf
        ) {
            $deploymentHash = (
                Get-FileHash -LiteralPath $deploymentFile -Algorithm SHA256
            ).Hash

            if ($deploymentHash -eq [string]$entry.Hash) {
                $deploymentFiles.Add($deploymentFile)
            }
            else {
                $verificationErrors.Add(
                    "Deployment file changed and will not be removed: " +
                        $safeRelativePath
                )
            }
        }
    }

    $stagingRoot = Join-Path (
        Join-Path $paths.Staging $Name
    ) $Version
    $deploymentArchive = Join-Path (
        Join-Path $paths.Deployment 'Packages'
    ) "$Name-$Version.7z"
    $recordRoot = Join-Path (
        Join-Path $paths.CurrentInstallation 'Mods'
    ) $Name
    $recordPath = Join-Path $recordRoot "$Version.json"
    $canComplete = (
        $GameValidated -and
        $verificationErrors.Count -eq 0
    )

    $plan = [PSCustomObject]@{
        Name = $Name
        Version = $Version
        Profile = $deployment.ActiveProfile
        GameValidated = [bool]$GameValidated
        CanComplete = $canComplete
        VerificationErrors = @($verificationErrors)
        InstalledFiles = @($installedFiles)
        RecordPath = $recordPath
        Cleanup = [PSCustomObject]@{
            StagingRoot = $stagingRoot
            DeploymentArchive = $deploymentArchive
            DeploymentFiles = @($deploymentFiles)
        }
        Applied = $false
    }

    if (-not $Apply) {
        return $plan
    }

    if (-not $GameValidated) {
        throw 'Use -GameValidated only after successful in-game testing.'
    }

    if (-not $canComplete) {
        throw 'Installation completion failed verification: ' +
            ($verificationErrors -join ' ')
    }

    if (Test-Path -LiteralPath $recordPath) {
        throw "A known-good installation record already exists: $recordPath"
    }

    if (-not $PSCmdlet.ShouldProcess(
        "$Name $Version",
        'Record known-good installation and clean disposable artifacts'
    )) {
        return $plan
    }

    $packageArchive = Join-Path $libraryRoot $manifest.PackageArchive
    $record = [PSCustomObject]@{
        SchemaVersion = '1.0'
        Name = $Name
        Version = $Version
        Status = 'KnownGood'
        Profile = $deployment.ActiveProfile
        ValidatedAt = Get-Date
        ValidatedInGame = $true
        Notes = $Notes
        LibraryManifest = $manifestPath
        LibraryArchive = $packageArchive
        LibraryArchiveHash = [string]$manifest.PackageArchiveHash
        OriginalArchive = [string]$manifest.OriginalArchive
        OriginalArchiveHash = [string]$manifest.ArchiveHash
        GameInstallRoot = $deployment.GameInstallRoot
        Files = @($installedFiles)
    }

    New-Item -ItemType Directory -Path $recordRoot -Force | Out-Null
    Write-PwJson -InputObject $record -Path $recordPath

    if (-not (Test-PwJson -Path $recordPath)) {
        throw "Known-good installation record could not be verified: $recordPath"
    }

    foreach ($deploymentFile in $deploymentFiles) {
        Remove-Item -LiteralPath $deploymentFile -Force -ErrorAction Stop
    }

    if (Test-Path -LiteralPath $deploymentArchive -PathType Leaf) {
        Remove-Item -LiteralPath $deploymentArchive -Force -ErrorAction Stop
    }

    if (Test-Path -LiteralPath $stagingRoot -PathType Container) {
        Remove-Item `
            -LiteralPath $stagingRoot `
            -Recurse `
            -Force `
            -ErrorAction Stop
    }

    $plan.Applied = $true
    $plan
}
