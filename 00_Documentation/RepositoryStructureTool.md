# Repository Structure Tool

## Purpose

`Export-PwRepositoryStructure.ps1` generates the authoritative repository map used by developers and AI assistants.

The tool creates:

- `00_Documentation/RepositoryStructure.txt`
- `00_Documentation/RepositoryInventory.json`

These generated files describe the current repository layout, documentation locations, script organization, project boundaries, and operational areas.

The exporter remains a standalone V1 utility. Pw-Git v1.2 adds a manual integration path without changing the exporter into a Git operation or loading the PwWorkshop module.

## Tool Location

The exporter is located at:

```text
10_Scripts/Utilities/Export-PwRepositoryStructure.ps1
```

## Direct Usage

Run the standalone exporter from the repository root:

```powershell
.\10_Scripts\Utilities\Export-PwRepositoryStructure.ps1
```

The exporter should be run after major structural changes, documentation additions, or folder reorganizations.

## Pw-Git Usage

Pw-Git v1.2 can invoke the standalone exporter manually through Advanced option 7:

```text
7. Refresh repository structure
```

The equivalent direct command is:

```powershell
pwsh -NoProfile -File .\pw-git.ps1 refresh-structure
```

The Pw-Git integration:

- invokes the standalone exporter directly
- reports which generated files changed
- shows Git status for the generated files
- verifies that the Git staging set was not changed
- does not stage, commit, or push generated files

Repository-map generation is not run automatically during fetch, pull, commit, or push because the exporter writes tracked files and would otherwise change the working tree implicitly.

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

Pw-Git command registration and structure-refresh integration are validated by:

```text
10_Scripts/Tests/PwGit.Tests.ps1
```

The validation ensures generated documentation remains current, contains required repository information, and remains under explicit user staging control when refreshed through Pw-Git.

## AI Workflow Usage

AI assistants should use the generated structure files during repository orientation:

1. Read `README.md`.
2. Read `RepositoryStructure.txt`.
3. Read `RepositoryInventory.json`.
4. Use the generated map before scanning deeper areas.

Generated files should be regenerated through the standalone exporter or the Pw-Git v1.2 manual refresh command rather than manually edited.
