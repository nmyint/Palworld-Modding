# Optional Update Sources

The workshop can check explicitly configured Nexus Mods and GitHub release
sources without changing, downloading, or deploying anything. The feature is
configured in `.config\UpdateSources.json` and can be disabled globally or per
source.

## Current source preferences

- **UE4SS** uses the official Palworld-specific
  `Okaetsu/RE-UE4SS` GitHub release tagged `experimental-palworld`. It selects
  `UE4SS-Palworld.zip`, not the developer `zDEV` package. Nexus mod 3035 is
  retained only as a disabled alternate because it is a Vortex-oriented
  repackage and may lag the GitHub asset.
- **PalSchema** uses Nexus mod 3037. The `Okaetsu/PalSchema` GitHub releases page
  is retained only as a disabled alternate.

Run:

```powershell
Get-PwSourceUpdateReport
```

The same report appears below the Nexus mod report in menu option
**Check mod and tool updates**. Enter `U` there to start the UE4SS baseline
workflow. After reviewing the displayed asset and confirming that exact build
has been installed and validated, approve the prompt to record it as the
installed baseline. Enter `B` to return without changing the baseline.

GitHub public releases do not require a token. `GITHUB_TOKEN` is used when it is
already present, which raises GitHub API rate limits. Nexus sources use the
existing `NEXUSMODS_API_KEY` configuration.

## Mutable GitHub tags

The UE4SS tag does not change when its downloadable ZIP is rebuilt. Therefore,
the checker compares the selected asset ID and its `updated_at` value instead
of treating the tag as a semantic version.

Until an installed GitHub build has been recorded, its status is `Untracked`.
After installing and validating the reported build, record that exact remote
asset as the installed baseline:

```powershell
Set-PwGitHubSourceBaseline -Key UE4SS
```

This updates only `.config\UpdateSources.json`; it does not install anything.

## Source discovery

For Nexus entries, GitHub repository or release URLs found in the API
description are exposed as `DiscoveredGitHubSources`. They are advisory. The
checker never follows them or silently replaces the configured provider.
