# AI Repository Workflow

## Purpose

Defines how AI assistants and automated tools should interact with this repository.

## Initial Repository Scan

Always begin with:

1. `README.md`
2. `00_Documentation/RepositoryStructure.txt`
3. `00_Documentation/RepositoryInventory.json`
4. `00_Documentation/AIRepositoryWorkflow.md`
5. Relevant operational documentation in `00_Documentation`
6. `00_Documentation/Scrapbook.md` for historical context

These files define the repository map before deeper inspection.

## Repository Truth and Verification Rules

The repository state is authoritative.

Before answering repository-specific questions, making recommendations, or modifying files:

1. Inspect the current repository state.
2. Verify that files, folders, and implementations actually exist.
3. Read the relevant documentation for the affected area.
4. Use repository contents instead of assumptions or conversation memory.
5. If uncertainty exists, inspect first, confirm second, answer third.
6. Read applicable standards and environment documentation before creating or modifying code.

AI assistants must not:

- claim files are missing without verification.
- claim features are absent without checking the implementation.
- propose replacements for systems that already exist.
- rely solely on previous conversation history when repository state can be inspected.

If documentation and assumptions conflict, repository documentation and current repository contents take priority.

## Authoritative Repository Sources

Primary source for repository orientation:

`README.md`

URL:

https://github.com/nmyint/Palworld-Modding/blob/main/README.md

The README provides the initial navigation point for AI assistants and developers.

Supporting authoritative sources:

1. `00_Documentation/RepositoryStructure.txt`
2. `00_Documentation/RepositoryInventory.json`
3. `00_Documentation/AIRepositoryWorkflow.md`
4. Relevant operational documentation
5. `00_Documentation/Scrapbook.md` for historical context

## File Reading Strategy

Large files must be processed incrementally.

Recommended approach:

1. Inspect file metadata.
2. Identify relevant sections.
3. Read in logical chunks.
4. Reassemble the required context.
5. Modify only the required content.
6. Update the file using the complete validated content.
7. Commit the change with a descriptive message.

## Large File Modification Workflow

When modifying large repository files:

1. Fetch large files in chunks.
2. Reassemble the file contents before editing.
3. Apply the requested change while preserving unrelated content.
4. Validate that no sections were removed accidentally.
5. Update the file.
6. Commit the change.

Do not repeatedly explain tooling limitations when the workflow can proceed. Continue with the established chunked fetch -> edit -> update -> commit process.

## AI Change Scope Rules

Before modifying files:

1. Identify the smallest required file set.
2. Avoid unrelated cleanup.
3. Do not restructure folders without documentation updates.
4. Update documentation when changing workflows.
5. Prefer additive changes over destructive changes.

## Code Creation Requirements

Before creating or modifying code:

1. Identify the language, runtime, and tooling requirements.
2. Read the applicable standards documentation.
3. Read the environment requirements for the affected toolchain.
4. Inspect existing implementations before creating new ones.
5. Follow repository-specific versions and conventions instead of general best practices.

Examples:

### PowerShell

Before creating or modifying PowerShell scripts, read:

- `00_Documentation/PowerShellStandards.md`
- `00_Documentation/Environment.md`

Verify:

- supported PowerShell version
- module/script organization
- testing framework version
- syntax compatibility requirements

Do not assume the latest language or framework conventions are compatible with this repository.

## Documentation Authority

Priority order:

1. README.md
2. AIRepositoryWorkflow.md
3. RepositoryStructure.txt
4. Individual documentation files
5. Scrapbook.md

Generated files describe the current repository state. They should not be manually edited unless specifically required.

## Priority Order

Preferred reading order:

1. Documentation
2. Configuration
3. PowerShell scripts
4. Tests
5. Project files
6. Generated data

## Repository Boundaries

| Area | Purpose |
|---|---|
| 00_Documentation | Human and AI knowledge base |
| 01-09 | Data containers and operational areas |
| 10_Scripts | Automation source |
| 11_Utilities | Supporting tools |
| 16_Profiles | Environment configuration |

## Change Discipline

Before modifying files:

- understand existing structure
- inspect related documentation
- preserve existing conventions
- avoid unrelated changes
