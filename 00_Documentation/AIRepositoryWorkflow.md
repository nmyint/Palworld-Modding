# AI Repository Workflow

## Purpose

Defines how AI assistants and automated tools should interact with this repository.

## Initial Repository Scan

Always begin with:

1. `README.md`
2. `00_Documentation/RepositoryStructure.txt`
3. `00_Documentation/RepositoryInventory.json`
4. Relevant documentation in `00_Documentation`

These files define the repository map before deeper inspection.

## File Reading Strategy

Large files must be processed incrementally.

Recommended approach:

1. Inspect file metadata.
2. Identify relevant sections.
3. Read in logical chunks.
4. Expand only when required.

Avoid loading:

- large logs
- archives
- generated files
- deployment payloads
- binary content

unless specifically required.

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
