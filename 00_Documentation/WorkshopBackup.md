# Git and External Backup Policy

Git is used for versioned source and lightweight metadata. It is not the binary
backup service for the workshop. Complete durable workshop data is stored in
dated 7z archives on external storage such as Google Drive.

## Git scope

Git tracks:

- scripts, tests, tasks, and configuration;
- documentation, templates, and source projects;
- curated mod manifests;
- known-good installation metadata;
- reusable testing and research notes; and
- personal profiles used by this private workshop.

Git ignores:

- original downloads in `01_Archives`;
- temporary `02_Staging` content;
- binary packages in `03_Mod_Library`;
- project build output and compiled mod files;
- generated `05_Deployment` content;
- generated test results, downloaded tools, and logs;
- downloaded research binaries;
- `13_Backups`; and
- disposable `15_Sandbox` content.

Tracked `.gitkeep` files preserve the workshop structure. Generated
`manifest.json` files in `03_Mod_Library` remain tracked even though mod
payloads and `package.7z` do not.

## Configure Google Drive or OneDrive

Set `Backup.DestinationRoot` in `.config\Workshop.json` to a directory managed
by the desktop synchronization client. The path must be a normal local
filesystem directory; a browser-only Google Drive or OneDrive location cannot
be used directly by 7-Zip.

Google Drive for desktop example:

```json
"Backup": {
    "DestinationRoot": "G:\\My Drive\\Palworld Workshop Backups",
    "RetentionCount": 5
}
```

OneDrive example:

```json
"Backup": {
    "DestinationRoot": "%USERPROFILE%\\OneDrive\\Palworld Workshop Backups",
    "RetentionCount": 5
}
```

Depending on account type and Windows configuration, OneDrive may instead use a
folder such as `%USERPROFILE%\OneDrive - Organization Name`. Confirm the actual
local folder in File Explorer before configuring it.

The destination must be outside the workshop directory. Environment variables
such as `%USERPROFILE%` are supported.

Alternatively, override the destination for one run:

```powershell
New-PwWorkshopBackup `
    -DestinationRoot 'G:\My Drive\Palworld Workshop Backups'
```

After backup creation, allow the synchronization client to finish uploading the
`.7z`, `.json`, and `.sha256` files before shutting down or deleting a local
copy. A green synchronized status in File Explorer is the simplest confirmation.

## Backup contents

The default archive includes durable data, including:

- original mod downloads in `01_Archives`;
- curated packages and manifests in `03_Mod_Library`;
- projects, testing definitions, utilities, and research;
- scripts, configuration, documentation, and profiles; and
- known-good installation metadata.

The following are excluded by default because they are disposable, generated,
recursive, or already represented elsewhere:

- `.git`;
- `02_Staging`;
- `05_Deployment`;
- `09_Logs`;
- `13_Backups`; and
- `15_Sandbox`.

Use `-IncludeDisposable` only when those temporary areas are intentionally
needed. `.git` and `13_Backups` always remain excluded.

## Output and retention

Each run creates:

```text
Palworld-Workshop-<timestamp>.7z
Palworld-Workshop-<timestamp>.json
Palworld-Workshop-<timestamp>.sha256
```

The JSON sidecar records the archive hash, length, exclusions, computer, 7-Zip
path, and Git state. The SHA-256 sidecar supports verification outside the
workshop.

After a successful backup, only matching `Palworld-Workshop-*` backup sets
beyond `RetentionCount` are removed. Unrelated files in the destination are
never touched.

Use the VS Code task `PwTools: Backup Workshop` or run:

```powershell
New-PwWorkshopBackup
```
