<#
.SYNOPSIS
    Workshop configuration management.
#>

Set-StrictMode -Version Latest

# Load the JSON helper when this file is dot-sourced independently.
if (-not (Get-Command Read-PwJson -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\Json.ps1"
}

<#
.SYNOPSIS
    Gets the absolute workshop root.
.OUTPUTS
    System.String containing the repository root path.
#>
function Get-PwWorkshopRoot {

    [CmdletBinding()]
    param()

    (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

}

<#
.SYNOPSIS
    Gets the workshop configuration file path.
.OUTPUTS
    System.String containing the path to Workshop.json.
#>
function Get-PwWorkshopConfigPath {

    [CmdletBinding()]
    param()

    Join-Path `
        (Get-PwWorkshopRoot) `
        ".config\Workshop.json"

}

<#
.SYNOPSIS
    Gets the deserialized workshop configuration.
.OUTPUTS
    PSCustomObject containing the Workshop.json configuration.
#>
function Get-PwWorkshopConfig {

    [CmdletBinding()]
    param()

    Read-PwJson -Path (Get-PwWorkshopConfigPath)

}

<#
.SYNOPSIS
    Saves the workshop configuration.
.PARAMETER Configuration
    Configuration object to serialize to Workshop.json.
#>
function Save-PwWorkshopConfig {

    [CmdletBinding(SupportsShouldProcess)]
    param(

        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [object]$Configuration

    )

    process {
        $validation = Test-PwWorkshopConfig `
            -Configuration $Configuration `
            -Detailed

        if (-not $validation.IsValid) {
            throw "Refusing to save invalid workshop configuration: " +
                ($validation.Errors -join ' ')
        }

        Write-PwJson `
            -InputObject $Configuration `
            -Path (Get-PwWorkshopConfigPath)

    }

}

<#
.SYNOPSIS
    Validates the workshop configuration.
.DESCRIPTION
    Verifies JSON syntax, required sections and properties, supported schema
    version, configured path values, preference types, and the PowerShell version.
.PARAMETER Detailed
    Returns the complete validation result instead of only a Boolean value.
.PARAMETER Configuration
    Optional in-memory configuration to validate instead of reading Workshop.json.
.OUTPUTS
    System.Boolean by default, or a PSCustomObject when `-Detailed` is specified.
#>
function Test-PwWorkshopConfig {

    [CmdletBinding()]
    param(
        [switch]$Detailed,

        [object]$Configuration
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $configPath = Get-PwWorkshopConfigPath
    $configurationValue = $Configuration

    if (-not $PSBoundParameters.ContainsKey('Configuration')) {
        try {
            $configurationValue = Read-PwJson -Path $configPath
        }
        catch {
            $errors.Add($_.Exception.Message)
        }
    }

    $requiredSections = @(
        'SchemaVersion',
        'Workshop',
        'Paths',
        'Deployment',
        'Tools',
        'Git',
        'Preferences'
    )

    if ($null -ne $configurationValue) {
        foreach ($section in $requiredSections) {
            if (-not $configurationValue.PSObject.Properties[$section]) {
                $errors.Add("Missing required configuration section '$section'.")
            }
            elseif ($null -eq $configurationValue.$section) {
                $errors.Add("Configuration section '$section' cannot be null.")
            }
        }
    }
    else {
        $errors.Add('Workshop configuration cannot be null.')
    }

    if ($errors.Count -eq 0) {
        if ($configurationValue.SchemaVersion -ne '1.0') {
            $errors.Add(
                "Unsupported configuration schema version " +
                    "'$($configurationValue.SchemaVersion)'."
            )
        }

        foreach ($property in @('Name', 'Version', 'Owner', 'Created', 'Description')) {
            if (-not $configurationValue.Workshop.PSObject.Properties[$property]) {
                $errors.Add("Missing required Workshop property '$property'.")
            }
            elseif (
                [string]::IsNullOrWhiteSpace(
                    $configurationValue.Workshop.$property
                )
            ) {
                $errors.Add("Workshop property '$property' cannot be empty.")
            }
        }

        foreach ($property in @(
            'Root',
            'Archives',
            'Staging',
            'ModLibrary',
            'Projects',
            'Deployment',
            'CurrentInstallation',
            'Testing',
            'Tools',
            'Utilities',
            'Research',
            'Backups',
            'Templates',
            'Sandbox',
            'Profiles'
        )) {
            if (-not $configurationValue.Paths.PSObject.Properties[$property]) {
                $errors.Add("Missing required Paths property '$property'.")
            }
            elseif (
                [string]::IsNullOrWhiteSpace($configurationValue.Paths.$property)
            ) {
                $errors.Add("Paths property '$property' cannot be empty.")
            }
        }

        if (
            -not $configurationValue.Deployment.PSObject.Properties['ActiveProfile']
        ) {
            $errors.Add("Missing required Deployment property 'ActiveProfile'.")
        }
        elseif (
            [string]::IsNullOrWhiteSpace(
                $configurationValue.Deployment.ActiveProfile
            )
        ) {
            $errors.Add("Deployment property 'ActiveProfile' cannot be empty.")
        }

        if (
            -not $configurationValue.Tools.PSObject.Properties['PowerShell']
        ) {
            $errors.Add("Missing required Tools property 'PowerShell'.")
        }
        elseif (
            -not $configurationValue.Tools.PowerShell.PSObject.Properties[
                'RequiredVersion'
            ]
        ) {
            $errors.Add("Missing required PowerShell property 'RequiredVersion'.")
        }
        else {
            try {
                [version]$configurationValue.Tools.PowerShell.RequiredVersion |
                    Out-Null
            }
            catch {
                $errors.Add("PowerShell property 'RequiredVersion' must be a version.")
            }
        }

        if (-not $configurationValue.Tools.PSObject.Properties['Git']) {
            $errors.Add("Missing required Tools property 'Git'.")
        }
        elseif (
            -not $configurationValue.Tools.Git.PSObject.Properties['Required']
        ) {
            $errors.Add("Missing required configured Git property 'Required'.")
        }
        elseif ($configurationValue.Tools.Git.Required -isnot [bool]) {
            $errors.Add("Configured Git property 'Required' must be Boolean.")
        }

        if (-not $configurationValue.Tools.PSObject.Properties['SevenZip']) {
            $errors.Add("Missing required Tools property 'SevenZip'.")
        }
        else {
            foreach ($property in @('Enabled', 'Path')) {
                if (
                    -not $configurationValue.Tools.SevenZip.PSObject.Properties[
                        $property
                    ]
                ) {
                    $errors.Add(
                        "Missing required SevenZip property '$property'."
                    )
                }
            }

            if (
                $configurationValue.Tools.SevenZip.PSObject.Properties['Enabled'] -and
                $configurationValue.Tools.SevenZip.Enabled -isnot [bool]
            ) {
                $errors.Add("SevenZip property 'Enabled' must be Boolean.")
            }

            if (
                $configurationValue.Tools.SevenZip.PSObject.Properties['Path'] -and
                [string]::IsNullOrWhiteSpace(
                    $configurationValue.Tools.SevenZip.Path
                )
            ) {
                $errors.Add("SevenZip property 'Path' cannot be empty.")
            }
        }

        foreach ($property in @('DefaultBranch', 'CommitConvention')) {
            if (-not $configurationValue.Git.PSObject.Properties[$property]) {
                $errors.Add("Missing required Git property '$property'.")
            }
            elseif (
                [string]::IsNullOrWhiteSpace($configurationValue.Git.$property)
            ) {
                $errors.Add("Git property '$property' cannot be empty.")
            }
        }

        foreach ($property in @(
            'AutoArchiveLogs',
            'CreateBackupsBeforeDeployment',
            'VerboseOutput',
            'ConfirmDestructiveOperations'
        )) {
            if (
                -not $configurationValue.Preferences.PSObject.Properties[$property]
            ) {
                $errors.Add("Missing required Preferences property '$property'.")
            }
            elseif ($configurationValue.Preferences.$property -isnot [bool]) {
                $errors.Add("Preferences property '$property' must be Boolean.")
            }
        }
    }

    $result = [PSCustomObject]@{
        Path = $configPath
        IsValid = ($errors.Count -eq 0)
        Errors = @($errors)
    }

    if ($Detailed) {
        return $result
    }

    $result.IsValid
}
