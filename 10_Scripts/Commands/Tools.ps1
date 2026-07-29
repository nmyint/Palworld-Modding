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

function Get-PwTools {

    [CmdletBinding()]
    param()

    (Get-PwWorkshopConfig).Tools
}
