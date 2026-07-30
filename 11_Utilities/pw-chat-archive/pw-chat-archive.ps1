[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$InputPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Topic,

    [datetime]$SessionDate = (Get-Date),

    [string]$ArchiveRoot,

    [string[]]$EvidencePath = @(),

    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepositoryRoot {
    param([string]$StartPath = (Get-Location).Path)

    $current = [System.IO.DirectoryInfo]::new((Resolve-Path -LiteralPath $StartPath).Path)
    while ($null -ne $current) {
        if (Test-Path -LiteralPath (Join-Path $current.FullName '.git')) {
            return $current.FullName
        }
        $current = $current.Parent
    }

    throw "Unable to locate a Git repository root from '$StartPath'. Supply -ArchiveRoot explicitly."
}

function ConvertTo-SafeSlug {
    param([Parameter(Mandatory)][string]$Value)

    $slug = $Value.Trim().ToLowerInvariant()
    $slug = [regex]::Replace($slug, '[^a-z0-9]+', '-')
    $slug = $slug.Trim('-')

    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw 'Topic does not contain any usable filename characters.'
    }

    return $slug
}

function Get-FileDigest {
    param([Parameter(Mandatory)][string]$Path)

    $item = Get-Item -LiteralPath $Path
    $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256

    [pscustomobject]@{
        Path       = $item.FullName
        Length     = $item.Length
        SHA256     = $hash.Hash.ToLowerInvariant()
        ModifiedAt = $item.LastWriteTimeUtc.ToString('o')
    }
}

$source = (Resolve-Path -LiteralPath $InputPath).Path
$sourceItem = Get-Item -LiteralPath $source
$slug = ConvertTo-SafeSlug -Value $Topic
$dateStamp = $SessionDate.ToString('yyyy-MM-dd')

if ([string]::IsNullOrWhiteSpace($ArchiveRoot)) {
    $repoRoot = Get-RepositoryRoot -StartPath (Get-Location).Path
    $ArchiveRoot = Join-Path $repoRoot '00_Documentation\Chat-Archives'
}

$archiveDirectory = [System.IO.Path]::GetFullPath($ArchiveRoot)
$extension = $sourceItem.Extension
if ([string]::IsNullOrWhiteSpace($extension)) {
    $extension = '.bin'
}

$baseName = "$dateStamp-$slug"
$archivePath = Join-Path $archiveDirectory "$baseName.raw$extension"
$manifestPath = Join-Path $archiveDirectory "$baseName.manifest.json"
$evidenceDirectory = Join-Path $archiveDirectory "$baseName.evidence"

foreach ($path in @($archivePath, $manifestPath)) {
    if (Test-Path -LiteralPath $path) {
        throw "Refusing to overwrite existing archive artifact: $path"
    }
}

if ($PSCmdlet.ShouldProcess($archivePath, 'Create byte-for-byte chat archive')) {
    New-Item -ItemType Directory -Path $archiveDirectory -Force | Out-Null

    # File.Copy preserves the source bytes. The transcript is never parsed,
    # normalized, reformatted, decoded, or rewritten by this utility.
    [System.IO.File]::Copy($source, $archivePath, $false)

    $sourceDigest = Get-FileDigest -Path $source
    $archiveDigest = Get-FileDigest -Path $archivePath

    if ($sourceDigest.Length -ne $archiveDigest.Length -or
        $sourceDigest.SHA256 -ne $archiveDigest.SHA256) {
        Remove-Item -LiteralPath $archivePath -Force -ErrorAction SilentlyContinue
        throw 'Archive verification failed: source and destination bytes differ.'
    }

    $evidence = @()
    if ($EvidencePath.Count -gt 0) {
        New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null

        foreach ($candidate in $EvidencePath) {
            if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                throw "Evidence file not found: $candidate"
            }

            $resolvedEvidence = (Resolve-Path -LiteralPath $candidate).Path
            $destination = Join-Path $evidenceDirectory ([System.IO.Path]::GetFileName($resolvedEvidence))

            if (Test-Path -LiteralPath $destination) {
                throw "Duplicate evidence filename: $destination"
            }

            [System.IO.File]::Copy($resolvedEvidence, $destination, $false)
            $sourceEvidenceDigest = Get-FileDigest -Path $resolvedEvidence
            $destinationEvidenceDigest = Get-FileDigest -Path $destination

            if ($sourceEvidenceDigest.Length -ne $destinationEvidenceDigest.Length -or
                $sourceEvidenceDigest.SHA256 -ne $destinationEvidenceDigest.SHA256) {
                throw "Evidence verification failed: $resolvedEvidence"
            }

            $evidence += [pscustomobject]@{
                OriginalPath = $sourceEvidenceDigest.Path
                ArchivedPath = $destinationEvidenceDigest.Path
                Length       = $destinationEvidenceDigest.Length
                SHA256       = $destinationEvidenceDigest.SHA256
            }
        }
    }

    $manifest = [ordered]@{
        SchemaVersion = 1
        Tool          = 'pw-chat-archive'
        CreatedAtUtc  = (Get-Date).ToUniversalTime().ToString('o')
        SessionDate   = $SessionDate.ToString('yyyy-MM-dd')
        Topic         = $Topic
        RawArchive    = [ordered]@{
            OriginalPath = $sourceDigest.Path
            ArchivedPath = $archiveDigest.Path
            Length       = $archiveDigest.Length
            SHA256       = $archiveDigest.SHA256
            ByteExact    = $true
        }
        Evidence      = $evidence
        Notes         = @(
            'The raw archive was copied byte-for-byte and was not parsed or modified.',
            'UI-only source chips are preserved only when present in the supplied source file or separately supplied as evidence.'
        )
    }

    $manifestJson = $manifest | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText(
        $manifestPath,
        $manifestJson + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    $result = [pscustomobject]@{
        ArchivePath  = $archivePath
        ManifestPath = $manifestPath
        EvidencePath = if (Test-Path -LiteralPath $evidenceDirectory) { $evidenceDirectory } else { $null }
        Length       = $archiveDigest.Length
        SHA256       = $archiveDigest.SHA256
        Verified     = $true
    }

    Write-Host ''
    Write-Host 'pw-chat-archive completed successfully.'
    Write-Host "Archive : $archivePath"
    Write-Host "Manifest: $manifestPath"
    Write-Host "SHA256  : $($archiveDigest.SHA256)"
    Write-Host 'Verified: byte-for-byte match'

    if ($PassThru) {
        $result
    }
}
