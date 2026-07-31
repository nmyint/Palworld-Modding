# Change Management

Defines how repository changes should be planned, documented, tested, and committed.

## Change Categories

### Documentation Only

Examples:

- updating instructions
- correcting explanations
- adding workflow notes

Expected changes:

- update documentation
- commit with a descriptive message

### Automation Changes

Examples:

- PowerShell scripts
- workshop commands
- validation logic
- tests

Expected changes:

1. Update scripts.
2. Update tests.
3. Update documentation if behavior changes.
4. Validate before committing.

### Structure Changes

Examples:

- adding folders
- changing repository layout
- moving workflows

Expected changes:

1. Update `FolderStructure.md`.
2. Regenerate repository structure files.
3. Update `README.md` if the entry workflow changes.
4. Document migration impact.

## Commit Guidelines

Commits should:

- describe the actual change
- avoid unrelated modifications
- preserve a clear project history
- separate unrelated work into separate commits

## Documentation Updates

Update documentation when:

- workflows change
- commands change
- folder responsibilities change
- automation behavior changes

## Rollback Expectations

Before major changes:

- verify Git status
- preserve backups when applicable
- understand affected deployment paths
- test before committing
