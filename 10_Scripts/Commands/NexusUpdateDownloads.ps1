<#
.SYNOPSIS
    Connects actionable Nexus update-report rows to the safe archive downloader.
#>

Set-StrictMode -Version Latest

function Get-PwNexusUpdateDownloadDecision {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Update
    )

    $getValue = {
        param(
            [Parameter(Mandatory)]
            [string]$Name,

            [object]$DefaultValue = $null
        )

        $property = $Update.PSObject.Properties[$Name]
        if ($property) {
            return $property.Value
        }

        $DefaultValue
    }

    $name = [string](& $getValue 'Name' '')
    $status = [string](& $getValue 'Status' '')
    $modIdValue = & $getValue 'NexusModId' 0
    $fileIdValue = & $getValue 'RemoteFileId' 0
    $modId = if ($null -eq $modIdValue) { 0 } else { [int]$modIdValue }
    $fileId = if ($null -eq $fileIdValue) { 0 } else { [int]$fileIdValue }
    $canDownload = $true
    $reason = ''

    if ($status -ne 'UpdateAvailable') {
        $canDownload = $false
        $reason = switch ($status) {
            'Current' {
                'The recorded local version already matches the compatible remote file.'
            }
            'VariantNotFound' {
                'Nexus has no compatible remote file for the recorded SP, DS, or MP variant.'
            }
            'NoRemoteFiles' {
                'Nexus returned no compatible downloadable files for this mod.'
            }
            'CheckFailed' {
                $errorMessage = [string](& $getValue 'Error' '')
                if ([string]::IsNullOrWhiteSpace($errorMessage)) {
                    'The Nexus update check failed.'
                }
                else {
                    "The Nexus update check failed: $errorMessage"
                }
            }
            default {
                "The update row is not actionable because its status is '$status'."
            }
        }
    }
    elseif ($modId -lt 1) {
        $canDownload = $false
        $reason = 'The update row does not contain a valid Nexus mod ID.'
    }
    elseif ($fileId -lt 1) {
        $canDownload = $false
        $reason = 'The update row does not contain a valid remote Nexus file ID.'
    }

    [PSCustomObject]@{
        Name = $name
        NexusModId = $modId
        RemoteFileId = $fileId
        LocalVersion = [string](& $getValue 'LocalVersion' '')
        RemoteVersion = [string](& $getValue 'RemoteVersion' '')
        RemoteFileName = [string](& $getValue 'RemoteFileName' '')
        LocalVariant = [string](& $getValue 'LocalVariant' '')
        RemoteVariant = [string](& $getValue 'RemoteVariant' '')
        Status = $status
        ManualUrl = [string](& $getValue 'ManualUrl' '')
        CanDownload = $canDownload
        Reason = $reason
    }
}

<#
.SYNOPSIS
    Downloads the exact actionable file selected from a Nexus update report.
.DESCRIPTION
    Accepts one object returned by Get-PwModUpdateReport. Only an
    UpdateAvailable row with valid Nexus mod and file IDs can proceed. The
    underlying downloader still performs Premium-account validation, downloads
    to a temporary path, inspects the archive, and moves it into 01_Archives
    only after the existing safety checks succeed.
.PARAMETER Update
    One update-report row returned by Get-PwModUpdateReport.
.PARAMETER ApiKey
    Optional Nexus API key. When omitted, NEXUSMODS_API_KEY is used.
.PARAMETER Destination
    Archive destination. Defaults to the configured 01_Archives directory.
.OUTPUTS
    A PSCustomObject containing the selected Nexus identity, download result,
    archive path, SHA-256 hash, and the recommended next workflow step.
#>
function Save-PwModUpdateFromReport {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [object]$Update,

        [string]$ApiKey,

        [string]$Destination = (Get-PwPaths).Archives
    )

    process {
        $decision = Get-PwNexusUpdateDownloadDecision -Update $Update

        if (-not $decision.CanDownload) {
            throw $decision.Reason
        }

        $target = if (
            [string]::IsNullOrWhiteSpace($decision.RemoteFileName)
        ) {
            "Nexus mod $($decision.NexusModId) file $($decision.RemoteFileId)"
        }
        else {
            $decision.RemoteFileName
        }
        $action = (
            "Download $($decision.Name) $($decision.RemoteVersion) " +
                "from Nexus file $($decision.RemoteFileId), validate it, " +
                'and add it to 01_Archives'
        )

        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            [PSCustomObject]@{
                Name = $decision.Name
                NexusModId = $decision.NexusModId
                FileId = $decision.RemoteFileId
                LocalVersion = $decision.LocalVersion
                RemoteVersion = $decision.RemoteVersion
                RemoteFileName = $decision.RemoteFileName
                Downloaded = $false
                Path = ''
                Hash = ''
                NextStep = 'Inspect and import the archive through menu option 2.'
            }
        }
        else {
            $result = Save-PwNexusModUpdate `
                -ModId $decision.NexusModId `
                -FileId $decision.RemoteFileId `
                -ApiKey $ApiKey `
                -Destination $Destination `
                -Confirm:$false

            [PSCustomObject]@{
                Name = $decision.Name
                NexusModId = $decision.NexusModId
                FileId = $decision.RemoteFileId
                LocalVersion = $decision.LocalVersion
                RemoteVersion = $decision.RemoteVersion
                RemoteFileName = $decision.RemoteFileName
                Downloaded = [bool]$result.Downloaded
                Path = [string]$result.Path
                Hash = [string]$result.Hash
                NextStep = 'Inspect and import the archive through menu option 2.'
            }
        }
    }
}
