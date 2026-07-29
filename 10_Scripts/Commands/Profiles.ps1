<#
.SYNOPSIS
    Provides workshop profile management.
.DESCRIPTION
    Defines commands for discovering, creating, validating, and activating
    Palworld installation and deployment profiles.
#>

Set-StrictMode -Version Latest

function Test-PwProfileName {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $Name -match '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$'
}

function Get-PwProfilePath {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if (-not (Test-PwProfileName -Name $Name)) {
        throw "Invalid profile name '$Name'. Use letters, numbers, hyphens, or underscores."
    }

    Join-Path (Get-PwPaths).Profiles "$Name.json"
}

function Resolve-PwProfilePath {

    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    $expandedPath = [System.Environment]::ExpandEnvironmentVariables($Path)

    if ([System.IO.Path]::IsPathFullyQualified($expandedPath)) {
        return [System.IO.Path]::GetFullPath($expandedPath)
    }

    [System.IO.Path]::GetFullPath(
        (Join-Path (Get-PwWorkshopRoot) $expandedPath)
    )
}

function Test-PwRelativePathWithinWorkshop {

    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $true
    }

    $expandedPath = [System.Environment]::ExpandEnvironmentVariables($Path)

    if ([System.IO.Path]::IsPathFullyQualified($expandedPath)) {
        return $true
    }

    $workshopRoot = [System.IO.Path]::GetFullPath((Get-PwWorkshopRoot))
    $resolvedPath = Resolve-PwProfilePath -Path $Path

    $resolvedPath.StartsWith(
        "$workshopRoot\",
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

<#
.SYNOPSIS
    Gets a named workshop profile.
.PARAMETER Name
    Name of the profile, without the `.json` extension.
.OUTPUTS
    PSCustomObject containing the deserialized profile.
#>
function Get-PwProfile {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    Read-PwJson -Path (Get-PwProfilePath -Name $Name)
}

<#
.SYNOPSIS
    Gets all workshop profiles.
.OUTPUTS
    PSCustomObject instances for each profile in `16_Profiles`.
#>
function Get-PwProfiles {

    [CmdletBinding()]
    param()

    $profileRoot = (Get-PwPaths).Profiles

    if (-not (Test-Path -LiteralPath $profileRoot -PathType Container)) {
        return
    }

    Get-ChildItem -LiteralPath $profileRoot -Filter '*.json' -File |
        Sort-Object BaseName |
        ForEach-Object {
            Read-PwJson -Path $_.FullName
        }
}

function Get-PwProfileModSets {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $profile = Get-PwProfile -Name $Name

    @(
        if ($profile.PSObject.Properties.Name -contains 'ModSets') {
            @($profile.ModSets)
        }
    ) |
        Where-Object { $null -ne $_ } |
        ForEach-Object {
            [PSCustomObject]@{
                Name = [string]$_.Name
                Description = [string]$_.Description
                IsActive = [bool]$_.IsActive
                CatalogKeys = @($_.CatalogKeys)
            }
        } |
        Sort-Object Name
}

function Set-PwProfileModSet {

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SetName,

        [string]$Description = '',

        [string[]]$CatalogKeys = @(),

        [switch]$Activate
    )

    $profilePath = Get-PwProfilePath -Name $Name
    $profile = Get-PwProfile -Name $Name

    if ($profile.PSObject.Properties.Name -notcontains 'ModSets') {
        $profile | Add-Member -NotePropertyName ModSets -NotePropertyValue @()
    }

    $modSets = [System.Collections.Generic.List[object]]::new()
    foreach ($modSet in @($profile.ModSets)) {
        if ([string]$modSet.Name -ieq $SetName) {
            continue
        }

        $copy = [ordered]@{}
        foreach ($property in $modSet.PSObject.Properties) {
            $copy[$property.Name] = $property.Value
        }
        $copy.IsActive = [bool]$modSet.IsActive
        $modSets.Add([PSCustomObject]$copy)
    }

    $modSets.Add([PSCustomObject]@{
        Name = $SetName
        Description = $Description
        IsActive = [bool]$Activate
        CatalogKeys = @($CatalogKeys | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    })

    if ($Activate) {
        foreach ($modSet in $modSets) {
            if ([string]$modSet.Name -ne $SetName) {
                $modSet.IsActive = $false
            }
        }
    }

    $profile.ModSets = @($modSets | Sort-Object Name)

    if ($PSCmdlet.ShouldProcess($profilePath, "Write mod set '$SetName'")) {
        Write-PwJson -InputObject $profile -Path $profilePath
    }

    Get-PwProfileModSets -Name $Name |
        Where-Object Name -eq $SetName |
        Select-Object -First 1
}

function Get-PwProfileModSetPreview {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [string]$SetName = ''
    )

    $profile = Get-PwProfile -Name $Name
    $catalog = Get-PwPersistentModCatalog
    $modSets = @(
        Get-PwProfileModSets -Name $Name
    )

    if ($modSets.Count -eq 0) {
        return [PSCustomObject]@{
            Profile = $Name
            ModSet = ''
            ModCount = 0
            Mods = @()
        }
    }

    $selectedSet = if ([string]::IsNullOrWhiteSpace($SetName)) {
        $modSets | Where-Object IsActive | Select-Object -First 1
    }
    else {
        $modSets | Where-Object Name -eq $SetName | Select-Object -First 1
    }

    if (-not $selectedSet) {
        $selectedSet = $modSets | Select-Object -First 1
    }

    $modsByKey = @{}
    foreach ($mod in @($catalog.Mods)) {
        $modsByKey[[string]$mod.CatalogKey] = $mod
    }

    $mods = foreach ($catalogKey in @($selectedSet.CatalogKeys)) {
        $mod = $modsByKey[[string]$catalogKey]
        if ($null -ne $mod) {
            [PSCustomObject]@{
                CatalogKey = [string]$mod.CatalogKey
                DisplayName = [string]$mod.DisplayName
                InstalledVersion = [string]$mod.InstalledVersion
                ReconciliationStatus = [string]$mod.ReconciliationStatus
                Types = @($mod.Types)
            }
        }
    }
    $mods = @($mods | Sort-Object DisplayName)

    [PSCustomObject]@{
        Profile = $Name
        ModSet = [string]$selectedSet.Name
        Description = [string]$selectedSet.Description
        ModCount = $mods.Count
        Mods = $mods
    }
}

<#
.SYNOPSIS
    Creates a workshop profile.
.PARAMETER Name
    Unique profile name containing letters, numbers, hyphens, or underscores.
.PARAMETER Description
    Human-readable purpose of the profile.
.PARAMETER Platform
    Palworld distribution platform.
.PARAMETER InstallRoot
    Palworld installation root. May be empty until configured.
.PARAMETER SavedRoot
    Palworld Saved directory containing configuration, logs, and saved games.
.PARAMETER Executable
    Palworld executable file name.
.PARAMETER DeploymentTargetRoot
    Absolute path or workshop-relative path for deployment output.
.PARAMETER Force
    Replaces an existing profile with the same name.
.OUTPUTS
    PSCustomObject containing the created profile.
#>
function New-PwProfile {

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [string]$Description = '',

        [ValidateSet('Steam', 'Xbox', 'Other')]
        [string]$Platform = 'Steam',

        [AllowEmptyString()]
        [string]$InstallRoot = '',

        [AllowEmptyString()]
        [string]$SavedRoot = '',

        [ValidateNotNullOrEmpty()]
        [string]$Executable = 'Palworld-Win64-Shipping.exe',

        [ValidateNotNullOrEmpty()]
        [string]$DeploymentTargetRoot = '05_Deployment\Pal',

        [switch]$Force
    )

    if (-not (Test-PwProfileName -Name $Name)) {
        throw "Invalid profile name '$Name'. Use letters, numbers, hyphens, or underscores."
    }

    $profilePath = Get-PwProfilePath -Name $Name

    if ((Test-Path -LiteralPath $profilePath) -and -not $Force) {
        throw "Profile '$Name' already exists. Use -Force to replace it."
    }

    $profile = [PSCustomObject]@{
        SchemaVersion = '1.0'
        Name = $Name
        Description = $Description
        Game = [PSCustomObject]@{
            Platform = $Platform
            InstallRoot = $InstallRoot
            SavedRoot = $SavedRoot
            Executable = $Executable
        }
        Deployment = [PSCustomObject]@{
            TargetRoot = $DeploymentTargetRoot
            MirrorGameStructure = $true
            CleanDeploymentBeforeBuild = $false
        }
    }

    if ($PSCmdlet.ShouldProcess($profilePath, "Write profile '$Name'")) {
        Write-PwJson -InputObject $profile -Path $profilePath
    }

    $profile
}

<#
.SYNOPSIS
    Validates a workshop profile.
.PARAMETER Name
    Name of the profile to validate.
.OUTPUTS
    PSCustomObject containing validity, readiness, errors, and warnings.
#>
function Test-PwProfile {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $profilePath = Get-PwProfilePath -Name $Name
    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    if (-not (Test-Path -LiteralPath $profilePath -PathType Leaf)) {
        $errors.Add("Profile file not found: $profilePath")

        return [PSCustomObject]@{
            Name = $Name
            Path = $profilePath
            IsValid = $false
            IsReady = $false
            Errors = @($errors)
            Warnings = @($warnings)
        }
    }

    try {
        $profile = Read-PwJson -Path $profilePath
    }
    catch {
        $errors.Add($_.Exception.Message)
    }

    if ($errors.Count -eq 0) {
        foreach ($property in @('SchemaVersion', 'Name', 'Game', 'Deployment')) {
            if ($profile.PSObject.Properties.Name -notcontains $property) {
                $errors.Add("Missing required property '$property'.")
            }
        }
    }

    if ($errors.Count -eq 0) {
        if ($profile.SchemaVersion -ne '1.0') {
            $errors.Add("Unsupported schema version '$($profile.SchemaVersion)'.")
        }

        if ($profile.Name -ne $Name) {
            $errors.Add("Profile name '$($profile.Name)' does not match file name '$Name'.")
        }

        if ($null -eq $profile.Game) {
            $errors.Add("Property 'Game' cannot be null.")
        }
        else {
            foreach ($property in @(
                'Platform',
                'InstallRoot',
                'SavedRoot',
                'Executable'
            )) {
                if ($profile.Game.PSObject.Properties.Name -notcontains $property) {
                    $errors.Add("Missing required Game property '$property'.")
                }
            }
        }

        if ($null -eq $profile.Deployment) {
            $errors.Add("Property 'Deployment' cannot be null.")
        }
        else {
            foreach ($property in @(
                'TargetRoot',
                'MirrorGameStructure',
                'CleanDeploymentBeforeBuild'
            )) {
                if (
                    $profile.Deployment.PSObject.Properties.Name -notcontains
                    $property
                ) {
                    $errors.Add("Missing required Deployment property '$property'.")
                }
            }
        }
    }

    if ($errors.Count -eq 0) {
        if (
            $profile.Game.Platform -notin @('Steam', 'Xbox', 'Other')
        ) {
            $errors.Add("Unsupported game platform '$($profile.Game.Platform)'.")
        }

        if ([string]::IsNullOrWhiteSpace($profile.Game.Executable)) {
            $errors.Add("Game property 'Executable' cannot be empty.")
        }

        if ($profile.Deployment.MirrorGameStructure -isnot [bool]) {
            $errors.Add("Deployment property 'MirrorGameStructure' must be Boolean.")
        }

        if ($profile.Deployment.CleanDeploymentBeforeBuild -isnot [bool]) {
            $errors.Add(
                "Deployment property 'CleanDeploymentBeforeBuild' must be Boolean."
            )
        }

        if ([string]::IsNullOrWhiteSpace($profile.Deployment.TargetRoot)) {
            $errors.Add("Deployment property 'TargetRoot' cannot be empty.")
        }
        elseif (-not (
            Test-PwRelativePathWithinWorkshop -Path $profile.Deployment.TargetRoot
        )) {
            $errors.Add('A relative deployment target must remain within the workshop.')
        }
    }

    if ($errors.Count -eq 0) {
        $installRoot = Resolve-PwProfilePath -Path $profile.Game.InstallRoot
        $savedRoot = Resolve-PwProfilePath -Path $profile.Game.SavedRoot

        if ([string]::IsNullOrWhiteSpace($installRoot)) {
            $warnings.Add('Game installation root is not configured.')
        }
        elseif (-not (Test-Path -LiteralPath $installRoot -PathType Container)) {
            $warnings.Add("Game installation root does not exist: $installRoot")
        }

        if ([string]::IsNullOrWhiteSpace($savedRoot)) {
            $warnings.Add('Game Saved root is not configured.')
        }
        elseif (-not (Test-Path -LiteralPath $savedRoot -PathType Container)) {
            $warnings.Add("Game Saved root does not exist: $savedRoot")
        }
    }

    [PSCustomObject]@{
        Name = $Name
        Path = $profilePath
        IsValid = ($errors.Count -eq 0)
        IsReady = ($errors.Count -eq 0 -and $warnings.Count -eq 0)
        Errors = @($errors)
        Warnings = @($warnings)
    }
}

<#
.SYNOPSIS
    Sets the active workshop profile.
.PARAMETER Name
    Name of an existing, structurally valid profile.
.OUTPUTS
    PSCustomObject containing the activated profile.
#>
function Set-PwActiveProfile {

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $validation = Test-PwProfile -Name $Name

    if (-not $validation.IsValid) {
        throw "Profile '$Name' is not valid: $($validation.Errors -join ' ')"
    }

    $configuration = Get-PwWorkshopConfig

    if ($PSCmdlet.ShouldProcess(
        (Get-PwWorkshopConfigPath),
        "Set active profile to '$Name'"
    )) {
        $configuration.Deployment.ActiveProfile = $Name
        Save-PwWorkshopConfig -Configuration $configuration
        Reset-PwContext
    }

    Get-PwProfile -Name $Name
}
