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
    PSCustomObject containing deployment, game, executable, and Saved-root paths.
#>
function Get-PwDeployment {

    [CmdletBinding()]
    param()

    $configuration = Get-PwWorkshopConfig
    $profileName = $configuration.Deployment.ActiveProfile
    $profile = Get-PwProfile -Name $profileName
    $validation = Test-PwProfile -Name $profileName

    if (-not $validation.IsValid) {
        throw "Active profile '$profileName' is not valid: $($validation.Errors -join ' ')"
    }

    $gameInstallRoot = Resolve-PwProfilePath -Path $profile.Game.InstallRoot
    $savedRoot = Resolve-PwProfilePath -Path $profile.Game.SavedRoot
    $targetRoot = Resolve-PwProfilePath -Path $profile.Deployment.TargetRoot
    $gameExecutable = ''

    if (-not [string]::IsNullOrWhiteSpace($gameInstallRoot)) {
        $gameExecutable = Join-Path `
            $gameInstallRoot `
            "Pal\Binaries\Win64\$($profile.Game.Executable)"
    }

    $canDeploy = (
        (Test-Path -LiteralPath $gameInstallRoot -PathType Container) -and
        (Test-Path -LiteralPath $gameExecutable -PathType Leaf)
    )

    [PSCustomObject]@{

        TargetRoot                   = $targetRoot

        ActiveProfile                = $profileName

        MirrorGameStructure          = $profile.Deployment.MirrorGameStructure

        CleanDeploymentBeforeBuild   = $profile.Deployment.CleanDeploymentBeforeBuild

        GameInstallRoot              = $gameInstallRoot

        GameExecutable               = $gameExecutable

        SavedRoot                    = $savedRoot

        IsReady                      = $validation.IsReady

        CanDeploy                    = $canDeploy

        Warnings                     = $validation.Warnings

    }

}
