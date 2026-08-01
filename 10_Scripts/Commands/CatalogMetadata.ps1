<#
.SYNOPSIS
    Enriches missing-archive catalog records with remote Nexus metadata.
.DESCRIPTION
    Uses reviewed Nexus IDs whenever available and compares the Nexus page name
    with local install-folder names. Records without an ID are reported for
    manual search because the supported personal-key API has no general
    name-search endpoint.
#>

Set-StrictMode -Version Latest

function ConvertTo-PwComparableModName {

    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    $normalized = (
        $Value -replace '[^a-zA-Z0-9]', ''
    ).ToLowerInvariant()

    $normalized -replace '^palworld', '' -replace 'palworld$', '' -replace 'mod$', ''
}

function Get-PwModNameMatch {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$InstallNames,

        [Parameter(Mandatory)]
        [string]$RemoteName
    )

    $remote = ConvertTo-PwComparableModName -Value $RemoteName
    $best = 'Review'

    foreach ($installName in $InstallNames) {
        $local = ConvertTo-PwComparableModName -Value $installName

        if ($local -eq $remote) {
            return 'Exact'
        }

        if (
            $local.Length -ge 5 -and
            ($remote.Contains($local) -or $local.Contains($remote))
        ) {
            $best = 'Strong'
        }
    }

    $best
}

function ConvertTo-PwGitHubSource {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Url
    )

    $match = [regex]::Match(
        $Url,
        '^https?://github\.com/(?<owner>[A-Za-z0-9_.-]+)/' +
            '(?<repo>[A-Za-z0-9_.-]+?)(?:\.git)?' +
            '(?:/releases(?:/tag/(?<tag>[A-Za-z0-9_.-]+))?)?/?$'
    )

    if (-not $match.Success) {
        return $null
    }

    $repository = (
        "$($match.Groups['owner'].Value)/$($match.Groups['repo'].Value)"
    )
    $tag = [string]$match.Groups['tag'].Value

    [PSCustomObject]@{
        Repository = $repository
        RepositoryUrl = "https://github.com/$repository"
        ReleasesUrl = "https://github.com/$repository/releases"
        ReleaseTag = $tag
        SourceUrl = $Url
    }
}

function Get-PwGitHubSourcesFromText {

    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    @(
        Get-PwGitHubLinksFromText `
            -Text ([System.Net.WebUtility]::HtmlDecode($Text)) |
            ForEach-Object { ConvertTo-PwGitHubSource -Url $_ } |
            Where-Object { $null -ne $_ } |
            Sort-Object Repository, ReleaseTag -Unique
    )
}

function Get-PwNexusCatalogMetadataReport {

    [CmdletBinding()]
    param(
        [string]$ApiKey,

        [object]$Catalog = (Get-PwPersistentModCatalog)
    )

    $records = @(
        $Catalog.Mods |
            Where-Object {
                $versions = if ($_.PSObject.Properties['Versions']) {
                    @($_.Versions)
                }
                else {
                    @()
                }
                $_.Source -ne 'UE4SSBundled' -and
                $_.CatalogKey -ne 'pal' -and
                @($versions | Where-Object ArchivePresent).Count -eq 0
            }
    )

    foreach ($record in $records) {
        $installNames = @(
            if ($record.PSObject.Properties['InstallNames']) {
                @($record.InstallNames) |
                    Where-Object {
                        -not [string]::IsNullOrWhiteSpace([string]$_)
                    }
            }
        )
        $ids = @(
            if ($record.PSObject.Properties['NexusModIds']) {
                @($record.NexusModIds) |
                    Where-Object {
                        $null -ne $_ -and
                        [string]$_ -match '^\d+$' -and
                        [int]$_ -gt 0
                    } |
                    ForEach-Object { [int]$_ } |
                    Sort-Object -Unique
            }
        )
        $searchTerm = if ($installNames.Count -gt 0) {
            [string]$installNames[0]
        }
        elseif (
            $record.PSObject.Properties['DisplayName'] -and
            -not [string]::IsNullOrWhiteSpace([string]$record.DisplayName)
        ) {
            [string]$record.DisplayName
        }
        else {
            [string]$record.CatalogKey
        }

        if ($ids.Count -eq 0) {
            [PSCustomObject]@{
                CatalogKey = [string]$record.CatalogKey
                InstallNames = $installNames
                SearchTerm = $searchTerm
                NexusModId = $null
                RemoteName = ''
                RemoteVersion = ''
                Summary = ''
                NameMatch = 'Unavailable'
                GitSources = @()
                Status = 'NeedsNexusId'
                Error = ''
            }
            continue
        }

        foreach ($id in $ids) {
            try {
                $mod = Invoke-PwNexusApi `
                    -Path "games/palworld/mods/$id.json" `
                    -ApiKey $ApiKey

                if (-not $mod.PSObject.Properties['name']) {
                    $message = if ($mod.PSObject.Properties['message']) {
                        [string]$mod.message
                    }
                    else {
                        'Nexus returned no mod metadata.'
                    }
                    throw $message
                }
            }
            catch {
                [PSCustomObject]@{
                    CatalogKey = [string]$record.CatalogKey
                    InstallNames = $installNames
                    SearchTerm = $searchTerm
                    NexusModId = [int]$id
                    RemoteName = ''
                    RemoteVersion = ''
                    Summary = ''
                    NameMatch = 'Unavailable'
                    GitSources = @()
                    Status = 'ApiUnavailable'
                    Error = $_.Exception.Message
                }
                continue
            }

            $nameMatch = Get-PwModNameMatch `
                -InstallNames $installNames `
                -RemoteName ([string]$mod.name)

            [PSCustomObject]@{
                CatalogKey = [string]$record.CatalogKey
                InstallNames = $installNames
                SearchTerm = $searchTerm
                NexusModId = [int]$id
                RemoteName = [string]$mod.name
                RemoteVersion = [string]$mod.version
                Summary = [string]$mod.summary
                NameMatch = $nameMatch
                GitSources = @(
                    Get-PwGitHubSourcesFromText -Text ([string]$mod.description)
                )
                Status = if ($nameMatch -eq 'Review') {
                    'ReviewIdentity'
                }
                else {
                    'MetadataFound'
                }
                Error = ''
            }
        }
    }
}

function Get-PwNexusModIdentity {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ModId,

        [string[]]$InstallNames = @(),

        [string]$ApiKey
    )

    $mod = Invoke-PwNexusApi `
        -Path "games/palworld/mods/$ModId.json" `
        -ApiKey $ApiKey

    if (-not $mod.PSObject.Properties['name']) {
        $message = if ($mod.PSObject.Properties['message']) {
            [string]$mod.message
        }
        else {
            'Nexus returned no mod metadata.'
        }
        throw $message
    }

    $gitSources = @(
        Get-PwGitHubSourcesFromText -Text ([string]$mod.description)
    )
    $frameworkText = @(
        [string]$mod.name
        [string]$mod.summary
        [string]$mod.description
    ) -join ' '
    $frameworkHints = @(
        if ($frameworkText -match '(?i)\bPalSchema\b') {
            'PalSchema'
        }
        if ($frameworkText -match '(?i)\bUE4SS\b') {
            'UE4SS'
        }
    )
    $isPalSchemaAddon = $frameworkHints -contains 'PalSchema'

    [PSCustomObject]@{
        NexusModId = $ModId
        Name = [string]$mod.name
        Version = [string]$mod.version
        Summary = [string]$mod.summary
        NameMatch = if ($InstallNames.Count -gt 0) {
            Get-PwModNameMatch `
                -InstallNames $InstallNames `
                -RemoteName ([string]$mod.name)
        }
        else {
            'NotCompared'
        }
        GitSources = $gitSources
        FrameworkHints = $frameworkHints
        ExpectedInstallRoot = if ($isPalSchemaAddon) {
            'Pal\Binaries\Win64\ue4ss\Mods\PalSchema\mods'
        }
        else {
            ''
        }
        RoutingAuthority = if ($isPalSchemaAddon) {
            'HintOnlyArchiveRequired'
        }
        else {
            'ArchiveRequired'
        }
        NexusUrl = "https://www.nexusmods.com/palworld/mods/$ModId"
    }
}

function Update-PwNexusCatalogMetadata {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [string]$ApiKey,

        [string]$Path = (Get-PwCatalogManifestPath)
    )

    $catalog = Get-PwPersistentModCatalog -Path $Path
    $report = @(
        Get-PwNexusCatalogMetadataReport `
            -ApiKey $ApiKey `
            -Catalog $catalog
    )
    $retrievedAt = (Get-Date).ToUniversalTime().ToString('o')

    foreach ($result in $report) {
        if ($result.Status -notin @('MetadataFound', 'ReviewIdentity')) {
            continue
        }

        $record = $catalog.Mods |
            Where-Object CatalogKey -eq $result.CatalogKey |
            Select-Object -First 1
        $metadata = [PSCustomObject]@{
            Provider = 'NexusMods'
            NexusModId = $result.NexusModId
            Name = $result.RemoteName
            Version = $result.RemoteVersion
            Summary = $result.Summary
            NameMatch = $result.NameMatch
            GitSources = @($result.GitSources)
            RetrievedAt = $retrievedAt
        }

        if ($record.PSObject.Properties['RemoteMetadata']) {
            $record.RemoteMetadata = $metadata
        }
        else {
            $record | Add-Member `
                -NotePropertyName RemoteMetadata `
                -NotePropertyValue $metadata
        }
    }

    if ($PSCmdlet.ShouldProcess($Path, 'Update remote Nexus catalog metadata')) {
        $catalog.UpdatedAt = $retrievedAt
        Write-PwJson -InputObject $catalog -Path $Path -Depth 20
    }

    $report
}
