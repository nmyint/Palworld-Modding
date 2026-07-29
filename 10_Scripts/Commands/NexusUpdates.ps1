<#
.SYNOPSIS
    Provides authenticated Nexus Mods update checks and downloads.
#>

Set-StrictMode -Version Latest

function Resolve-PwNexusApiKey {

    [CmdletBinding()]
    param(
        [string]$ApiKey
    )

    $resolved = if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
        $ApiKey
    }
    else {
        [Environment]::GetEnvironmentVariable('NEXUSMODS_API_KEY', 'Process')
    }

    if ([string]::IsNullOrWhiteSpace($resolved)) {
        throw (
            'Nexus API key not found. Set the NEXUSMODS_API_KEY environment ' +
            'variable; never save the key in this repository.'
        )
    }

    $resolved
}

function Invoke-PwNexusApi {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$ApiKey
    )

    $resolvedKey = Resolve-PwNexusApiKey -ApiKey $ApiKey
    $uri = 'https://api.nexusmods.com/v1/' + $Path.TrimStart('/')
    $headers = @{
        apikey = $resolvedKey
        'Application-Name' = 'Palworld-Modding-Workshop'
        'Application-Version' = (Get-PwVersion)
    }

    Invoke-RestMethod `
        -Method Get `
        -Uri $uri `
        -Headers $headers `
        -UserAgent 'Palworld-Modding-Workshop'
}

<#
.SYNOPSIS
    Validates the configured Nexus Mods API key.
.DESCRIPTION
    Returns account and API quota information without exposing the key.
#>
function Get-PwNexusApiIdentity {

    [CmdletBinding()]
    param(
        [string]$ApiKey
    )

    Invoke-PwNexusApi -Path 'users/validate.json' -ApiKey $ApiKey
}

function Get-PwLatestNexusFile {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Response,

        [string]$Variant
    )

    $files = if ($Response.PSObject.Properties['files']) {
        @($Response.files)
    }
    else {
        @($Response)
    }
    $mainFiles = @(
        $files |
            Where-Object {
                $_.category_id -eq 1 -or
                $_.category_name -eq 'MAIN'
            }
    )
    $candidates = if ($mainFiles.Count -gt 0) {
        $mainFiles
    }
    else {
        $files
    }

    if (-not [string]::IsNullOrWhiteSpace($Variant)) {
        $variantCandidates = @(
            $candidates |
                Where-Object {
                    (
                        Get-PwNexusFileVariant `
                            -FileName ([string]$_.file_name) `
                            -Version ([string]$_.version)
                    ) -eq $Variant
                }
        )

        if ($variantCandidates.Count -eq 0) {
            return $null
        }

        $candidates = $variantCandidates
    }

    $candidates |
        Sort-Object {
            if ($_.PSObject.Properties['uploaded_timestamp']) {
                [long]$_.uploaded_timestamp
            }
            else {
                0
            }
        } |
        Select-Object -Last 1
}

function Get-PwNexusFileVariant {

    [CmdletBinding()]
    param(
        [string]$FileName,

        [string]$Version
    )

    $identity = "$FileName $Version"

    if (
        $identity -match '(?i)(^|[\s_.()\-])SP(?:[\s_.\-]|$)' -or
        $identity -match '(?i)Single[\s_-]*player'
    ) {
        return 'SinglePlayer'
    }

    if (
        $identity -match '(?i)(^|[\s_.()\-])DS(?:[\s_.\-]|$)' -or
        $identity -match '(?i)Dedicated(?:[\s_-]*Server)?'
    ) {
        return 'DedicatedServer'
    }

    if (
        $identity -match '(?i)(^|[\s_.()\-])MP(?:[\s_.\-]|$)' -or
        $identity -match '(?i)Multi[\s_-]*player'
    ) {
        return 'MultiplayerHost'
    }

    ''
}

<#
.SYNOPSIS
    Checks known Nexus mods for newer main files.
.DESCRIPTION
    Uses Nexus IDs parsed from surviving files in 01_Archives. An update is
    reported when the newest remote main file was uploaded after the latest
    local download for that Nexus mod ID. No files are downloaded or changed.
#>
function Get-PwModUpdateReport {

    [CmdletBinding()]
    param(
        [string]$ApiKey,

        [int[]]$ModId,

        [Parameter(DontShow)]
        [object[]]$ArchiveMetadata
    )

    $sourceArchives = if ($PSBoundParameters.ContainsKey('ArchiveMetadata')) {
        @($ArchiveMetadata)
    }
    else {
        @(Get-PwNexusArchiveMetadata -SkipContentInspection)
    }
    $archives = @(
        $sourceArchives |
            Where-Object { $_.IsParsed -and $_.NexusModId }
    )
    $requestedModIds = @(
        $ModId |
            Where-Object { $_ -gt 0 }
    )
    $groups = @(
        $archives |
            Group-Object NexusModId
    )

    if ($requestedModIds.Count -gt 0) {
        $groups = @(
            $groups |
                Where-Object { [int]$_.Name -in $requestedModIds }
        )
    }

    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($group in $groups) {
        $id = [int]$group.Name
        $local = @($group.Group | Sort-Object DownloadedAt)[-1]
        $localFileName = if (
            $local.PSObject.Properties['OriginalFileName']
        ) {
            [string]$local.OriginalFileName
        }
        else {
            [string]$local.Name
        }
        $localVariant = Get-PwNexusFileVariant `
            -FileName $localFileName `
            -Version ([string]$local.ArchiveVersion)

        try {
            $mod = Invoke-PwNexusApi `
                -Path "games/palworld/mods/$id.json" `
                -ApiKey $ApiKey
            $fileResponse = Invoke-PwNexusApi `
                -Path "games/palworld/mods/$id/files.json" `
                -ApiKey $ApiKey
            $latestFile = Get-PwLatestNexusFile `
                -Response $fileResponse `
                -Variant $localVariant
            $remoteUploadedAt = if (
                $latestFile -and
                $latestFile.PSObject.Properties['uploaded_timestamp']
            ) {
                [datetimeoffset]::FromUnixTimeSeconds(
                    [long]$latestFile.uploaded_timestamp
                ).UtcDateTime
            }
            else {
                $null
            }
            $status = if (
                -not $latestFile -and
                -not [string]::IsNullOrWhiteSpace($localVariant)
            ) {
                'VariantNotFound'
            }
            elseif (-not $latestFile) {
                'NoRemoteFiles'
            }
            else {
                $remoteVersion = [string]$latestFile.version
                $localVersion = [string]$local.ArchiveVersion

                if (
                    -not [string]::IsNullOrWhiteSpace($remoteVersion) -and
                    -not [string]::IsNullOrWhiteSpace($localVersion)
                ) {
                    if ($remoteVersion -ne $localVersion) {
                        'UpdateAvailable'
                    }
                    else {
                        'Current'
                    }
                }
                elseif ($remoteUploadedAt -gt $local.DownloadedAt) {
                    'UpdateAvailable'
                }
                else {
                    'Current'
                }
            }

            $results.Add([PSCustomObject]@{
                Name = [string]$mod.name
                NexusModId = $id
                LocalVersion = [string]$local.ArchiveVersion
                LocalDownloadedAt = $local.DownloadedAt
                RemoteVersion = if ($latestFile) {
                    [string]$latestFile.version
                }
                else {
                    [string]$mod.version
                }
                RemoteUploadedAt = $remoteUploadedAt
                RemoteFileId = if ($latestFile) {
                    [int]$latestFile.file_id
                }
                else {
                    0
                }
                RemoteFileName = if ($latestFile) {
                    [string]$latestFile.file_name
                }
                else {
                    ''
                }
                LocalVariant = $localVariant
                RemoteVariant = if ($latestFile) {
                    Get-PwNexusFileVariant `
                        -FileName ([string]$latestFile.file_name) `
                        -Version ([string]$latestFile.version)
                }
                else {
                    ''
                }
                Status = $status
                ManualUrl = (
                    "https://www.nexusmods.com/palworld/mods/${id}?tab=files"
                )
                Error = ''
            })
        }
        catch {
            $results.Add([PSCustomObject]@{
                Name = [string]$local.Name
                NexusModId = $id
                LocalVersion = [string]$local.ArchiveVersion
                LocalDownloadedAt = $local.DownloadedAt
                RemoteVersion = ''
                RemoteUploadedAt = $null
                RemoteFileId = 0
                RemoteFileName = ''
                LocalVariant = $localVariant
                RemoteVariant = ''
                Status = 'CheckFailed'
                ManualUrl = (
                    "https://www.nexusmods.com/palworld/mods/${id}?tab=files"
                )
                Error = $_.Exception.Message
            })
        }
    }

    @($results | Sort-Object Name)
}

<#
.SYNOPSIS
    Returns or opens the Nexus file page for a Palworld mod.
.PARAMETER Launch
    Opens the page in the default browser. Without this switch, only returns
    the URL.
#>
function Open-PwNexusModPage {

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ModId,

        [switch]$Launch
    )

    $url = "https://www.nexusmods.com/palworld/mods/${ModId}?tab=files"

    if ($Launch -and $PSCmdlet.ShouldProcess($url, 'Open Nexus Mods page')) {
        Start-Process $url
    }

    $url
}

function Get-PwDownloadExecutable {

    [CmdletBinding()]
    param()

    $wget = Get-Command wget.exe -ErrorAction SilentlyContinue

    if ($wget) {
        return [PSCustomObject]@{
            Name = 'wget'
            Path = $wget.Source
        }
    }

    $localWget = Join-Path `
        ([Environment]::GetFolderPath('LocalApplicationData')) `
        'Programs\Wget\wget.exe'

    if (Test-Path -LiteralPath $localWget -PathType Leaf) {
        return [PSCustomObject]@{
            Name = 'wget'
            Path = $localWget
        }
    }

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue

    if ($curl) {
        return [PSCustomObject]@{
            Name = 'curl'
            Path = $curl.Source
        }
    }

    [PSCustomObject]@{
        Name = 'PowerShell'
        Path = ''
    }
}

function Save-PwRemoteFile {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$Uri,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $downloader = Get-PwDownloadExecutable
    $nativeExitCode = 0

    switch ($downloader.Name) {
        'wget' {
            & $downloader.Path `
                '--continue' `
                "--output-document=$Path" `
                '--' `
                $Uri.AbsoluteUri
            $nativeExitCode = $LASTEXITCODE
        }
        'curl' {
            & $downloader.Path `
                '--fail' `
                '--location' `
                '--continue-at' `
                '-' `
                '--output' `
                $Path `
                '--' `
                $Uri.AbsoluteUri
            $nativeExitCode = $LASTEXITCODE
        }
        default {
            Invoke-WebRequest -Uri $Uri -OutFile $Path
        }
    }

    if ($nativeExitCode -ne 0) {
        throw (
            "$($downloader.Name) download failed with exit code " +
                "$nativeExitCode."
        )
    }
}

<#
.SYNOPSIS
    Downloads a selected Nexus file into 01_Archives.
.DESCRIPTION
    Direct API download links normally require Nexus Premium. The file is first
    downloaded to a temporary path, inspected with the workshop safety checks,
    and only then moved into 01_Archives using the catalog filename convention.
#>
function Save-PwNexusModUpdate {

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

    $identity = Get-PwNexusApiIdentity -ApiKey $ApiKey

    if (-not $identity.is_premium) {
        throw (
            'Direct API downloads require Nexus Premium. Use ' +
            "Open-PwNexusModPage -ModId $ModId -Launch for manual download."
        )
    }

    $mod = Invoke-PwNexusApi `
        -Path "games/palworld/mods/$ModId.json" `
        -ApiKey $ApiKey
    $file = Invoke-PwNexusApi `
        -Path "games/palworld/mods/$ModId/files/$FileId.json" `
        -ApiKey $ApiKey
    $links = @(
        Invoke-PwNexusApi `
            -Path (
                "games/palworld/mods/$ModId/files/$FileId/" +
                    'download_link.json'
            ) `
            -ApiKey $ApiKey
    )

    if ($links.Count -eq 0 -or -not $links[0].URI) {
        throw 'Nexus did not return a direct download link.'
    }

    $extension = [System.IO.Path]::GetExtension([string]$file.file_name)

    if ($extension -notin @('.zip', '.7z')) {
        throw "Unsupported Nexus archive format: $extension"
    }

    $safeName = ([string]$mod.name -replace '[<>:"/\\|?*]', '_').Trim()
    $version = ([string]$file.version -replace '\s+', '_').Trim()

    if ([string]::IsNullOrWhiteSpace($safeName)) {
        $safeName = "NexusMod-$ModId"
    }

    if ([string]::IsNullOrWhiteSpace($version)) {
        $version = 'unknown'
    }

    $timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH-mmZ')
    $fileName = (
        "$safeName $ModId $version $timestamp Api$FileId$extension"
    )
    $destinationRoot = [System.IO.Path]::GetFullPath($Destination)
    $destinationPath = Join-Path $destinationRoot $fileName

    if (Test-Path -LiteralPath $destinationPath) {
        throw "Archive already exists: $destinationPath"
    }

    if (-not $PSCmdlet.ShouldProcess(
        $destinationPath,
        "Download Nexus mod $ModId file $FileId"
    )) {
        return [PSCustomObject]@{
            Downloaded = $false
            Path = $destinationPath
            ModId = $ModId
            FileId = $FileId
        }
    }

    New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null
    $temporaryPath = Join-Path `
        ([System.IO.Path]::GetTempPath()) `
        ([System.IO.Path]::GetRandomFileName() + $extension)

    try {
        Save-PwRemoteFile -Uri ([uri]$links[0].URI) -Path $temporaryPath
        $inspection = Get-PwModArchiveInfo -Path $temporaryPath

        if (-not $inspection.IsSafe) {
            throw 'Downloaded archive failed workshop safety inspection.'
        }

        Move-Item -LiteralPath $temporaryPath -Destination $destinationPath
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }

    [PSCustomObject]@{
        Downloaded = $true
        Path = $destinationPath
        ModId = $ModId
        FileId = $FileId
        Version = $version
        Hash = (
            Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256
        ).Hash
    }
}

function Get-PwProfileModDownloadPlan {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfileName,

        [string]$SetName = '',

        [bool]$MissingOnly = $true,

        [string]$ApiKey
    )

    $profileSets = @(Get-PwProfileModSets -Name $ProfileName)
    if ($profileSets.Count -eq 0) {
        return @()
    }

    $selectedSet = if ([string]::IsNullOrWhiteSpace($SetName)) {
        $profileSets | Where-Object IsActive | Select-Object -First 1
    }
    else {
        $profileSets | Where-Object Name -eq $SetName | Select-Object -First 1
    }

    if (-not $selectedSet) {
        $selectedSet = $profileSets | Select-Object -First 1
    }

    $catalog = @(Get-PwPersistentModCatalog)
    $catalogByKey = @{}
    foreach ($record in @($catalog.Mods)) {
        $catalogByKey[[string]$record.CatalogKey] = $record
    }

    $selectedKeys = @($selectedSet.CatalogKeys | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_)
    })

    foreach ($catalogKey in $selectedKeys) {
        $record = $catalogByKey[[string]$catalogKey]

        if (-not $record) {
            [PSCustomObject]@{
                Profile = $ProfileName
                ModSet = [string]$selectedSet.Name
                CatalogKey = [string]$catalogKey
                DisplayName = ''
                NexusModId = $null
                RemoteFileId = $null
                RemoteFileName = ''
                RemoteVersion = ''
                LocalArchivePresent = $false
                Status = 'CatalogMissing'
                Reason = 'No catalog record exists for this catalog key.'
            }

            continue
        }

        $nexusModId = @($record.NexusModIds | Where-Object { $_ -gt 0 }) |
            Select-Object -First 1
        $archivePresent = @($record.ArchiveVersions).Count -gt 0 -and (
            @($record.ArchiveVersions | Where-Object ArchivePresent).Count -gt 0
        )

        if ($MissingOnly -and $archivePresent) {
            [PSCustomObject]@{
                Profile = $ProfileName
                ModSet = [string]$selectedSet.Name
                CatalogKey = [string]$record.CatalogKey
                DisplayName = [string]$record.DisplayName
                NexusModId = [int]$nexusModId
                RemoteFileId = $null
                RemoteFileName = ''
                RemoteVersion = ''
                LocalArchivePresent = $true
                Status = 'AlreadyPresent'
                Reason = 'A matching archive already exists in the catalog.'
            }

            continue
        }

        if (-not $nexusModId) {
            [PSCustomObject]@{
                Profile = $ProfileName
                ModSet = [string]$selectedSet.Name
                CatalogKey = [string]$record.CatalogKey
                DisplayName = [string]$record.DisplayName
                NexusModId = $null
                RemoteFileId = $null
                RemoteFileName = ''
                RemoteVersion = ''
                LocalArchivePresent = $archivePresent
                Status = 'NeedsNexusId'
                Reason = 'No Nexus mod ID is recorded for this mod.'
            }

            continue
        }

        try {
            $mod = Invoke-PwNexusApi `
                -Path "games/palworld/mods/$nexusModId.json" `
                -ApiKey $ApiKey
            $files = Invoke-PwNexusApi `
                -Path "games/palworld/mods/$nexusModId/files.json" `
                -ApiKey $ApiKey
            $latestFile = Get-PwLatestNexusFile -Response $files

            if (-not $latestFile) {
                [PSCustomObject]@{
                    Profile = $ProfileName
                    ModSet = [string]$selectedSet.Name
                    CatalogKey = [string]$record.CatalogKey
                    DisplayName = [string]$record.DisplayName
                    NexusModId = [int]$nexusModId
                    RemoteFileId = $null
                    RemoteFileName = ''
                    RemoteVersion = ''
                    LocalArchivePresent = $archivePresent
                    Status = 'NoRemoteFiles'
                    Reason = 'Nexus returned no downloadable files.'
                }

                continue
            }

            [PSCustomObject]@{
                Profile = $ProfileName
                ModSet = [string]$selectedSet.Name
                CatalogKey = [string]$record.CatalogKey
                DisplayName = [string]$record.DisplayName
                NexusModId = [int]$nexusModId
                RemoteFileId = [int]$latestFile.file_id
                RemoteFileName = [string]$latestFile.file_name
                RemoteVersion = [string]$latestFile.version
                LocalArchivePresent = $archivePresent
                Status = 'Ready'
                Reason = ''
            }
        }
        catch {
            [PSCustomObject]@{
                Profile = $ProfileName
                ModSet = [string]$selectedSet.Name
                CatalogKey = [string]$record.CatalogKey
                DisplayName = [string]$record.DisplayName
                NexusModId = [int]$nexusModId
                RemoteFileId = $null
                RemoteFileName = ''
                RemoteVersion = ''
                LocalArchivePresent = $archivePresent
                Status = 'CheckFailed'
                Reason = $_.Exception.Message
            }
        }
    }
}

function Save-PwProfileModDownloads {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfileName,

        [string]$SetName = '',

        [bool]$MissingOnly = $true,

        [string]$ApiKey
    )

    $plan = @(
        Get-PwProfileModDownloadPlan `
            -ProfileName $ProfileName `
            -SetName $SetName `
            -MissingOnly:$MissingOnly `
            -ApiKey $ApiKey
    )

    foreach ($item in $plan) {
        if ($item.Status -ne 'Ready') {
            continue
        }

        if (-not $PSCmdlet.ShouldProcess(
            $item.DisplayName,
            "Download Nexus mod $($item.NexusModId) file $($item.RemoteFileId)"
        )) {
            continue
        }

        Save-PwNexusModUpdate `
            -ModId $item.NexusModId `
            -FileId $item.RemoteFileId `
            -ApiKey $ApiKey | Out-Null
    }

    $plan
}
