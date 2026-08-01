<#
.SYNOPSIS
    Adds lazy Nexus content-preview inventories and package classification.
.DESCRIPTION
    Extends the persistent Nexus metadata snapshot with advisory remote content
    previews and authoritative local archive inspections. Remote inventories are
    reused until their Nexus file metadata changes. Local archive inspection
    always takes precedence for the same Nexus file ID.
#>

Set-StrictMode -Version Latest

$script:PwUpdateNexusMetadataCacheCore = ${function:Update-PwNexusMetadataCache}
$script:PwGetModUpdateReportCore = ${function:Get-PwModUpdateReport}
$script:PwSaveNexusModUpdateCore = ${function:Save-PwNexusModUpdateCore}

function Set-PwObjectProperty {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [AllowNull()]
        [object]$Value
    )

    if ($InputObject.PSObject.Properties[$Name]) {
        $InputObject.$Name = $Value
        return
    }

    $InputObject |
        Add-Member `
            -NotePropertyName $Name `
            -NotePropertyValue $Value
}

function Get-PwNexusFileMetadataFingerprint {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$File
    )

    $json = $File | ConvertTo-Json -Depth 30 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
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

function Test-PwNexusContentPathCandidate {

    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    $candidate = $Value.Trim()

    if ($candidate -match '^[a-z][a-z0-9+.-]*://') {
        return $false
    }

    if ($candidate -match '[\\/]') {
        return $true
    }

    $extension = [System.IO.Path]::GetExtension($candidate).ToLowerInvariant()
    $extension -in @(
        '.lua',
        '.pak',
        '.utoc',
        '.ucas',
        '.dll',
        '.json',
        '.ini',
        '.cfg',
        '.toml',
        '.yaml',
        '.yml',
        '.md',
        '.txt',
        '.pdf',
        '.png',
        '.jpg',
        '.jpeg',
        '.webp'
    )
}

function ConvertTo-PwNormalizedContentPath {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    $normalized = $Value.Trim().Replace('\', '/')
    $normalized = $normalized -replace '^\./', ''
    $normalized = $normalized -replace '^/+', ''
    $normalized = $normalized -replace '/+', '/'
    $normalized.Trim('/')
}

function Get-PwNexusContentPreviewPaths {

    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Response
    )

    $paths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $nameProperties = @(
        'path',
        'full_path',
        'fullPath',
        'relative_path',
        'relativePath',
        'file_path',
        'filePath',
        'filename',
        'file_name',
        'name'
    )
    $childProperties = @(
        'children',
        'files',
        'entries',
        'contents',
        'items'
    )
    $visit = $null
    $visit = {
        param(
            [AllowNull()]
            [object]$Value,

            [string]$Prefix = ''
        )

        if ($null -eq $Value) {
            return
        }

        if ($Value -is [string]) {
            $candidate = [string]$Value

            if (
                -not [string]::IsNullOrWhiteSpace($Prefix) -and
                $candidate -notmatch '[\\/]'
            ) {
                $candidate = "$Prefix/$candidate"
            }

            if (Test-PwNexusContentPathCandidate -Value $candidate) {
                $normalized = ConvertTo-PwNormalizedContentPath `
                    -Value $candidate

                if (-not [string]::IsNullOrWhiteSpace($normalized)) {
                    $paths.Add($normalized) | Out-Null
                }
            }

            return
        }

        if ($Value -is [System.Collections.IDictionary]) {
            $object = [PSCustomObject]$Value
            & $visit $object $Prefix
            return
        }

        if (
            $Value -is [System.Collections.IEnumerable] -and
            $Value -isnot [string]
        ) {
            foreach ($item in $Value) {
                & $visit $item $Prefix
            }

            return
        }

        if ($Value -is [System.ValueType]) {
            return
        }

        $properties = @($Value.PSObject.Properties)

        if ($properties.Count -eq 0) {
            return
        }

        $nameValue = ''

        foreach ($propertyName in $nameProperties) {
            $property = $Value.PSObject.Properties[$propertyName]

            if (
                $property -and
                $property.Value -is [string] -and
                -not [string]::IsNullOrWhiteSpace([string]$property.Value)
            ) {
                $nameValue = [string]$property.Value
                break
            }
        }

        $currentPath = $Prefix

        if (-not [string]::IsNullOrWhiteSpace($nameValue)) {
            $candidate = if (
                -not [string]::IsNullOrWhiteSpace($Prefix) -and
                $nameValue -notmatch '[\\/]'
            ) {
                "$Prefix/$nameValue"
            }
            else {
                $nameValue
            }
            $normalizedCandidate = ConvertTo-PwNormalizedContentPath `
                -Value $candidate

            if (Test-PwNexusContentPathCandidate -Value $candidate) {
                $paths.Add($normalizedCandidate) | Out-Null
            }

            if ([string]::IsNullOrWhiteSpace(
                [System.IO.Path]::GetExtension($normalizedCandidate)
            )) {
                $currentPath = $normalizedCandidate
            }
        }

        foreach ($property in $properties) {
            if ($property.Name -in $nameProperties) {
                continue
            }

            $nextPrefix = if ($property.Name -in $childProperties) {
                $currentPath
            }
            else {
                $Prefix
            }
            & $visit $property.Value $nextPrefix
        }
    }

    & $visit $Response ''
    @($paths | Sort-Object)
}

function ConvertTo-PwNexusContentClassification {

    [CmdletBinding()]
    param(
        [string[]]$Path = @()
    )

    $paths = @(
        $Path |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { ConvertTo-PwNormalizedContentPath -Value $_ } |
            Sort-Object -Unique
    )
    $packageTypes = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $detectedRoots = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($contentPath in $paths) {
        $extension = [System.IO.Path]::GetExtension(
            $contentPath
        ).ToLowerInvariant()
        $ue4ssMatch = [regex]::Match(
            $contentPath,
            '(?i)(?:^|/)Pal/Binaries/Win64/ue4ss/Mods/(?<name>[^/]+)'
        )
        $shortUe4ssMatch = [regex]::Match(
            $contentPath,
            '(?i)(?:^|/)ue4ss/Mods/(?<name>[^/]+)'
        )

        if ($ue4ssMatch.Success) {
            $detectedRoots.Add(
                'Pal/Binaries/Win64/ue4ss/Mods/' +
                    $ue4ssMatch.Groups['name'].Value
            ) | Out-Null
        }
        elseif ($shortUe4ssMatch.Success) {
            $detectedRoots.Add(
                'Pal/Binaries/Win64/ue4ss/Mods/' +
                    $shortUe4ssMatch.Groups['name'].Value
            ) | Out-Null
        }

        if ($extension -eq '.lua') {
            $packageTypes.Add('UE4SSLua') | Out-Null
        }

        if (
            $extension -in @('.pak', '.utoc', '.ucas') -and
            $contentPath -match '(?i)(?:^|/)Pal/Content/Paks/LogicMods(?:/|$)'
        ) {
            $packageTypes.Add('LogicMods') | Out-Null
            $detectedRoots.Add('Pal/Content/Paks/LogicMods') | Out-Null
        }
        elseif ($extension -in @('.pak', '.utoc', '.ucas')) {
            $packageTypes.Add('Pak') | Out-Null

            if (
                $contentPath -match '(?i)(?:^|/)Pal/Content/Paks/~mods(?:/|$)'
            ) {
                $detectedRoots.Add('Pal/Content/Paks/~mods') | Out-Null
            }
            elseif ($contentPath -match '(?i)(?:^|/)Pal/Content/Paks(?:/|$)') {
                $detectedRoots.Add('Pal/Content/Paks') | Out-Null
            }
        }

        if ($extension -eq '.dll') {
            $packageTypes.Add('Native') | Out-Null

            if (
                $contentPath -match '(?i)(?:^|/)Pal/Binaries/Win64(?:/|$)'
            ) {
                $detectedRoots.Add('Pal/Binaries/Win64') | Out-Null
            }
        }

        if ($extension -in @('.json', '.ini', '.cfg', '.toml', '.yaml', '.yml')) {
            $packageTypes.Add('Configuration') | Out-Null
        }

        if (
            $extension -in @('.md', '.txt', '.pdf') -or
            [System.IO.Path]::GetFileName($contentPath) -match
                '(?i)^(readme|license|changelog|changes)(\.|$)'
        ) {
            $packageTypes.Add('Documentation') | Out-Null
        }
    }

    $deploymentTypes = @(
        $packageTypes |
            Where-Object {
                $_ -in @('UE4SSLua', 'Pak', 'LogicMods', 'Native')
            }
    )

    if ($packageTypes.Count -eq 0) {
        $packageTypes.Add('SupportOrUnknown') | Out-Null
    }

    [PSCustomObject]@{
        Paths = $paths
        FileCount = $paths.Count
        PackageTypes = @($packageTypes | Sort-Object)
        DetectedRoots = @($detectedRoots | Sort-Object)
        IsMixedPackage = $deploymentTypes.Count -gt 1
    }
}

function Invoke-PwNexusContentPreviewRequest {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$Uri
    )

    if ($Uri.Scheme -ne 'https') {
        throw 'Nexus content-preview links must use HTTPS.'
    }

    if ($Uri.Host -notmatch '(?i)(^|\.)nexusmods\.com$') {
        throw "Unexpected Nexus content-preview host: $($Uri.Host)"
    }

    Invoke-RestMethod `
        -Method Get `
        -Uri $Uri `
        -UserAgent 'Palworld-Modding-Workshop' `
        -ErrorAction Stop
}

function Get-PwNexusEntryContentInventories {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Entry
    )

    if (-not $Entry.PSObject.Properties['ContentInventories']) {
        return @()
    }

    @($Entry.ContentInventories)
}

function Set-PwNexusFileContentInventoryRecord {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ModId,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Inventory,

        [string]$Path = (Get-PwNexusMetadataCachePath)
    )

    $cache = Read-PwNexusMetadataCache -Path $Path
    $entry = @(
        $cache.Mods |
            Where-Object NexusModId -eq $ModId
    ) | Select-Object -First 1

    if ($null -eq $entry) {
        throw "Nexus metadata cache has no entry for mod $ModId."
    }

    $inventories = @(
        Get-PwNexusEntryContentInventories -Entry $entry |
            Where-Object FileId -ne ([int]$Inventory.FileId)
    )
    $updatedInventories = @(
        @($inventories) + @($Inventory) |
            Sort-Object FileId
    )
    Set-PwObjectProperty `
        -InputObject $entry `
        -Name ContentInventories `
        -Value $updatedInventories
    Set-PwObjectProperty `
        -InputObject $cache `
        -Name ContentInventoryUpdatedAt `
        -Value ((Get-Date).ToUniversalTime().ToString('o'))
    Write-PwNexusMetadataCache -Cache $cache -Path $Path
    $Inventory
}

function Get-PwNexusFileContentInventory {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ModId,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$FileId,

        [string]$ApiKey,

        [string]$ArchivePath,

        [string]$ArchiveHash,

        [switch]$Refresh
    )

    $entry = Get-PwNexusMetadataEntry `
        -ModId $ModId `
        -ApiKey $ApiKey
    $file = Find-PwNexusCachedFile -Entry $entry -FileId $FileId

    if ($null -eq $file) {
        throw "Nexus file $FileId was not found for mod $ModId."
    }

    $fingerprint = Get-PwNexusFileMetadataFingerprint -File $file
    $existing = @(
        Get-PwNexusEntryContentInventories -Entry $entry |
            Where-Object FileId -eq $FileId
    ) | Select-Object -First 1

    if (-not [string]::IsNullOrWhiteSpace($ArchivePath)) {
        $resolvedArchivePath = [System.IO.Path]::GetFullPath($ArchivePath)

        if (-not (Test-Path -LiteralPath $resolvedArchivePath -PathType Leaf)) {
            throw "Archive path does not exist: $resolvedArchivePath"
        }

        $resolvedArchiveHash = if (
            -not [string]::IsNullOrWhiteSpace($ArchiveHash)
        ) {
            $ArchiveHash
        }
        else {
            (
                Get-FileHash `
                    -LiteralPath $resolvedArchivePath `
                    -Algorithm SHA256
            ).Hash
        }

        if (
            $null -ne $existing -and
            [string]$existing.Source -eq 'LocalArchiveInspection' -and
            [string]$existing.ArchiveHash -eq $resolvedArchiveHash
        ) {
            if ([string]$existing.FileMetadataFingerprint -ne $fingerprint) {
                Set-PwObjectProperty `
                    -InputObject $existing `
                    -Name FileMetadataFingerprint `
                    -Value $fingerprint
                return Set-PwNexusFileContentInventoryRecord `
                    -ModId $ModId `
                    -Inventory $existing
            }

            return $existing
        }

        $inspection = Get-PwModArchiveInfo -Path $resolvedArchivePath
        $paths = @(
            foreach ($inspectionEntry in @($inspection.Entries)) {
                if (
                    $inspectionEntry.PSObject.Properties['DeploymentRelativePath'] -and
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$inspectionEntry.DeploymentRelativePath
                    )
                ) {
                    [string]$inspectionEntry.DeploymentRelativePath
                    continue
                }

                if (
                    $inspectionEntry.PSObject.Properties['ArchivePath'] -and
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$inspectionEntry.ArchivePath
                    )
                ) {
                    [string]$inspectionEntry.ArchivePath
                }
            }
        )
        $classification = ConvertTo-PwNexusContentClassification -Path $paths
        $inventory = [PSCustomObject]@{
            FileId = $FileId
            FileMetadataFingerprint = $fingerprint
            Source = 'LocalArchiveInspection'
            Authority = 'Authoritative'
            Status = 'Ready'
            RetrievedAt = (Get-Date).ToUniversalTime().ToString('o')
            ContentPreviewLink = if (
                $file.PSObject.Properties['content_preview_link']
            ) {
                [string]$file.content_preview_link
            }
            else {
                ''
            }
            ArchivePath = $resolvedArchivePath
            ArchiveHash = $resolvedArchiveHash
            RawPreview = $null
            Paths = @($classification.Paths)
            FileCount = $classification.FileCount
            PackageTypes = @($classification.PackageTypes)
            DetectedRoots = @($classification.DetectedRoots)
            IsMixedPackage = $classification.IsMixedPackage
            LastError = ''
        }

        return Set-PwNexusFileContentInventoryRecord `
            -ModId $ModId `
            -Inventory $inventory
    }

    if (
        $null -ne $existing -and
        [string]$existing.Source -eq 'LocalArchiveInspection'
    ) {
        if ([string]$existing.FileMetadataFingerprint -ne $fingerprint) {
            Set-PwObjectProperty `
                -InputObject $existing `
                -Name FileMetadataFingerprint `
                -Value $fingerprint
            return Set-PwNexusFileContentInventoryRecord `
                -ModId $ModId `
                -Inventory $existing
        }

        return $existing
    }

    if (
        $null -ne $existing -and
        [string]$existing.FileMetadataFingerprint -eq $fingerprint -and
        -not $Refresh
    ) {
        return $existing
    }

    $previewLink = if ($file.PSObject.Properties['content_preview_link']) {
        [string]$file.content_preview_link
    }
    else {
        ''
    }
    $retrievedAt = (Get-Date).ToUniversalTime().ToString('o')

    if ([string]::IsNullOrWhiteSpace($previewLink)) {
        $inventory = [PSCustomObject]@{
            FileId = $FileId
            FileMetadataFingerprint = $fingerprint
            Source = 'NexusContentPreview'
            Authority = 'Advisory'
            Status = 'Unavailable'
            RetrievedAt = $retrievedAt
            ContentPreviewLink = ''
            ArchivePath = ''
            ArchiveHash = ''
            RawPreview = $null
            Paths = @()
            FileCount = 0
            PackageTypes = @('SupportOrUnknown')
            DetectedRoots = @()
            IsMixedPackage = $false
            LastError = 'Nexus file metadata did not provide a content preview.'
        }

        return Set-PwNexusFileContentInventoryRecord `
            -ModId $ModId `
            -Inventory $inventory
    }

    try {
        $rawPreview = Invoke-PwNexusContentPreviewRequest `
            -Uri ([uri]$previewLink)
        $paths = @(Get-PwNexusContentPreviewPaths -Response $rawPreview)
        $classification = ConvertTo-PwNexusContentClassification -Path $paths
        $inventory = [PSCustomObject]@{
            FileId = $FileId
            FileMetadataFingerprint = $fingerprint
            Source = 'NexusContentPreview'
            Authority = 'Advisory'
            Status = if ($paths.Count -gt 0) { 'Ready' } else { 'Empty' }
            RetrievedAt = $retrievedAt
            ContentPreviewLink = $previewLink
            ArchivePath = ''
            ArchiveHash = ''
            RawPreview = $rawPreview
            Paths = @($classification.Paths)
            FileCount = $classification.FileCount
            PackageTypes = @($classification.PackageTypes)
            DetectedRoots = @($classification.DetectedRoots)
            IsMixedPackage = $classification.IsMixedPackage
            LastError = ''
        }
    }
    catch {
        $inventory = [PSCustomObject]@{
            FileId = $FileId
            FileMetadataFingerprint = $fingerprint
            Source = 'NexusContentPreview'
            Authority = 'Advisory'
            Status = 'Error'
            RetrievedAt = $retrievedAt
            ContentPreviewLink = $previewLink
            ArchivePath = ''
            ArchiveHash = ''
            RawPreview = $null
            Paths = @()
            FileCount = 0
            PackageTypes = @('SupportOrUnknown')
            DetectedRoots = @()
            IsMixedPackage = $false
            LastError = $_.Exception.Message
        }
    }

    Set-PwNexusFileContentInventoryRecord `
        -ModId $ModId `
        -Inventory $inventory
}

function Update-PwNexusMetadataCache {

    [CmdletBinding()]
    param(
        [int[]]$ModId,

        [string]$ApiKey,

        [switch]$Refresh,

        [string]$Path = (Get-PwNexusMetadataCachePath)
    )

    $priorCache = if (Test-Path -LiteralPath $Path -PathType Leaf) {
        Read-PwNexusMetadataCache -Path $Path
    }
    else {
        New-PwEmptyNexusMetadataCache
    }
    $priorById = @{}

    foreach ($priorEntry in @($priorCache.Mods)) {
        if (
            $null -ne $priorEntry -and
            $priorEntry.PSObject.Properties['NexusModId']
        ) {
            $priorById[[int]$priorEntry.NexusModId] = $priorEntry
        }
    }

    $parameters = @{
        ApiKey = $ApiKey
        Path = $Path
    }

    if ($PSBoundParameters.ContainsKey('ModId')) {
        $parameters.ModId = $ModId
    }

    if ($Refresh) {
        $parameters.Refresh = $true
    }

    $cache = & $script:PwUpdateNexusMetadataCacheCore @parameters
    $inventoryChanged = $false

    foreach ($entry in @($cache.Mods)) {
        $retained = [System.Collections.Generic.List[object]]::new()
        $currentFilesById = @{}

        foreach ($file in @(Get-PwNexusResponseFiles -Response $entry.Files)) {
            if (
                $null -ne $file -and
                $file.PSObject.Properties['file_id']
            ) {
                $currentFilesById[[int]$file.file_id] = $file
            }
        }

        $priorEntry = if ($priorById.ContainsKey([int]$entry.NexusModId)) {
            $priorById[[int]$entry.NexusModId]
        }
        else {
            $null
        }
        $priorInventories = if ($null -ne $priorEntry) {
            @(Get-PwNexusEntryContentInventories -Entry $priorEntry)
        }
        else {
            @()
        }

        foreach ($inventory in $priorInventories) {
            if (
                $null -eq $inventory -or
                -not $inventory.PSObject.Properties['FileId']
            ) {
                continue
            }

            $fileId = [int]$inventory.FileId

            if ([string]$inventory.Source -eq 'LocalArchiveInspection') {
                $retained.Add($inventory)
                continue
            }

            if (-not $currentFilesById.ContainsKey($fileId)) {
                $inventoryChanged = $true
                continue
            }

            $currentFingerprint = Get-PwNexusFileMetadataFingerprint `
                -File $currentFilesById[$fileId]

            if (
                [string]$inventory.FileMetadataFingerprint -eq
                    $currentFingerprint
            ) {
                $retained.Add($inventory)
            }
            else {
                $inventoryChanged = $true
            }
        }

        $existingInventories = @(
            Get-PwNexusEntryContentInventories -Entry $entry
        )
        $retainedArray = @($retained | Sort-Object FileId)

        if (
            -not $entry.PSObject.Properties['ContentInventories'] -or
            ($existingInventories | ConvertTo-Json -Depth 100 -Compress) -ne
                ($retainedArray | ConvertTo-Json -Depth 100 -Compress)
        ) {
            Set-PwObjectProperty `
                -InputObject $entry `
                -Name ContentInventories `
                -Value $retainedArray
            $inventoryChanged = $true
        }
    }

    if ($inventoryChanged) {
        Set-PwObjectProperty `
            -InputObject $cache `
            -Name ContentInventoryUpdatedAt `
            -Value ((Get-Date).ToUniversalTime().ToString('o'))
        Write-PwNexusMetadataCache -Cache $cache -Path $Path
    }

    $cache
}

function Get-PwModUpdateReport {

    [CmdletBinding()]
    param(
        [string]$ApiKey,

        [int[]]$ModId,

        [Parameter(DontShow)]
        [object[]]$ArchiveMetadata
    )

    $parameters = @{}

    if ($PSBoundParameters.ContainsKey('ApiKey')) {
        $parameters.ApiKey = $ApiKey
    }

    if ($PSBoundParameters.ContainsKey('ModId')) {
        $parameters.ModId = $ModId
    }

    if ($PSBoundParameters.ContainsKey('ArchiveMetadata')) {
        $parameters.ArchiveMetadata = $ArchiveMetadata
    }

    $sourceArchives = if ($PSBoundParameters.ContainsKey('ArchiveMetadata')) {
        @($ArchiveMetadata)
    }
    else {
        @(Get-PwNexusArchiveMetadata -SkipContentInspection)
    }

    foreach ($archive in $sourceArchives) {
        if (
            $null -eq $archive -or
            -not $archive.PSObject.Properties['NexusModId'] -or
            -not $archive.PSObject.Properties['DownloadToken'] -or
            -not $archive.PSObject.Properties['ArchivePath']
        ) {
            continue
        }

        if ([string]$archive.DownloadToken -notmatch '^Api(?<fileId>\d+)$') {
            continue
        }

        try {
            $inventoryParameters = @{
                ModId = [int]$archive.NexusModId
                FileId = [int]$Matches['fileId']
                ArchivePath = [string]$archive.ArchivePath
                ApiKey = $ApiKey
            }

            if (
                $archive.PSObject.Properties['ArchiveHash'] -and
                -not [string]::IsNullOrWhiteSpace([string]$archive.ArchiveHash)
            ) {
                $inventoryParameters.ArchiveHash = [string]$archive.ArchiveHash
            }

            Get-PwNexusFileContentInventory @inventoryParameters | Out-Null
        }
        catch {
            # Local inventory enrichment must not block update reporting.
        }
    }

    $rows = @(& $script:PwGetModUpdateReportCore @parameters)

    foreach ($row in $rows) {
        $inventory = $null
        $inventoryError = ''

        if (
            $row.PSObject.Properties['RemoteFileId'] -and
            [int]$row.RemoteFileId -gt 0 -and
            [string]$row.Status -in @('Current', 'UpdateAvailable')
        ) {
            try {
                $inventory = Get-PwNexusFileContentInventory `
                    -ModId ([int]$row.NexusModId) `
                    -FileId ([int]$row.RemoteFileId) `
                    -ApiKey $ApiKey
            }
            catch {
                $inventoryError = $_.Exception.Message
            }
        }

        Set-PwObjectProperty `
            -InputObject $row `
            -Name RemoteContentInventoryStatus `
            -Value $(if ($null -ne $inventory) {
                [string]$inventory.Status
            } elseif (-not [string]::IsNullOrWhiteSpace($inventoryError)) {
                'Error'
            } else {
                'NotRequested'
            })
        Set-PwObjectProperty `
            -InputObject $row `
            -Name RemoteContentInventorySource `
            -Value $(if ($null -ne $inventory) {
                [string]$inventory.Source
            } else {
                ''
            })
        Set-PwObjectProperty `
            -InputObject $row `
            -Name RemotePackageTypes `
            -Value $(if ($null -ne $inventory) {
                @($inventory.PackageTypes)
            } else {
                @()
            })
        Set-PwObjectProperty `
            -InputObject $row `
            -Name RemoteDetectedRoots `
            -Value $(if ($null -ne $inventory) {
                @($inventory.DetectedRoots)
            } else {
                @()
            })
        Set-PwObjectProperty `
            -InputObject $row `
            -Name RemoteContentFileCount `
            -Value $(if ($null -ne $inventory) {
                [int]$inventory.FileCount
            } else {
                0
            })
        Set-PwObjectProperty `
            -InputObject $row `
            -Name RemoteIsMixedPackage `
            -Value $(if ($null -ne $inventory) {
                [bool]$inventory.IsMixedPackage
            } else {
                $false
            })
        Set-PwObjectProperty `
            -InputObject $row `
            -Name RemoteContentInventoryError `
            -Value $inventoryError
    }

    $rows
}

function Save-PwNexusModUpdateCore {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ModId,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$FileId,

        [string]$ApiKey,

        [string]$Destination = (Get-PwPaths).Archives
    )

    $parameters = @{
        ModId = $ModId
        FileId = $FileId
        ApiKey = $ApiKey
        Destination = $Destination
    }

    if ($PSBoundParameters.ContainsKey('WhatIf')) {
        $parameters.WhatIf = [bool]$PSBoundParameters['WhatIf']
    }

    if ($PSBoundParameters.ContainsKey('Confirm')) {
        $parameters.Confirm = [bool]$PSBoundParameters['Confirm']
    }

    $result = & $script:PwSaveNexusModUpdateCore @parameters

    if (
        $null -eq $result -or
        -not $result.PSObject.Properties['Downloaded'] -or
        -not [bool]$result.Downloaded -or
        -not $result.PSObject.Properties['Path'] -or
        [string]::IsNullOrWhiteSpace([string]$result.Path)
    ) {
        return $result
    }

    try {
        $inventory = Get-PwNexusFileContentInventory `
            -ModId $ModId `
            -FileId $FileId `
            -ApiKey $ApiKey `
            -ArchivePath ([string]$result.Path) `
            -ArchiveHash ([string]$result.Hash)
        Set-PwObjectProperty `
            -InputObject $result `
            -Name ContentInventorySource `
            -Value ([string]$inventory.Source)
        Set-PwObjectProperty `
            -InputObject $result `
            -Name PackageTypes `
            -Value @($inventory.PackageTypes)
        Set-PwObjectProperty `
            -InputObject $result `
            -Name DetectedRoots `
            -Value @($inventory.DetectedRoots)
        Set-PwObjectProperty `
            -InputObject $result `
            -Name IsMixedPackage `
            -Value ([bool]$inventory.IsMixedPackage)
        Set-PwObjectProperty `
            -InputObject $result `
            -Name ContentInventoryError `
            -Value ''
    }
    catch {
        Set-PwObjectProperty `
            -InputObject $result `
            -Name ContentInventorySource `
            -Value ''
        Set-PwObjectProperty `
            -InputObject $result `
            -Name PackageTypes `
            -Value @()
        Set-PwObjectProperty `
            -InputObject $result `
            -Name DetectedRoots `
            -Value @()
        Set-PwObjectProperty `
            -InputObject $result `
            -Name IsMixedPackage `
            -Value $false
        Set-PwObjectProperty `
            -InputObject $result `
            -Name ContentInventoryError `
            -Value $_.Exception.Message
    }

    $result
}
