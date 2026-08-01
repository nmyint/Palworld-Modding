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

## Branch and Review Decision

Choose the lightest workflow that safely fits the change.

Commit directly to `main` when the change is minor, low risk, and clearly
bounded. Typical examples are small documentation fixes, narrow instruction
updates, simple metadata maintenance, and focused corrections.

Create a dedicated branch when the change starts a new sprint or major milestone,
adds a major feature, changes behavior broadly, involves a risky refactor or
migration, is experimental, has uncertain scope, or benefits materially from
isolated review and rollback.

Do not require branch creation and pull-request cleanup for routine minor edits.
If a direct `main` change expands beyond its original small scope, create a branch
before continuing the expanded work.

Branch-based work should normally be reviewed through a pull request and merged
with a merge commit. Use squash or rebase only when explicitly approved and when
no documentation or handoff depends on individual commit SHAs. Delete a merged
branch only after `main` is synchronized and the required validation passes.

## Commit Guidelines

Commits should:

- describe the actual change
- avoid unrelated modifications
- preserve a clear project history
- separate unrelated work into separate commits

Direct commits to `main` must meet the same review and validation standards as
branch-based commits.

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
