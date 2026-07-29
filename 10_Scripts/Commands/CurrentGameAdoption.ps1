<#
.SYNOPSIS
    Adopts current-game-only mod payloads into the managed workshop.
#>

Set-StrictMode -Version Latest

function Get-PwCurrentGameOnlyMods {

    [CmdletBinding()]
    param()

    $readiness = Test-PwDeploymentReadiness
    @(
        $readiness.CurrentGameOnly |
            Where-Object Classification -eq 'ModPayload' |
            ForEach-Object {
                $relativePath = ([string]$_.RelativePath).Replace('\', '/')
                $candidateName = if (
                    $relativePath -match '(?i)ue4ss/Mods/([^/]+)/'
                ) {
                    $Matches[1]
                }
                else {
                    $leaf = [System.IO.Path]::GetFileNameWithoutExtension(
                        $relativePath
                    )
                    $leaf -replace '(?i)\.modconfig$', '' -replace '(?i)_P$', ''
                }

                [PSCustomObject]@{
                    CandidateName = $candidateName
                    RelativePath = [string]$_.RelativePath
                    GamePath = [string]$_.GamePath
                    Hash = [string]$_.GameHash
                }
            } |
            Group-Object CandidateName |
            ForEach-Object {
                [PSCustomObject]@{
                    CandidateName = $_.Name
                    FileCount = $_.Count
                    Files = @($_.Group)
                }
            } |
            Sort-Object CandidateName
    )
}

function Get-PwCurrentGameModAdoptionPlan {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CandidateName,

        [ValidateRange(1, [int]::MaxValue)]
        [int]$NexusModId
    )

    $candidate = Get-PwCurrentGameOnlyMods |
        Where-Object CandidateName -eq $CandidateName |
        Select-Object -First 1

    if (-not $candidate) {
        throw "Current-game-only candidate was not found: $CandidateName"
    }

    $catalogKey = ConvertTo-PwCatalogKey -Value $CandidateName
    $catalog = Get-PwPersistentModCatalog
    $record = $catalog.Mods |
        Where-Object CatalogKey -eq $catalogKey |
        Select-Object -First 1
    $identity = if ($PSBoundParameters.ContainsKey('NexusModId')) {
        Get-PwNexusModIdentity `
            -ModId $NexusModId `
            -InstallNames @($CandidateName)
    }
    else {
        $null
    }

    [PSCustomObject]@{
        CandidateName = $CandidateName
        CatalogKey = $catalogKey
        CatalogExists = ($null -ne $record)
        NexusModId = if ($identity) { $NexusModId } else { 0 }
        NexusIdentity = $identity
        FileCount = $candidate.FileCount
        Files = @($candidate.Files)
        StagingRoot = (Get-PwPaths).Staging
        CanAdopt = (
            $candidate.FileCount -gt 0 -and
            (
                -not $identity -or
                $identity.NameMatch -in @('Exact', 'Strong')
            )
        )
    }
}

function Import-PwCurrentGameMod {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [string]$CandidateName,

        [ValidateRange(1, [int]::MaxValue)]
        [int]$NexusModId,

        [switch]$ApproveIdentity,

        [switch]$Apply
    )

    $parameters = @{
        CandidateName = $CandidateName
    }
    if ($PSBoundParameters.ContainsKey('NexusModId')) {
        $parameters.NexusModId = $NexusModId
    }
    $plan = Get-PwCurrentGameModAdoptionPlan @parameters

    if (-not $Apply) {
        return $plan
    }
    if (-not $plan.CanAdopt -and -not $ApproveIdentity) {
        throw (
            'Nexus identity is not an Exact or Strong name match. Review it ' +
            'and use -ApproveIdentity only when the entered mod ID is correct.'
        )
    }
    if (-not $PSCmdlet.ShouldProcess(
        $plan.StagingRoot,
        "Adopt current game mod '$CandidateName' into staging and catalog"
    )) {
        return $plan
    }

    foreach ($file in $plan.Files) {
        $destinationPath = Join-Path $plan.StagingRoot (
            "Pal\$($file.RelativePath)"
        )
        $destinationDirectory = Split-Path -Parent $destinationPath
        New-Item `
            -ItemType Directory `
            -Path $destinationDirectory `
            -Force |
            Out-Null
        Copy-Item `
            -LiteralPath $file.GamePath `
            -Destination $destinationPath `
            -Force `
            -ErrorAction Stop
        $actualHash = (
            Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256
        ).Hash
        if ($actualHash -ne $file.Hash) {
            throw "Adopted file hash mismatch: $($file.RelativePath)"
        }
    }

    if (-not $plan.CatalogExists) {
        New-PwModCatalogRecord `
            -DisplayName $CandidateName `
            -ComponentName $CandidateName `
            -Source (
                if ($plan.NexusModId -gt 0) { 'NexusMods' } else { 'Manual' }
            ) `
            -Confirm:$false |
            Out-Null
    }

    $metadataParameters = @{
        CatalogKey = $plan.CatalogKey
        ComponentName = $CandidateName
        InstallName = $CandidateName
        Confirm = $false
    }
    if ($plan.NexusModId -gt 0) {
        $metadataParameters.NexusModId = $plan.NexusModId
        $metadataParameters.ReplaceNexusModIds = $true
        $metadataParameters.DisplayName = $plan.NexusIdentity.Name
        $metadataParameters.InstalledVersion = $plan.NexusIdentity.Version
    }
    Set-PwModCatalogMetadata @metadataParameters | Out-Null

    [PSCustomObject]@{
        CandidateName = $CandidateName
        CatalogKey = $plan.CatalogKey
        NexusModId = $plan.NexusModId
        Adopted = $true
        FileCount = $plan.FileCount
        StagingRoot = $plan.StagingRoot
        ArchiveStatus = if ($plan.NexusModId -gt 0) {
            'Use menu 4 to review/download the selected Nexus file.'
        }
        else {
            'No Nexus identity was assigned.'
        }
    }
}

function Get-PwNexusModFiles {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ModId,

        [string]$ApiKey
    )

    $response = Invoke-PwNexusApi `
        -Path "games/palworld/mods/$ModId/files.json" `
        -ApiKey $ApiKey

    @(
        @($response.files) |
            Where-Object {
                [string]$_.category_name -notin @('ARCHIVED', 'OLD_VERSION')
            } |
            Sort-Object uploaded_timestamp -Descending |
            ForEach-Object {
                [PSCustomObject]@{
                    FileId = [int]$_.file_id
                    Name = [string]$_.name
                    Version = [string]$_.version
                    Category = [string]$_.category_name
                    FileName = [string]$_.file_name
                    SizeKb = [long]$_.size_kb
                    UploadedAt = if ($_.uploaded_timestamp) {
                        [datetimeoffset]::FromUnixTimeSeconds(
                            [long]$_.uploaded_timestamp
                        ).UtcDateTime
                    }
                    else {
                        $null
                    }
                }
            }
    )
}
