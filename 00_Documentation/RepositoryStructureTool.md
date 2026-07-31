# Repository Structure Tool

## Purpose

`Export-PwRepositoryStructure.ps1` generates the authoritative repository map used by developers and AI assistants.

The tool creates:

- `00_Documentation/RepositoryStructure.txt`
- `00_Documentation/RepositoryInventory.json`

These generated files describe the current repository layout, documentation locations, script organization, project boundaries, and operational areas.

## Tool Location

The exporter is located at:

```text
10_Scripts/Utilities/Export-PwRepositoryStructure.ps1
```

## Usage

Run from the repository root:

```powershell
.\10_Scripts\Utilities\Export-PwRepositoryStructure.ps1
```

The exporter should be run after major structural changes, documentation additions, or folder reorganizations.

## Design Rules

The exporter follows these rules:

- Uses one repository traversal model for all generated outputs.
- Excludes `.git` while preserving repository configuration files.
- Includes documentation, scripts, configuration, and supported metadata files.
- Includes PowerShell modules and manifests (`.ps1`, `.psm1`, `.psd1`).
- Generates statistics from the same filtered dataset used for the tree and inventory.

## Generated Metadata

Generated output includes repository provenance information:

- repository name
- relative repository root
- current branch
- commit SHA
- generation timestamp

This allows generated documentation to be tied to an exact repository state.

## Validation

The exporter output is validated by:

```text
10_Scripts/Tests/RepositoryStructure.Tests.ps1
```

The validation ensures generated documentation remains current and contains required repository information.

## AI Workflow Usage

AI assistants should use the generated structure files during repository orientation:

1. Read `README.md`.
2. Read `RepositoryStructure.txt`.
3. Read `RepositoryInventory.json`.
4. Use the generated map before scanning deeper areas.

Generated files should be regenerated through the exporter rather than manually edited.