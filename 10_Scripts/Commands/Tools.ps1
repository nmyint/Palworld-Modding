<#
.SYNOPSIS
    Provides access to configured workshop tools.
.DESCRIPTION
    Defines commands for retrieving individual tool settings or the complete tool
    configuration.
#>

Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Gets the configuration for a named workshop tool.
.PARAMETER Name
    Name of the tool entry in Workshop.json.
.OUTPUTS
    PSCustomObject containing the selected tool configuration.
#>
function Get-PwTool {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $cfg = Get-PwWorkshopConfig

    if ($cfg.Tools.PSObject.Properties.Name -notcontains $Name) {
        throw "Unknown tool '$Name'."
    }

    $cfg.Tools.$Name
}

<#
.SYNOPSIS
    Gets all configured workshop tools.
.OUTPUTS
    PSCustomObject containing every tool configuration.
#>
function Get-PwTools {

    [CmdletBinding()]
    param()

    (Get-PwWorkshopConfig).Tools
}
