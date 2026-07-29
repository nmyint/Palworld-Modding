# Workshop Profiles

Profiles separate machine- and installation-specific Palworld settings from the
workshop's global configuration. Profile files live in `16_Profiles` and use JSON.

## Profile structure

```json
{
    "SchemaVersion": "1.0",
    "Name": "Stable",
    "Description": "Primary stable installation.",
    "Game": {
        "Platform": "Steam",
        "InstallRoot": "",
        "SavedRoot": "",
        "Executable": "Palworld-Win64-Shipping.exe"
    },
    "Deployment": {
        "TargetRoot": "05_Deployment\\Pal",
        "MirrorGameStructure": true,
        "CleanDeploymentBeforeBuild": false
    }
}
```

Relative paths are resolved beneath the workshop root. Windows environment
variables such as `%LOCALAPPDATA%` are expanded at runtime. Game paths may remain
empty while a profile is being prepared. Such a profile is structurally valid but
not ready for deployment.

## Mod sets

Profiles can optionally store named mod sets under `ModSets`. A mod set records
which catalog keys should be assembled together for a given profile and whether
that set is currently active.

Example:

```json
{
    "Name": "Core",
    "Description": "Stable gameplay and compatibility mods.",
    "IsActive": true,
    "CatalogKeys": [
        "palworldtuner",
        "palschema",
        "waypointteleport"
    ]
}
```

Mod sets are profile-local. They do not change the global catalog; they only
describe how a profile should assemble the curated library when the workshop
builds or previews a deployment.

## Commands

```powershell
Get-PwProfiles
Get-PwProfile -Name Stable
Test-PwProfile -Name Stable
New-PwProfile -Name Testing -Description 'Experimental mod set'
Get-PwProfileModSets -Name Stable
Get-PwProfileModSetPreview -Name Stable
Set-PwProfileModSet -Name Stable -SetName Core -CatalogKeys palworldtuner,palschema -Activate
Set-PwActiveProfile -Name Testing -WhatIf
Set-PwActiveProfile -Name Testing
Get-PwDeployment
```

Commands that create or activate profiles support `-WhatIf`. Activating a profile
does not copy files or modify the Palworld installation.

## Readiness

`Test-PwProfile` reports two states:

- `IsValid` means the profile has the required schema and properties.
- `IsReady` means it is valid and its configured installation and save directories
  exist locally.

`SavedRoot` refers to Palworld's `Saved` directory, normally
`%LOCALAPPDATA%\Pal\Saved`. It is recorded for future configuration and saved-game
backups; deployment commands do not write to it.
