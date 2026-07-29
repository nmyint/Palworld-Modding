# Mod Intake

Sprint 3.5 introduces a preview-first path from downloaded ZIP and 7z archives into the
workshop's staging area, curated mod library, and generated deployment output. It
never writes to the live Palworld installation.

## Workflow

```text
Download -> Inspect -> Archive -> Stage -> Validate -> Review -> Publish
```

- Original ZIP or 7z downloads are preserved beneath `01_Archives`.
- `02_Staging` is the current working mod setup. It holds the extracted and
  reconciled files you are actively using for review, validation, and profile
  assembly, and it is ignored by Git.
- Published packages are recompressed as curated `package.7z` files beneath
  `03_Mod_Library`.
- Generated game-layout files live beneath `05_Deployment\Pal` and are ignored by
  Git.
- Portable per-mod deployment archives live beneath `05_Deployment\Packages`.

## Supported formats

ZIP archives are handled with built-in .NET compression APIs. The workshop
discovers `7z.exe` from configuration, Windows registration, the command path, or
the standard Program Files locations.

Both ZIP and 7z downloads receive the same path, entry-count, expanded-size, and
manifest validation. Encrypted 7z entries and archive links are rejected.

## Inspect an archive

Inspection reads archive metadata and file hashes without extracting anything:

```powershell
$info = Get-PwModArchiveInfo -Path 'C:\Downloads\ExampleMod.7z'
$info
$info.Entries | Format-Table ArchivePath, Category, DeploymentRelativePath
```

Inspection rejects:

- absolute paths and parent-directory traversal;
- Windows alternate data stream syntax;
- invalid or reserved Windows file names;
- duplicate paths;
- more than 10,000 entries;
- suspicious compression ratios; and
- archives that expand beyond 5 GB.

Native DLLs and unclassified files are allowed into staging but marked for manual
review.

## Stage a package

Use stable identifiers for the mod and its version:

```powershell
Import-PwModArchive `
    -Path 'C:\Downloads\ExampleMod.zip' `
    -Name 'ExampleMod' `
    -Version '1.2.0' `
    -Author 'Example Author' `
    -SourceUri 'https://example.invalid/mod'
```

The command:

1. inspects the ZIP or 7z archive;
2. copies the original archive into `01_Archives`;
3. extracts only validated files into the current staging tree beneath
   `02_Staging\<Name>\<Version>\Source`;
4. verifies every extracted SHA-256 hash; and
5. creates a normalized maximum-compression `package.7z`; and
6. writes `manifest.json` with metadata, hashes, and deployment mappings.

Common archive layouts are normalized automatically:

- `<ModName>\Scripts\...` becomes
  `Pal\Binaries\Win64\ue4ss\Mods\<ModName>\Scripts\...`;
- root-level PAK files become `Pal\Content\Paks\~mods\...`;
- `~mods\...` and `LogicMods\...` retain their distinct PAK destinations; and
- archives containing both UE4SS and PAK components retain both beneath the
  same package version.

Files without a safe, recognizable game destination are retained beneath
`Source\_Review` and are not deployed automatically. This covers malformed,
unusually nested, or otherwise ambiguous archives without discarding their
contents.

Use `-WhatIf` to preview the staging location without writing files.

## Reconcile an existing installation capture

The staging reconciliation report understands both the older top-level UE4SS
folders and captured game-relative PAK content:

```powershell
$report = Get-PwStagingReconciliation
$report.Groups |
    Format-Table DisplayName, PackageTypes, ComponentCount, IsMixedPackage
$report.ReviewItems |
    Format-Table OwnerName, SourceArea, PackageType, RelativePath
```

The report is read-only. It groups components only when a filename or UE4SS
folder matches a reviewed catalog identity. Unmatched files remain review items
instead of being silently assigned to an unrelated mod. In the workshop menu,
open **Catalog and versions**, then choose **Staging groups**.

## Validate a staged package

```powershell
Test-PwModPackage -Name 'ExampleMod' -Version '1.2.0'
```

Validation checks manifest identity, required properties, file presence, safe
paths, and hashes.

## Publish a package

Preview is the default:

```powershell
$plan = Publish-PwModPackage -Name 'ExampleMod' -Version '1.2.0'
$plan.DeploymentFiles | Format-Table Action, DeploymentRelativePath
```

The plan refuses promotion when the library version already exists or a mapped
deployment path contains different content.

After reviewing the plan:

```powershell
Publish-PwModPackage `
    -Name 'ExampleMod' `
    -Version '1.2.0' `
    -Apply
```

Packages containing native or unclassified files require manual review and the
additional `-AllowReviewRequired` switch.

Publishing reuses the verified staging package and creates:

- `03_Mod_Library\<Name>-<Version>\package.7z`, containing the curated source;
- a library manifest with the package SHA-256 hash;
- `05_Deployment\Packages\<Name>-<Version>.7z`, containing the portable
  game-layout bundle; and
- verified loose files beneath `05_Deployment\Pal` for the deployment engine.

The normalized 7z packages use maximum compression. Use the separate deployment
preview before making any change to Palworld.

## Installation and testing records

The later numbered directories are not additional unpacking stages:

- `06_Current_Installation` will record the known-good installed mod set, file
  hashes, and validation status. It will not duplicate all mod files.
- `07_Testing` stores test plans, compatibility notes, regression results, and
  logs. It does not deploy files.
- `13_Backups` stores recovery copies of live files overwritten during deployment.

Curated compressed packages remain authoritative in `03_Mod_Library`.

If `02_Staging` is being used as the live working copy of your current setup,
keep the repository-level staging mirror aligned with the actual `ue4ss\Mods`,
`Pal\Content\Paks\~mods`, and `Pal\Content\Paks\LogicMods` content you are
testing. That lets the workshop redownload missing archives while still
reflecting the real in-game layout you are maintaining locally.

## Complete validation and clean temporary files

After deployment succeeds and the mod has been tested inside Palworld, preview
completion:

```powershell
Complete-PwModInstallation `
    -Name 'ExampleMod' `
    -Version '1.2.0' `
    -GameValidated
```

Review `VerificationErrors`, `InstalledFiles`, and `Cleanup`. If
`CanComplete` is `True`, record the known-good installation and clean the
temporary copies:

```powershell
Complete-PwModInstallation `
    -Name 'ExampleMod' `
    -Version '1.2.0' `
    -GameValidated `
    -Notes 'Loaded a save and verified the mod in game.' `
    -Apply
```

The command first verifies the curated package and installed game-file hashes.
It then writes
`06_Current_Installation\Mods\<Name>\<Version>.json`. Only after that record is
readable does it remove:

- `02_Staging\<Name>\<Version>`;
- `05_Deployment\Packages\<Name>-<Version>.7z`; and
- matching, unchanged loose files under `05_Deployment`.

It never removes the original download, curated library package, installed game
files, or deployment backups. Cleanup never removes the established
`05_Deployment` directory tree. It removes only the selected mod's generated
archive and verified loose files, leaving shared folders and `.gitkeep`
placeholders intact for subsequent deployments.
