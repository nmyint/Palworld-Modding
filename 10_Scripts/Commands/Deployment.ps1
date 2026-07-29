<#
.SYNOPSIS
    Provides resolved deployment configuration.
.DESCRIPTION
    Defines commands that combine workshop, game, and deployment settings into
    deployment-ready paths and values.
#>

Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Gets the resolved deployment configuration for the workshop.
.OUTPUTS
    PSCustomObject containing deployment, game, executable, and save paths.
#>
function Get-PwDeployment {

    [CmdletBinding()]
    param()

    $cfg = Get-PwWorkshopConfig

    [PSCustomObject]@{

        TargetRoot                   = $cfg.Deployment.TargetRoot

        ActiveProfile                = $cfg.Deployment.ActiveProfile

        MirrorGameStructure          = $cfg.Deployment.MirrorGameStructure

        CleanDeploymentBeforeBuild   = $cfg.Deployment.CleanDeploymentBeforeBuild

        GameInstallRoot              = $cfg.Game.InstallRoot

        GameExecutable               = Join-Path `
                                        $cfg.Game.InstallRoot `
                                        "Pal\Binaries\Win64\$($cfg.Game.Executable)"

        SavePath                     = $cfg.Game.SavePath

    }

}
