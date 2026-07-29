<#
.SYNOPSIS
    Returns the deployment configuration for the workshop.
#>

Set-StrictMode -Version Latest

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
