# PowerShell Standards

Workshop automation follows these conventions.

## Supported runtime

1. The workshop scripts are developed and tested for **PowerShell 7.6.4** (`pwsh`).
2. Windows PowerShell 5.1 is not a supported runtime.
3. The authoritative configured version is stored in `.config/Workshop.json` at
   `Tools.PowerShell.RequiredVersion`.
4. Scripts may use PowerShell 7 behavior and must not claim Windows PowerShell 5.1
   compatibility unless that compatibility has been explicitly implemented and
   tested.
5. Verify the active runtime with `$PSVersionTable.PSVersion` before diagnosing
   version-sensitive behavior.

## File structure

1. Start each `.ps1` or `.psm1` file with comment-based help containing at least
   `.SYNOPSIS`. Add `.DESCRIPTION` when the file's role is not obvious.
2. Enable `Set-StrictMode -Version Latest` immediately after the file header.
3. Group module imports and exports with descriptive section comments.
4. Keep one blank line between logical blocks and avoid decorative whitespace
   inside simple expressions.

## Script Organization

Scripts should follow the repository structure:

```text
10_Scripts
├── Commands
├── Config
├── Core
├── Modules
├── Tasks
├── Tests
└── Utilities
```

New scripts should be placed according to responsibility. Do not create new
root-level scripts unless they are intentional user entry points.

## Functions

1. Use approved PowerShell verbs and the `Pw` noun prefix.
2. Add comment-based help immediately before every public function.
3. Document every parameter and the function's output.
4. Add `[CmdletBinding()]` to public functions.
5. Use `-LiteralPath` for user- or configuration-supplied paths.
6. Use `SupportsShouldProcess` for commands that write, replace, deploy, or delete.

## Safety and testing

1. Resolve and validate paths before filesystem changes.
2. Keep destructive operations opt-in and compatible with `-WhatIf`.
3. Add or update Pester coverage for every public behavior change.
   The supported Pester version is defined in Environment.md.
4. Run `PwTools: Test` under PowerShell 7.6.4 before committing.
5. Never commit credentials, access tokens, private keys, game saves, or generated
   deployment output.
