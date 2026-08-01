# Workshop Dashboard Data Model

## Status

**Sprint:** 5.1.3  
**Implementation:** In progress  
**Validation:** Pending local PowerShell and Pester execution

`Get-PwWorkshopDashboard` provides one structured, read-only snapshot of the
current Palworld Modding Workshop state. It is a data model for automation,
future terminal presentation, and later MCP or interface adapters. It is not a
menu screen and does not replace any existing command.

## Command

```powershell
Import-Module ./10_Scripts/Modules/PalworldModding.psd1 -Force
$dashboard = Get-PwWorkshopDashboard
```

For deterministic test or automation records, provide the snapshot timestamp:

```powershell
$dashboard = Get-PwWorkshopDashboard `
    -GeneratedAt ([datetime]'2026-08-01T12:00:00Z')
```

The result can be serialized without terminal-formatting dependencies:

```powershell
$dashboard | ConvertTo-Json -Depth 30
```

## Top-level contract

The dashboard returns:

| Property | Purpose |
| --- | --- |
| `SchemaVersion` | Dashboard contract version; initially `1.0` |
| `GeneratedAt` | UTC snapshot timestamp |
| `Workshop` | Existing workshop/module/runtime information |
| `Repository` | Read-only local Git branch and working-tree state |
| `Profile` | Active profile validation and selected mod-set summary |
| `Catalog` | Persistent catalog summary and deterministic compact records |
| `Deployment` | Deployment configuration, assembly plan, assembly validation, and optional readiness data |
| `UpdateCache` | Existing persistent Nexus metadata-cache information |
| `Diagnostics` | Existing workshop diagnostics result |
| `Sections` | Fixed-order collection status for every provider section |
| `ReadySectionCount` | Number of sections collected successfully |
| `UnavailableSectionCount` | Number of sections whose provider failed |
| `IsComplete` | Whether every section was collected successfully |
| `Errors` | Section name and error message for unavailable providers |

The fixed section order is:

```text
Workshop
Repository
Profile
Catalog
Deployment
UpdateCache
Diagnostics
```

## Existing command authority

The dashboard composes established providers instead of reimplementing their
business logic:

- `Get-PwWorkshopInfo`;
- `Get-PwWorkshopConfig`, `Get-PwProfile`, `Test-PwProfile`, and
  `Get-PwProfileModSetPreview`;
- `Get-PwPersistentModCatalog`;
- `Get-PwDeployment`, `Get-PwProfileAssemblyPlan`,
  `Test-PwProfileDeploymentAssembly`, and, when locally available,
  `Test-PwDeploymentReadiness`;
- `Get-PwNexusMetadataCacheInfo`;
- `Get-PwDiagnostics`.

The underlying commands remain authoritative. The dashboard only normalizes and
assembles their current output for consumers that need one model.

## Repository section

The repository section uses local, read-only Git commands. It reports:

- workshop root;
- current branch and commit;
- configured upstream when one exists;
- ahead and behind counts from the current local refs;
- clean or changed working-tree state;
- staged, unstaged, untracked, and conflict counts;
- raw short-status lines.

It does not fetch, pull, switch branches, stage, commit, push, or modify refs.
Ahead and behind values therefore describe the locally known remote-tracking ref.
Use Pw-Git explicitly when remote synchronization is required.

## Profile and catalog sections

The profile section preserves the existing distinction between:

- `IsValid`: the profile schema and required properties are valid;
- `IsReady`: the valid profile's required local paths are available.

It also reports the active mod-set name and compact selected-mod records sorted
by catalog key.

The catalog section reports catalog existence, schema, update timestamp, record
counts, reviewed Nexus coverage, installed-version coverage, source counts,
reconciliation counts, and compact records sorted by catalog key. Nexus identity
and version metadata remain provenance; they are not treated as proof of local
byte integrity.

## Deployment section

Deployment state is intentionally layered:

- `Get-PwDeployment` provides the active profile and resolved path readiness;
- `Get-PwProfileAssemblyPlan` provides current build blockers and package counts;
- `Test-PwProfileDeploymentAssembly` verifies the current assembly manifest and
  SHA-256-backed output;
- `Test-PwDeploymentReadiness` is evaluated only when the active profile can
  address a local game installation.

Each nested result has its own status and error field. An unavailable game path
therefore does not erase the deployment configuration or assembly information.
The dashboard does not build or deploy anything.

## Update cache section

The update-cache section calls `Get-PwNexusMetadataCacheInfo`. It reports the
existing local snapshot's path, timestamps, coverage, ready/error counts,
completeness, and currentness.

The dashboard never calls `Update-PwNexusMetadataCache` and never performs a
hidden Nexus or GitHub network refresh. An absent cache remains visible as an
absent cache until the user explicitly uses an established Nexus-backed workflow.

## Diagnostics section

The diagnostics section returns the existing `Get-PwDiagnostics` result. Its
health meaning remains separate from dashboard collection completeness:

- `Dashboard.IsComplete` means every dashboard provider returned data;
- `Dashboard.Diagnostics.IsHealthy` reflects the existing workshop diagnostic
  warnings and integrity checks.

A complete snapshot may correctly describe an unhealthy workshop, and an
incomplete snapshot may still contain useful healthy sections.

## Failure isolation

Every top-level provider is collected independently. When one provider throws:

- its top-level data property is `null`;
- its `Sections` entry is `Unavailable`;
- the provider message is retained in `Sections.Error` and top-level `Errors`;
- other successfully collected sections remain available.

This distinguishes a provider or local-environment limitation from a failure of
the entire workshop.

## Read-only boundary

`Get-PwWorkshopDashboard` does not call commands that:

- update the catalog;
- refresh or replace remote metadata caches;
- create or activate profiles;
- import archives;
- build curated packages or deployment output;
- deploy files to Palworld;
- restore backups;
- delete, discard, or clean workshop data.

Sprint 5.1.4 may present this model through the existing adaptive menu. Sprint
5.1.5 may add broader repository/document/configuration/test health providers.
Those later increments must continue using established command authority rather
than embedding duplicate logic in the interface.

## Validation checkpoint

Focused coverage is defined in:

```text
10_Scripts/Tests/WorkshopDashboard.Tests.ps1
```

The tests cover:

- fixed schema and section ordering;
- deterministic timestamp input and JSON serialization;
- provider-failure isolation;
- deterministic profile and catalog sorting;
- deployment readiness not being evaluated when the game target is unavailable;
- zero calls to catalog, cache, build, deployment, or restoration mutation
  commands.

Passing local results must be recorded before Sprint 5.1.3 is marked complete.
