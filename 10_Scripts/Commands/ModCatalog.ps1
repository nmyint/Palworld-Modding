<#
.SYNOPSIS
    Provides offline Nexus archive, loose-mod, and catalog discovery.
#>

Set-StrictMode -Version Latest

function ConvertTo-PwCatalogKey {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    ($Value -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
}

function Test-PwStrictJson {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        $document = [System.Text.Json.JsonDocument]::Parse(
            [System.IO.File]::ReadAllText($Path)
        )
        $document.Dispose()
        $true
    }
    catch {
        $false
    }
}

function Get-PwDirectoryContentHash {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $records = @(
        Get-ChildItem -LiteralPath $Path -Recurse -File |
            Sort-Object FullName |
            ForEach-Object {
                $relativePath = [System.IO.Path]::GetRelativePath(
                    $Path,
                    $_.FullName
                ).Replace('\', '/')
                $hash = (
                    Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
                ).Hash
                "$relativePath|$hash"
            }
    )
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(
        ($records -join "`n")
    )
    $algorithm = [System.Security.Cryptography.SHA256]::Create()

    try {
        [System.Convert]::ToHexString(
            $algorithm.ComputeHash($bytes)
        )
    }
    finally {
        $algorithm.Dispose()
    }
}

function Get-PwArchiveInstallNames {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Inspection
    )

    $names = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($entry in @($Inspection.Entries)) {
        $candidatePaths = @(
            [string]$entry.DeploymentRelativePath
            [string]$entry.ArchivePath
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        foreach ($candidatePath in $candidatePaths) {
            $segments = @(
                $candidatePath.Replace('/', '\').Split(
                    '\',
                    [System.StringSplitOptions]::RemoveEmptyEntries
                )
            )
            $modsIndex = [System.Array]::IndexOf($segments, 'Mods')

            if (
                $modsIndex -ge 0 -and
                $modsIndex + 1 -lt $segments.Count
            ) {
                $candidate = $segments[$modsIndex + 1]

                if ($candidate -notin @('~mods', 'LogicMods')) {
                    $names.Add($candidate) | Out-Null
                }

                continue
            }

            if (
                $entry.Category -eq 'Lua' -and
                $segments.Count -ge 2 -and
                $segments[0] -notin @('Pal', 'Content', 'ue4ss')
            ) {
                $names.Add($segments[0]) | Out-Null
            }
        }
    }

    @($names | Sort-Object)
}

function Get-PwNexusFilenameMetadata {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FileName
    )

    $modernMatch = [regex]::Match(
        $FileName,
        '^(?<name>.+)\s+(?<modId>\d+)\s+' +
            '(?<version>\S+)\s+' +
            '(?<downloaded>\d{4}-\d{2}-\d{2}T\d{2}-\d{2}Z)\s+' +
            '(?<token>[A-Za-z0-9]+)\.(?<format>zip|7z)$',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    if ($modernMatch.Success) {
        try {
            $timestamp = [datetime]::ParseExact(
                $modernMatch.Groups['downloaded'].Value,
                'yyyy-MM-ddTHH-mmZ',
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::AssumeUniversal
            ).ToUniversalTime()

            return [PSCustomObject]@{
                Success = $true
                Pattern = 'NexusDownload'
                Name = $modernMatch.Groups['name'].Value.Trim()
                ModId = [int]$modernMatch.Groups['modId'].Value
                Version = $modernMatch.Groups['version'].Value
                Timestamp = $timestamp
                TimestampSource = 'DownloadedAt'
                Token = $modernMatch.Groups['token'].Value
                Error = ''
            }
        }
        catch {
            return [PSCustomObject]@{
                Success = $false
                Pattern = 'NexusDownload'
                Name = ''
                ModId = $null
                Version = ''
                Timestamp = $null
                TimestampSource = ''
                Token = ''
                Error = 'Download timestamp could not be parsed.'
            }
        }
    }

    $legacyMatch = [regex]::Match(
        $FileName,
        '^(?<prefix>.+)-(?<timestamp>\d{9,10})\.(?<format>zip|7z)$',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    if ($legacyMatch.Success) {
        $segments = @($legacyMatch.Groups['prefix'].Value.Split('-'))
        $numericRunStart = $segments.Count

        for ($index = $segments.Count - 1; $index -ge 0; $index--) {
            if ($segments[$index] -notmatch '^\d+$') {
                break
            }

            $numericRunStart = $index
        }

        if (
            $numericRunStart -gt 0 -and
            $segments.Count - $numericRunStart -ge 3
        ) {
            try {
                $timestamp = [datetimeoffset]::FromUnixTimeSeconds(
                    [long]$legacyMatch.Groups['timestamp'].Value
                ).UtcDateTime
                $versionSegments = @(
                    $segments[($numericRunStart + 1)..($segments.Count - 1)]
                )

                return [PSCustomObject]@{
                    Success = $true
                    Pattern = 'NexusLegacyHyphen'
                    Name = (
                        $segments[0..($numericRunStart - 1)] -join '-'
                    )
                    ModId = [int]$segments[$numericRunStart]
                    Version = $versionSegments -join '.'
                    Timestamp = $timestamp
                    TimestampSource = 'NexusFileUploadedAt'
                    Token = ''
                    Error = ''
                }
            }
            catch {
                return [PSCustomObject]@{
                    Success = $false
                    Pattern = 'NexusLegacyHyphen'
                    Name = ''
                    ModId = $null
                    Version = ''
                    Timestamp = $null
                    TimestampSource = ''
                    Token = ''
                    Error = 'Legacy Nexus timestamp could not be parsed.'
                }
            }
        }
    }

    [PSCustomObject]@{
        Success = $false
        Pattern = 'Unrecognized'
        Name = ''
        ModId = $null
        Version = ''
        Timestamp = $null
        TimestampSource = ''
        Token = ''
        Error = 'Filename does not match a supported Nexus archive pattern.'
    }
}

<#
.SYNOPSIS
    Parses and inspects Nexus-style archives in 01_Archives.
.DESCRIPTION
    Parses filename fields from the right so names may contain spaces, version
    text, and parenthetical labels. The numeric field is recorded as the Nexus
    Palworld mod ID. Archive contents remain authoritative for deployment layout.
.PARAMETER Path
    Optional archive file or archive directory. Defaults to 01_Archives.
.PARAMETER SkipContentInspection
    Parses filenames and hashes archives without inspecting internal layouts.
#>
function Get-PwNexusArchiveMetadata {

    [CmdletBinding()]
    param(
        [string]$Path = (Get-PwPaths).Archives,

        [switch]$SkipContentInspection
    )

    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $archives = if (Test-Path -LiteralPath $resolvedPath -PathType Leaf) {
        @(Get-Item -LiteralPath $resolvedPath)
    }
    elseif (Test-Path -LiteralPath $resolvedPath -PathType Container) {
        @(
            Get-ChildItem -LiteralPath $resolvedPath -File |
                Where-Object Extension -in @('.zip', '.7z') |
                Sort-Object Name
        )
    }
    else {
        throw "Archive path does not exist: $resolvedPath"
    }

    @(
        foreach ($archive in $archives) {
            $filenameMetadata = Get-PwNexusFilenameMetadata `
                -FileName $archive.Name
            $parsed = $filenameMetadata.Success
            $parseErrors = [System.Collections.Generic.List[string]]::new()

            if (-not $parsed) {
                $parseErrors.Add($filenameMetadata.Error)
            }

            $inspection = $null

            if (-not $SkipContentInspection) {
                try {
                    $inspection = Get-PwModArchiveInfo -Path $archive.FullName
                }
                catch {
                    $parseErrors.Add(
                        "Archive inspection failed: $($_.Exception.Message)"
                    )
                }
            }

            $name = if ($parsed) {
                $filenameMetadata.Name
            }
            else {
                [System.IO.Path]::GetFileNameWithoutExtension($archive.Name)
            }
            $modId = if ($parsed) {
                $filenameMetadata.ModId
            }
            else {
                $null
            }
            $version = if ($parsed) {
                $filenameMetadata.Version
            }
            else {
                ''
            }
            $token = if ($parsed) {
                $filenameMetadata.Token
            }
            else {
                ''
            }
            $archiveHash = if ($inspection) {
                $inspection.ArchiveHash
            }
            else {
                (
                    Get-FileHash `
                        -LiteralPath $archive.FullName `
                        -Algorithm SHA256
                ).Hash
            }

            [PSCustomObject]@{
                Source = 'NexusMods'
                GameDomain = 'palworld'
                Name = $name
                CatalogKey = ConvertTo-PwCatalogKey -Value $name
                NexusModId = $modId
                NexusUrl = if ($modId) {
                    "https://www.nexusmods.com/palworld/mods/$modId"
                }
                else {
                    ''
                }
                ArchiveVersion = $version
                DownloadedAt = $filenameMetadata.Timestamp
                TimestampSource = $filenameMetadata.TimestampSource
                DownloadToken = $token
                FilenamePattern = $filenameMetadata.Pattern
                OriginalFileName = $archive.Name
                ArchivePath = $archive.FullName
                ArchiveFormat = $archive.Extension.TrimStart('.').ToUpperInvariant()
                ArchiveLength = $archive.Length
                ArchiveHash = $archiveHash
                InstallNames = if ($inspection) {
                    @(Get-PwArchiveInstallNames -Inspection $inspection)
                }
                else {
                    @()
                }
                Categories = if ($inspection) {
                    @($inspection.Categories)
                }
                else {
                    @()
                }
                IsSafe = if ($inspection) {
                    [bool]$inspection.IsSafe
                }
                else {
                    $null
                }
                IsParsed = $parsed -and $parseErrors.Count -eq 0
                Errors = @($parseErrors)
            }
        }
    )
}

function Get-PwLegacyModState {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StagingRoot
    )

    $states = @{}
    $modsTextPath = Join-Path $StagingRoot 'mods.txt'

    if (Test-Path -LiteralPath $modsTextPath -PathType Leaf) {
        foreach ($line in Get-Content -LiteralPath $modsTextPath) {
            if ($line -match '^\s*([^;][^:]+?)\s*:\s*([01])\s*$') {
                $states[$matches[1].Trim()] = $matches[2] -eq '1'
            }
        }
    }

    $states
}

<#
.SYNOPSIS
    Inventories loose mod folders currently stored in 02_Staging.
.OUTPUTS
    Read-only records containing folder, enablement, layout, and aggregate hashes.
#>
function Get-PwStagedModSnapshot {

    [CmdletBinding()]
    param(
        [string]$Path = (Get-PwPaths).Staging
    )

    $root = [System.IO.Path]::GetFullPath($Path)

    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw "Staging root does not exist: $root"
    }

    $ue4ssModsRoot = Join-Path $root 'Pal\Binaries\Win64\ue4ss\Mods'
    $inventoryRoot = if (
        Test-Path -LiteralPath $ue4ssModsRoot -PathType Container
    ) {
        $ue4ssModsRoot
    }
    else {
        $root
    }

    $legacyStates = Get-PwLegacyModState -StagingRoot $root

    @(
        foreach (
            $directory in Get-ChildItem -LiteralPath $inventoryRoot -Directory |
                Where-Object Name -notin @('Pal', '~mods', 'LogicMods') |
                Sort-Object Name
        ) {
            $enabledMarker = Join-Path $directory.FullName 'enabled.txt'
            $disabledMarker = Join-Path $directory.FullName 'disabled.txt'
            $hasEnabled = Test-Path -LiteralPath $enabledMarker -PathType Leaf
            $hasDisabled = Test-Path -LiteralPath $disabledMarker -PathType Leaf
            $enabled = $null
            $enabledSource = 'Unknown'

            if ($hasEnabled) {
                $enabled = $true
                $enabledSource = 'enabled.txt'
            }
            elseif ($hasDisabled) {
                $enabled = $false
                $enabledSource = 'disabled.txt'
            }
            elseif ($legacyStates.ContainsKey($directory.Name)) {
                $enabled = [bool]$legacyStates[$directory.Name]
                $enabledSource = 'mods.txt'
            }

            $files = @(
                Get-ChildItem -LiteralPath $directory.FullName -Recurse -File
            )
            $hasLua = @($files | Where-Object Extension -eq '.lua').Count -gt 0
            $hasDll = @($files | Where-Object Extension -eq '.dll').Count -gt 0
            $hasPak = @(
                $files |
                    Where-Object Extension -in @('.pak', '.ucas', '.utoc')
            ).Count -gt 0
            $types = [System.Collections.Generic.List[string]]::new()

            if ($hasLua) {
                $types.Add('UE4SS')
            }

            if ($hasDll) {
                $types.Add('Native')
            }

            if ($hasPak) {
                $types.Add('Pak')
            }

            if ($types.Count -eq 0) {
                $types.Add('SupportOrUnknown')
            }

            [PSCustomObject]@{
                Name = $directory.Name
                CatalogKey = ConvertTo-PwCatalogKey -Value $directory.Name
                Path = $directory.FullName
                Enabled = $enabled
                EnabledSource = $enabledSource
                Types = @($types)
                FileCount = $files.Count
                Length = ($files | Measure-Object Length -Sum).Sum
                ContentHash = Get-PwDirectoryContentHash -Path $directory.FullName
            }
        }
    )
}

function Test-PwCatalogArchiveMatch {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Snapshot,

        [Parameter(Mandatory)]
        [object]$Archive
    )

    if ($Snapshot.CatalogKey -eq $Archive.CatalogKey) {
        return $true
    }

    foreach ($installName in @($Archive.InstallNames)) {
        if (
            $Snapshot.CatalogKey -eq (
                ConvertTo-PwCatalogKey -Value $installName
            )
        ) {
            return $true
        }
    }

    $archiveKey = [string]$Archive.CatalogKey
    $snapshotKey = [string]$Snapshot.CatalogKey

    (
        $archiveKey.StartsWith($snapshotKey) -or
        $snapshotKey.StartsWith($archiveKey)
    )
}

<#
.SYNOPSIS
    Builds a read-only catalog that matches archives to the loose installation.
.OUTPUTS
    Catalog report containing mods, archive-only items, duplicates, and warnings.
#>
function Get-PwModCatalog {

    [CmdletBinding()]
    param(
        [switch]$SkipContentInspection
    )

    $archives = @(
        Get-PwNexusArchiveMetadata `
            -SkipContentInspection:$SkipContentInspection
    )
    $snapshots = @(Get-PwStagedModSnapshot)
    $mods = [System.Collections.Generic.List[object]]::new()
    $matchedArchivePaths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $warnings = [System.Collections.Generic.List[string]]::new()

    foreach ($archive in $archives) {
        if (-not $archive.IsParsed) {
            $warnings.Add(
                "Archive filename needs manual metadata: " +
                    $archive.OriginalFileName
            )
        }

        foreach ($errorMessage in @($archive.Errors)) {
            $warnings.Add(
                "Archive '$($archive.OriginalFileName)': $errorMessage"
            )
        }
    }

    foreach ($snapshot in $snapshots) {
        $matches = @(
            $archives |
                Where-Object {
                    Test-PwCatalogArchiveMatch `
                        -Snapshot $snapshot `
                        -Archive $_
                } |
                Sort-Object DownloadedAt
        )

        foreach ($archive in $matches) {
            $matchedArchivePaths.Add($archive.ArchivePath) | Out-Null
        }

        $matchStatus = if ($matches.Count -eq 0) {
            'MissingArchive'
        }
        elseif ($matches.Count -eq 1) {
            'Matched'
        }
        else {
            'MultipleVersions'
        }

        if ($matchStatus -eq 'MissingArchive') {
            $warnings.Add(
                "No surviving archive matches staged mod '$($snapshot.Name)'."
            )
        }

        $mods.Add([PSCustomObject]@{
            Name = $snapshot.Name
            InstallName = $snapshot.Name
            Enabled = $snapshot.Enabled
            EnabledSource = $snapshot.EnabledSource
            Types = $snapshot.Types
            InstalledContentHash = $snapshot.ContentHash
            ArchiveMatchStatus = $matchStatus
            CandidateVersions = @(
                $matches |
                    Select-Object -ExpandProperty ArchiveVersion
            )
            LatestCandidateVersion = if ($matches.Count -gt 0) {
                [string]$matches[-1].ArchiveVersion
            }
            else {
                ''
            }
            NexusModIds = @(
                $matches |
                    Where-Object NexusModId |
                    Select-Object -ExpandProperty NexusModId -Unique
            )
            Archives = $matches
        })
    }

    $archiveOnly = @(
        $archives |
            Where-Object {
                -not $matchedArchivePaths.Contains($_.ArchivePath)
            }
    )

    foreach ($archive in $archiveOnly) {
        $warnings.Add(
            "Archive has no loose staging match: $($archive.OriginalFileName)"
        )
    }

    $duplicateArchives = @(
        $archives |
            Group-Object ArchiveHash |
            Where-Object Count -gt 1 |
            ForEach-Object {
                [PSCustomObject]@{
                    Hash = $_.Name
                    Files = @($_.Group.OriginalFileName)
                }
            }
    )
    $duplicateSnapshots = @(
        $snapshots |
            Group-Object ContentHash |
            Where-Object Count -gt 1 |
            ForEach-Object {
                [PSCustomObject]@{
                    Hash = $_.Name
                    Mods = @($_.Group.Name)
                }
            }
    )
    $modsJsonPath = Join-Path (Get-PwPaths).Staging 'mods.json'
    $modsJsonValid = (
        -not (Test-Path -LiteralPath $modsJsonPath -PathType Leaf) -or
        (Test-PwStrictJson -Path $modsJsonPath)
    )

    if (-not $modsJsonValid) {
        $warnings.Add('02_Staging\mods.json is malformed JSON.')
    }

    [PSCustomObject]@{
        GeneratedAt = Get-Date
        ModCount = $mods.Count
        ArchiveCount = $archives.Count
        MatchedModCount = @(
            $mods |
                Where-Object ArchiveMatchStatus -ne 'MissingArchive'
        ).Count
        MissingArchiveCount = @(
            $mods |
                Where-Object ArchiveMatchStatus -eq 'MissingArchive'
        ).Count
        ArchiveOnlyCount = $archiveOnly.Count
        ModsJsonValid = $modsJsonValid
        Mods = @($mods)
        ArchiveOnly = $archiveOnly
        DuplicateArchives = $duplicateArchives
        DuplicateSnapshots = $duplicateSnapshots
        Warnings = @($warnings)
    }
}
