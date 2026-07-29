# Daily Workshop Workflow

This is the repeatable checklist for installing, updating, customizing, testing,
and deploying Palworld mods through `PwWorkshop.ps1`.

Start from the repository root:

```powershell
pwsh -NoProfile -File ./PwWorkshop.ps1
```

## Choose an editor

Use VS Code for Lua, JSON, INI, configuration, and PowerShell files. It provides
diffs, Git history, encoding visibility, and JSON validation. Notepad++ is fine
for quick inspection or a simple one-file edit, but VS Code is the safer default
for managed workshop changes.

## Add a new downloaded mod

1. Put the original ZIP or 7z file in `01_Archives`.
2. Open menu `2` and choose `I`.
3. Select the archive and review every normalized destination.
4. Continue only when UE4SS, `~mods`, and LogicMods files map correctly.
5. The importer places payloads into the normalized `02_Staging\Pal` layout.
6. Open menu `3` and confirm the mod appears in staging.
7. Open menu `1`, then `G`, and resolve any ownership review.
8. Open menu `1`, then `E`, to add or correct its Nexus ID, version, aliases,
   platform, or play-mode metadata.
9. Add the catalog key to the appropriate profile mod set in menu `6`.

## Check and download updates

1. Open menu `4`.
2. Review local and remote versions. The catalog's installed variant prevents a
   Singleplayer archive from being compared with a Dedicated Server file.
3. Enter the Nexus mod ID for the item being updated.
4. Premium users may choose the direct API download. Otherwise open the Nexus
   files page and download manually into `01_Archives`.
5. Return to menu `2` and import the downloaded archive.
6. Review configuration changes before replacing customized staging settings.
7. Re-run menu `3`, menu `1/G`, and menu `5`.

Nexus IDs, file IDs, versions, and URLs establish provenance. Local SHA-256
hashes establish byte integrity; see
[NexusHashVerification.md](NexusHashVerification.md).

## Customize settings or scripts

1. Edit the mod under `02_Staging\Pal` using VS Code.
2. Keep changes limited to that mod's Lua/configuration files.
3. Do not copy logs, caches, `mods.txt`, or `mods.json` into a package.
4. Run menu `3` to confirm staging still inventories correctly.
5. Run menu `5` to check compatibility and variant warnings.
6. Rebuild with menu `7/S`. The changed files receive new local SHA-256 hashes,
   making the customization explicit and reproducible.

## Choose a workflow

### Standard staged workflow

Use menu `7/S` when staging is ready:

1. Reconciliation must have zero unresolved ownership items.
2. The active profile mod set must contain every intended mod.
3. Runtime state is excluded.
4. Curated, versioned 7z packages and manifests are written to
   `03_Mod_Library`.
5. Verified loose files are assembled beneath `05_Deployment\Pal`.
6. The live game is not changed.

### Experiment or debug workflow

Use menu `7/E` for an isolated copy:

1. Enter a short experiment label.
2. The current profile is copied to a timestamped directory beneath
   `15_Sandbox\ProfileExperiments`.
3. All copied files are SHA-256 verified.
4. Curated library packages, normal deployment output, and the game remain
   unchanged.
5. Use this for inspection, script experiments, and disposable debugging.

### Verified direct deployment

Use menu `7/D` only after reviewing `V` and `R`:

1. `V` verifies every assembled file against the assembly manifest.
2. `R` compares deployment with the current game:
   - `Identical` needs no copy;
   - `DeploymentOnly` will be added;
   - `Different` will overwrite the game copy;
   - `CurrentGameOnly` remains installed and is never silently deleted;
   - runtime/state files are reported separately.
3. Resolve unexpected current-game-only mods before deploying.
4. Select `D`. Verification runs again.
5. Read the create, update, and current-only counts.
6. Type the exact word `DEPLOY`.
7. Files being overwritten are backed up under `13_Backups\Deployments`.
8. Create and Update files are copied and hashed again.
9. A structured result is written under `09_Logs\Deployments`.
10. Launch Palworld and test. Recording a known-good installation remains a
    separate explicit step.

## Adopt a mod found only in the current game

Use menu `7/C`, for example when `LessBaseHud` appears in the game but not in
staging:

1. Select the numbered current-game-only candidate.
2. Enter its known Nexus mod ID, or leave it blank for a manual identity.
3. Review the Nexus name, version, and match confidence.
4. Approve adoption only when the identity is correct.
5. The workshop copies the live payload to its normalized `02_Staging\Pal`
   path and verifies the copy hash.
6. A catalog identity is created or updated.
7. Select the correct Nexus file for download into `01_Archives`, or open the
   Nexus page for manual download.
8. Import the downloaded archive through menu `2`; compare it with the adopted
   working copy before replacing custom settings.
9. Add the catalog key to the profile mod set in menu `6`.
10. Rebuild and review through menu `7/S`, `V`, and `R`.

## After successful in-game testing

1. Record the installation as known-good.
2. Preserve the curated package, manifest, catalog, and profile metadata.
3. Clean only generated staging/deployment artifacts whose hashes still match
   their manifests.
4. Commit lightweight code and metadata to Git.
5. Keep binary archives and workshop payloads in the external 7z backup rather
   than Git.
