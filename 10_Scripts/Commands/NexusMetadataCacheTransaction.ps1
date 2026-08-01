<#
.SYNOPSIS
    Finalizes atomic Nexus metadata cache writes and preview safety.
.DESCRIPTION
    Replaces the cache writer with one ShouldProcess transaction so -WhatIf
    returns before directory creation, temporary serialization, or replacement.
#>

Set-StrictMode -Version Latest

function Write-PwNexusMetadataCache {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Cache,

        [string]$Path = (Get-PwNexusMetadataCachePath)
    )

    $resolvedPath = [System.IO.Path]::GetFullPath($Path)

    if (-not $PSCmdlet.ShouldProcess(
        $resolvedPath,
        'Write Nexus metadata cache atomically'
    )) {
        return
    }

    $parent = Split-Path -Parent $resolvedPath
    New-Item `
        -ItemType Directory `
        -Path $parent `
        -Force `
        -ErrorAction Stop |
        Out-Null
    $temporaryPath = Join-Path `
        $parent `
        ('.NexusMetadata-{0}.tmp' -f [guid]::NewGuid().ToString('N'))

    try {
        Write-PwJson `
            -InputObject $Cache `
            -Path $temporaryPath `
            -Depth 100 `
            -Confirm:$false

        if (-not (Test-Path -LiteralPath $temporaryPath -PathType Leaf)) {
            throw "Temporary Nexus metadata cache was not written: $temporaryPath"
        }

        Move-Item `
            -LiteralPath $temporaryPath `
            -Destination $resolvedPath `
            -Force `
            -ErrorAction Stop
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item `
                -LiteralPath $temporaryPath `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}
