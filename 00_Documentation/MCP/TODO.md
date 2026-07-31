# MCP Integration TODO

## Purpose

This document records the current Model Context Protocol (MCP) decisions for the
Palworld Modding Workshop and defines a safe implementation path for future MCP
features and upgrades.

The workshop is a personal learning, automation, and backup environment. It may
be migrated to another computer, but it is not intended to be a general-purpose
or redistributable PowerShell package.

MCP is an integration layer around the workshop. It must not replace the
PowerShell module, duplicate workshop logic, or bypass the existing safety,
preview, backup, validation, logging, and recovery workflows.

## Architectural direction

The intended dependency order is:

```text
PowerShell commands
        |
JSON configuration and manifests
        |
Tests and diagnostics
        |
PwWorkshop menu and dashboard
        |
MCP and AI integrations
```

The existing PowerShell module and repository contracts remain authoritative.
Future MCP features should call established workshop commands and consume their
structured output rather than implement separate catalog, profile, intake,
compatibility, assembly, deployment, recovery, or diagnostic logic.

## Current MCP configuration

The tracked workspace configuration is `.vscode/mcp.json`.

Current servers:

- `PalWorldWorkshop`
  - Generic filesystem MCP server.
  - Uses `npx` and `@modelcontextprotocol/server-filesystem`.
  - Is restricted to `${workspaceFolder}`.
  - Contains no hardcoded workshop path.
  - Contains no stored credential value.
- `github`
  - GitHub HTTP MCP endpoint used by supported VS Code and agent workflows.

Recovered implementation decisions:

- Replace absolute paths such as `D:\Projects\Palworld-Modding` with
  `${workspaceFolder}`.
- Do not store GitHub tokens or other credentials in tracked MCP configuration.
- Remove unused token prompts when they are not referenced by a configured
  server.
- Keep the configuration useful for Noel's personal environment while making
  repository migration straightforward.
- Treat ChatGPT GitHub connector authorization, Codex cloud environment access,
  VS Code GitHub MCP access, and local Git authentication as separate execution
  contexts. Do not assume that authorization in one context automatically
  applies to another.

## Responsibility boundaries

### PowerShell module

The PowerShell module remains responsible for:

- Workshop configuration and initialization.
- Profiles and machine-specific paths.
- Mod intake and normalization.
- Catalog and metadata management.
- Compatibility and dependency reporting.
- Deployment assembly and preview.
- Backup, deployment, restoration, and recovery.
- Diagnostics, validation, and health reporting.
- Approval and destructive-operation safeguards.

### Filesystem MCP

The generic filesystem MCP is intended for:

- Reading repository files.
- Inspecting documentation and configuration.
- Editing source files during approved development work.
- Supporting AI-assisted repository maintenance.

The filesystem MCP must remain restricted to `${workspaceFolder}`.

It must not receive direct access to:

- `D:\Games\Palworld`
- `%LOCALAPPDATA%\Pal`
- Drive roots such as `D:\`
- External backup roots
- Other unrelated user directories

Direct access to those paths would bypass the workshop profile, preview, backup,
hash-verification, logging, and recovery layers.

### GitHub MCP and connector integrations

GitHub MCP and connector integrations are intended for remote repository
metadata and supported GitHub operations.

Local working-tree operations should continue to use Git and the established
`pw-git` workflow where applicable, including:

- Status and diff review.
- Branch and worktree inspection.
- Staging and commits.
- Pull and push operations.
- Local repository validation.

The GitHub MCP must not become a duplicate implementation of `pw-git`.

## Naming cleanup

The current `PalWorldWorkshop` server name describes a generic filesystem
server, not a workshop-aware MCP implementation.

Recommended future rename:

```text
PalworldWorkspaceFilesystem
```

or:

```text
palworld-workspace
```

Reserve `PalworldWorkshop` for a future custom MCP server that exposes actual
workshop state and commands.

Renaming should be handled as a documented configuration change and verified in
VS Code before committing.

## Immediate documentation work

- [x] Record recovered MCP decisions and future implementation direction in this
  document.
- [ ] Create `00_Documentation/MCP/README.md` as the canonical MCP setup and
  operations guide.
- [ ] Link the MCP guide from the root `README.md`.
- [ ] Link the MCP guide from `00_Documentation/Environment.md`.
- [ ] Document the distinction between:
  - VS Code MCP servers.
  - ChatGPT GitHub connector access.
  - Codex local tasks.
  - Codex cloud environments.
  - Local Git and `pw-git` authentication.
- [ ] Add a concise migration checklist for a new computer.
- [ ] Add troubleshooting guidance for workspace resolution, Node/npm/npx,
  GitHub authorization, server startup, and invalid JSON.

## MCP configuration validation

Add MCP configuration checks to the workshop diagnostic model. This work fits
within Sprint 5.1.5 diagnostics and health reporting.

Recommended public or internal command:

```powershell
Test-PwMcpConfiguration
```

The implementation may instead be an internal provider consumed by
`Get-PwDiagnostics` or `Test-PwEnvironment` if a separate public command is not
needed.

Validation requirements:

- [ ] Confirm `.vscode/mcp.json` exists.
- [ ] Confirm the file contains valid JSON.
- [ ] Confirm a `servers` object exists.
- [ ] Confirm every server has a supported transport.
- [ ] Confirm the filesystem server uses `${workspaceFolder}`.
- [ ] Reject or warn on absolute repository paths.
- [ ] Reject tracked credential, token, password, or secret values.
- [ ] Confirm HTTP MCP endpoints use valid HTTPS URLs.
- [ ] Confirm `node`, `npm`, and `npx` availability when the filesystem MCP is
  configured.
- [ ] Confirm the canonical MCP documentation exists.
- [ ] Distinguish warnings from blocking failures.
- [ ] Report MCP unavailability separately from core workshop readiness.

Recommended status values:

```text
Ready
Warning
Unavailable
Invalid
```

MCP should remain optional for normal workshop operation. A missing Node.js
installation or unavailable MCP endpoint should normally produce a warning, not
make the PowerShell workshop unusable.

## Automated tests

Add focused tests without requiring external services or network access.

Recommended assertions:

- [ ] `.vscode/mcp.json` parses as valid JSON.
- [ ] The filesystem server uses `${workspaceFolder}`.
- [ ] The MCP configuration contains no absolute workshop path.
- [ ] The MCP configuration contains no tracked credential values.
- [ ] All configured transports are supported.
- [ ] HTTP endpoints use HTTPS.
- [ ] The canonical MCP documentation exists.
- [ ] Diagnostic output separates MCP warnings from core workshop errors.
- [ ] Existing workshop commands work when MCP dependencies are unavailable.

The normal Pester suite must not require:

- GitHub to be online.
- GitHub authorization to be active.
- npm to download packages.
- An MCP server to establish a network connection.
- A Codex cloud environment to exist.

External connectivity checks should be optional integration diagnostics.

## Package version policy

The filesystem server currently references:

```text
@modelcontextprotocol/server-filesystem
```

without an explicit package version.

For reproducibility and migration safety:

- [ ] Determine the currently resolved and working package version.
- [ ] Verify that version with the current VS Code and Node.js environment.
- [ ] Record the validated package version and validation date.
- [ ] Pin the package version in `.vscode/mcp.json` after validation.
- [ ] Upgrade only during an intentional maintenance change.
- [ ] Review release notes before upgrading.
- [ ] Run MCP configuration checks and normal workshop tests after upgrading.
- [ ] Retain a documented rollback version.

Do not select or pin a version based only on an assumed latest release. Verify
the local and supported version first.

## Future custom Palworld Workshop MCP server

A custom MCP server may be valuable after the Sprint 5 runtime, session, and
dashboard models are stable.

The custom server should be a thin adapter over structured PowerShell commands.
It must not reimplement workshop business logic.

Expected flow:

```text
MCP request
    |
PowerShell adapter
    |
Existing PalworldModding command
    |
Structured JSON result
```

### Phase 1: read-only tools

Implement read-only tools first.

Potential tools:

- [ ] `get_workshop_summary`
- [ ] `get_repository_health`
- [ ] `get_active_profile`
- [ ] `get_mod_catalog`
- [ ] `get_staging_reconciliation`
- [ ] `get_compatibility_report`
- [ ] `get_deployment_preview`
- [ ] `get_installation_inventory`
- [ ] `get_workshop_diagnostics`

Requirements:

- [ ] Use existing PowerShell commands as the source of truth.
- [ ] Return structured, deterministic JSON.
- [ ] Perform no writes during initialization or read-only requests.
- [ ] Avoid hidden global state.
- [ ] Preserve the one-command `PwWorkshop.ps1` workflow.
- [ ] Keep the custom server optional.
- [ ] Add compatibility and regression tests.

### Phase 2: controlled write tools

Consider write-capable tools only after the read-only layer is stable and
reviewed.

Potential tools:

- [ ] `import_mod_archive`
- [ ] `update_catalog_metadata`
- [ ] `build_profile_deployment`
- [ ] `apply_deployment`
- [ ] `restore_backup`

Write-tool requirements:

- [ ] Delegate to existing PowerShell commands.
- [ ] Produce a preview before an apply operation.
- [ ] Preserve `SupportsShouldProcess` and `-WhatIf` behavior.
- [ ] Require explicit user approval for external or destructive changes.
- [ ] Revalidate current state immediately before applying.
- [ ] Use the same backups, hashes, logs, and manifests as the normal workshop.
- [ ] Never copy directly to the live game outside the deployment engine.
- [ ] Never delete live game files unless a future feature explicitly defines,
  previews, approves, backs up, and tests that behavior.
- [ ] Return clear partial-failure and recovery information.

## Roadmap placement

### Sprint 5.1.1: repository awareness and structure documentation

- [ ] Create the canonical MCP README.
- [ ] Clarify the generic filesystem server name.
- [ ] Link MCP documentation from repository entry points.
- [ ] Ensure generated repository documentation includes the MCP documents.

### Sprint 5.1.2 through 5.1.4: runtime, dashboard, and menu

- [ ] Keep MCP requirements in mind while designing structured session and
  dashboard models.
- [ ] Ensure dashboard data is language-neutral and serializable.
- [ ] Avoid terminal-formatting dependencies in structured providers.
- [ ] Preserve command authority so the menu and MCP can consume the same model.

### Sprint 5.1.5: diagnostics and health reporting

- [ ] Add MCP JSON, dependency, workspace, documentation, and security checks.
- [ ] Report MCP health without blocking the core workshop unnecessarily.
- [ ] Add Pester coverage for configuration validation.

### Later Sprint 5 increment

- [ ] Design and prototype the custom read-only Palworld Workshop MCP adapter.
- [ ] Implement only after the session and dashboard contracts are stable.

### Sprint 6: packaging and maintenance

- [ ] Pin validated MCP package versions.
- [ ] Add an MCP upgrade checklist.
- [ ] Record version compatibility and validation dates.
- [ ] Include MCP setup in migration and disaster-recovery testing.
- [ ] Include MCP documentation in repository synchronization checks.
- [ ] Add a rollback procedure for failed MCP upgrades.

## Upgrade procedure

Use the following process for future MCP changes:

1. Review the existing MCP documentation and current configuration.
2. Identify one server, package, endpoint, or capability to change.
3. Review the provider's release notes and migration requirements.
4. Confirm the current working version and configuration.
5. Apply the smallest possible configuration change.
6. Run JSON and MCP configuration validation.
7. Run the complete workshop Pester suite.
8. Test VS Code server startup and basic read-only access.
9. Confirm no secrets or machine-specific absolute paths were introduced.
10. Update MCP documentation and version records.
11. Commit the change separately from unrelated workshop feature work.
12. Retain a documented rollback path.

Do not silently auto-upgrade MCP packages or add multiple experimental servers
in one change.

## Security and safety rules

- [ ] Keep filesystem access restricted to the repository workspace.
- [ ] Keep credentials outside tracked repository files.
- [ ] Use supported authentication flows instead of embedded tokens.
- [ ] Treat external MCP output as untrusted input until validated.
- [ ] Do not allow MCP tools to bypass profile resolution.
- [ ] Do not allow MCP tools to bypass deployment preview and backups.
- [ ] Do not allow MCP tools to redefine the catalog or profile schemas.
- [ ] Require explicit approval for writes to GitHub, the game installation,
  save data, or external backups.
- [ ] Log and identify the execution context for write operations when possible.
- [ ] Preserve recovery information for all approved external writes.

## Explicit non-goals

Do not implement the following as part of the current MCP work:

- Direct generic filesystem access to the Palworld installation.
- A second deployment engine implemented inside MCP.
- Duplicate catalog, profile, compatibility, or recovery schemas.
- Stored GitHub, Nexus Mods, or other service credentials in `mcp.json`.
- A mandatory MCP dependency for normal workshop startup.
- Automatic package upgrades without review and validation.
- Multiple experimental MCP servers without assigned responsibilities.
- A full rewrite of the PowerShell workshop in another language.

## Completion criteria

The MCP foundation will be considered mature when:

- MCP setup and responsibility boundaries are documented in one canonical
  location.
- The configuration is migration-friendly and contains no secrets.
- Diagnostics can identify invalid configuration and missing dependencies.
- Core workshop operation remains functional without MCP.
- Package upgrades are intentional, tested, recorded, and reversible.
- A future custom server consumes the same structured PowerShell models as the
  menu and dashboard.
- All write-capable MCP actions preserve the workshop's existing preview,
  approval, backup, validation, logging, and recovery guarantees.
