<#
.SYNOPSIS
    Checks explicitly configured Nexus Mods and GitHub release sources.
.DESCRIPTION
    Keeps the preferred provider authoritative. Links discovered in Nexus
    descriptions are returned as advisory metadata and never switch providers.
#>

Set-StrictMode -Version Latest

function Get-PwUpdateSourceConfigPath {

    [CmdletBinding()]
    param()

    Join-Path (Get-PwWorkshopRoot) '.config\UpdateSources.json'
}

function Get-PwUpdateSources {

    [CmdletBinding()]
    param(
        [switch]$IncludeDisabled
    )

    $configuration = Read-PwJson -Path (Get-PwUpdateSourceConfigPath)

    if ($configuration.SchemaVersion -ne '1.0') {
        throw "Unsupported update-source schema '$($configuration.SchemaVersion)'."
    }

    if (-not $configuration.Enabled -and -not $IncludeDisabled) {
        return @()
    }

    @(
        $configuration.Sources |
            Where-Object { $IncludeDisabled -or $_.Enabled }
    )
}

function Invoke-PwGitHubApi {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $headers = @{
        Accept = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
        'User-Agent' = 'Palworld-Modding-Workshop'
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
        $headers.Authorization = "Bearer $($env:GITHUB_TOKEN)"
    }

    Invoke-RestMethod `
        -Uri "https://api.github.com/$($Path.TrimStart('/'))" `
        -Headers $headers `
        -Method Get `
        -ErrorAction Stop
}

function Get-PwGitHubReleaseSource {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Source
    )

    $repository = [string]$Source.Repository
    $tag = [string]$Source.ReleaseTag
    $release = Invoke-PwGitHubApi `
        -Path "repos/$repository/releases/tags/$tag"
    $assets = @($release.assets)
    $assetPattern = [string]$Source.AssetPattern

    if (-not [string]::IsNullOrWhiteSpace($assetPattern)) {
        $assets = @($assets | Where-Object name -Match $assetPattern)
    }

    if ($assets.Count -ne 1) {
        throw (
            "Expected exactly one GitHub asset for '$($Source.Key)' but found " +
                "$($assets.Count). Check AssetPattern in UpdateSources.json."
        )
    }

    $asset = $assets[0]
    $installedAssetId = $Source.InstalledAssetId
    $installedUpdatedAt = [string]$Source.InstalledAssetUpdatedAt
    $remoteUpdatedAt = ([datetime]$asset.updated_at).ToUniversalTime()
    $status = 'Untracked'

    if ($null -ne $installedAssetId -and [long]$installedAssetId -gt 0) {
        if (
            [long]$installedAssetId -eq [long]$asset.id -and
            -not [string]::IsNullOrWhiteSpace($installedUpdatedAt) -and
            ([datetime]$installedUpdatedAt).ToUniversalTime() -ge $remoteUpdatedAt
        ) {
            $status = 'Current'
        }
        else {
            $status = 'UpdateAvailable'
        }
    }

    [PSCustomObject]@{
        Key = [string]$Source.Key
        Name = [string]$Source.DisplayName
        Provider = 'GitHubRelease'
        Source = "https://github.com/$repository/releases/tag/$tag"
        LocalVersion = $installedUpdatedAt
        RemoteVersion = $tag
        RemoteFileId = [long]$asset.id
        RemoteFileName = [string]$asset.name
        RemoteUpdatedAt = $remoteUpdatedAt
        DownloadUrl = [string]$asset.browser_download_url
        Status = $status
        DiscoveredGitHubSources = @()
    }
}

function Get-PwGitHubLinksFromText {

    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    @(
        [regex]::Matches(
            $Text,
            'https?://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' +
                '(?:/releases(?:/tag/[A-Za-z0-9_.-]+)?)?'
        ) |
            ForEach-Object { $_.Value } |
            ForEach-Object { $_.TrimEnd('.', ',', ')', ']', '"', "'") } |
            Sort-Object -Unique
    )
}

function Get-PwNexusUpdateSource {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Source,

        [string]$ApiKey
    )

    $id = [int]$Source.NexusModId
    $mod = Invoke-PwNexusApi `
        -Path "games/palworld/mods/$id.json" `
        -ApiKey $ApiKey
    $files = Invoke-PwNexusApi `
        -Path "games/palworld/mods/$id/files.json" `
        -ApiKey $ApiKey
    $latest = Get-PwLatestNexusFile -Response $files
    $localVersion = [string]$Source.InstalledVersion
    $remoteVersion = if (
        -not [string]::IsNullOrWhiteSpace([string]$latest.version)
    ) {
        [string]$latest.version
    }
    else {
        [string]$mod.version
    }
    $status = if ([string]::IsNullOrWhiteSpace($localVersion)) {
        'Untracked'
    }
    elseif ($localVersion -eq $remoteVersion) {
        'Current'
    }
    else {
        'UpdateAvailable'
    }

    [PSCustomObject]@{
        Key = [string]$Source.Key
        Name = [string]$Source.DisplayName
        Provider = 'NexusMods'
        Source = "https://www.nexusmods.com/palworld/mods/$id"
        LocalVersion = $localVersion
        RemoteVersion = $remoteVersion
        RemoteFileId = [long]$latest.file_id
        RemoteFileName = [string]$latest.file_name
        RemoteUpdatedAt = [datetimeoffset]::FromUnixTimeSeconds(
            [long]$latest.uploaded_timestamp
        ).UtcDateTime
        DownloadUrl = (
            "https://www.nexusmods.com/palworld/mods/${id}?tab=files"
        )
        Status = $status
        DiscoveredGitHubSources = @(
            Get-PwGitHubLinksFromText -Text ([string]$mod.description)
        )
    }
}

function Get-PwSourceUpdateReport {

    [CmdletBinding()]
    param(
        [string]$ApiKey,

        [object[]]$Sources
    )

    $configuredSources = if ($PSBoundParameters.ContainsKey('Sources')) {
        @($Sources | Where-Object Enabled)
    }
    else {
        @(Get-PwUpdateSources)
    }

    foreach ($source in $configuredSources) {
        switch ([string]$source.Provider) {
            'GitHubRelease' {
                Get-PwGitHubReleaseSource -Source $source
            }
            'NexusMods' {
                Get-PwNexusUpdateSource -Source $source -ApiKey $ApiKey
            }
            default {
                throw (
                    "Unsupported update provider '$($source.Provider)' for " +
                        "'$($source.Key)'."
                )
            }
        }
    }
}

function Set-PwGitHubSourceBaseline {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [string]$Key
    )

    $path = Get-PwUpdateSourceConfigPath
    $configuration = Read-PwJson -Path $path
    $source = @(
        $configuration.Sources |
            Where-Object {
                $_.Key -eq $Key -and $_.Provider -eq 'GitHubRelease'
            }
    ) | Select-Object -First 1

    if (-not $source) {
        throw "GitHub update source '$Key' was not found."
    }

    $remote = Get-PwGitHubReleaseSource -Source $source

    if ($PSCmdlet.ShouldProcess($path, "Record installed baseline for '$Key'")) {
        $source.InstalledAssetId = $remote.RemoteFileId
        $source.InstalledAssetUpdatedAt = (
            $remote.RemoteUpdatedAt.ToUniversalTime().ToString('o')
        )
        Write-PwJson -InputObject $configuration -Path $path
    }

    $remote
}
