# Workshop Menu Flow

This document is the living reference for the `PwWorkshop.ps1` interactive
menu. It tracks the current navigation structure so the menu can grow without
losing the intended hierarchy.

## Principles

- `Q` quits the current prompt or menu level.
- `B` goes back one menu level when a submenu is active, except where a menu
  already assigns `B` to a specific action.
- `Enter` usually returns to the previous menu level without applying changes.
- Read-only views stay read-only until the user explicitly chooses to apply
  something.

## Main Menu

The top-level menu is the one shown by `Start-PwWorkshop`.

- `1` Catalog
- `2` Archive intake and staging
- `3` Staging and ownership snapshot
- `4` Updates
- `5` Compatibility and conflict report
- `6` Profile mod sets
- `7` Stage, experiment, build, or deploy
- `8` Diagnostics
- `9` Installation inventory
- `0` Deployment and restore history
- `Q` Exit

## Catalog Submenu

The catalog submenu is a nested loop. It stays open until the user presses
`B`, `Enter`, or `Q` at the catalog prompt.

Actions:

- `L` list catalog mods
- `W` list catalog warnings
- `S` show the catalog sync plan
- `R` inspect remote metadata
- `E` edit catalog identity fields
- `G` show staging reconciliation groups and assign component ownership
- `H` show compatibility and conflict details

Back behavior:

- `B` returns to the main menu from the catalog submenu.
- `Enter` also returns to the main menu from the catalog submenu.
- Prompts inside `R` and `E` now accept `B` to return to the catalog submenu
  instead of dropping all the way back to the main menu.
- `G` numbers unresolved PAK, LogicMods, and configuration components. A
  component can be assigned to an existing numbered catalog record or used to
  create a new metadata-only identity for a PAK-only mod.
- Long report and picker screens redraw as fixed paged views sized from the
  current terminal. `N` and `P` move between pages without changing the
  screen's existing action keys. Numbered selections retain their absolute
  numbers across pages.
- This applies to catalog lists and warnings, remote metadata and identity
  review, staging groups and ownership, archives and archive contents, the
  staging snapshot, updates, deployment inventory and history, mod sets and
  previews, and compatibility reports.

## Workflow and deployment (`7`)

- `S` runs the standard staged build: captures reviewed staging groups into
  `03_Mod_Library` and builds verified loose output in `05_Deployment`.
- `E` creates an isolated experiment/debug build under
  `15_Sandbox\ProfileExperiments`; it changes neither the curated library nor
  the game.
- `C` adopts a current-game-only mod into staging and the catalog. A Nexus ID
  can be verified before copying, then a reviewed Nexus file can be downloaded
  into `01_Archives` for Premium accounts or opened for manual download.
- `D` performs readiness verification and requires the exact text `DEPLOY`
  before invoking the backed-up live deployment.
- `V` re-hashes and verifies the assembled output against its manifest.
- `R` compares the verified deployment with the current game and reports
  identical, new, changed, and current-game-only files.
- Current-game-only files are review information and are not deleted.
- Ownership lists are compact numbered tables so they remain usable in the same
  narrow terminal sizes supported by the main responsive menu.

## Archives Submenu

The archives submenu is also a nested loop.

Actions:

- `I` inspect and import an archive

Back behavior:

- `B` returns to the main menu from the archives submenu.
- `Enter` returns to the main menu from the archives submenu.
- During archive import prompts, `B` returns to the archive submenu.

## Updates Submenu

The updates submenu is a nested loop. Successful Nexus and GitHub metadata
responses are reused for up to ten minutes within the current module session so
reopening or navigating within the menu does not repeat identical API calls.
Local archive and catalog state is still read normally.

Actions:

- Enter a Nexus mod ID to open the manual or Premium update flow.
- `U` records or inspects the UE4SS source baseline flow.
- `R` clears the in-memory Nexus and GitHub metadata cache and reruns both
  update reports.
- `B` returns to the main menu.
- `Enter` also returns to the main menu.

Manual-download behavior:

- The browser page opens after the menu displays the resolved `01_Archives`
  location.
- The user must save the completed ZIP or 7z file into that directory.
- Browser completion is not monitored automatically.
- After the download finishes, use `R` to rescan local archives and refresh
  remote metadata.
- Use menu option `2` to inspect and import the downloaded archive.

Direct-download behavior:

- The selected mod and file are refreshed immediately before approval.
- A stale or non-actionable row is refused.
- Nexus download-link responses are never cached.
- Approved direct downloads are inspected before being moved into
  `01_Archives`.

Back behavior:

- `B` and `Enter` return to the main menu from the update report.
- Nested manual, direct, and UE4SS prompts accept `B` to return to the updates
  submenu.
- `Q` exits the workshop.

## Profile Mod Sets Submenu (`6`)

The profile mod sets submenu is a nested loop tied to the active deployment
profile.

## Staged UE4SS Snapshot

Menu option `3` now mirrors the migrated `02_Staging\Pal\Binaries\Win64\ue4ss\Mods`
tree when that layout is present. It remains a read-only view of the active
UE4SS/Lua staging folders and their enablement markers.

Actions:

- `N` create or replace a named mod set for the active profile
- `V` preview the currently active mod set

Back behavior:

- `B` returns to the main menu from the profile mod sets submenu.
- `Enter` returns to the main menu from the profile mod sets submenu.
- Nested prompts inside the create flow accept `B` to step back without saving.

## Current Navigation Notes

- Catalog, archive, and update actions are grouped as dedicated submenu loops.
- Profile mod sets follow the same submenu pattern and are profile-scoped.
- The main menu still redraws after each completed action.
- Submenu prompts should be updated before adding new action branches so they
  continue to support `B` consistently.
