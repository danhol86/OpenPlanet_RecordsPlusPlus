# Records++

Records++ adds a **FRIENDS** ranking directly to Trackmania's native Records panel.

It uses your Ubisoft/Trackmania friend list, fetches each friend's Personal Best for the current map, and inserts those records into the same native UI used by WORLD and regional rankings. Trackmania's own ghost eye controls and **HIDE PB GHOST** option continue to work normally.

## Features

- Native **FRIENDS** Records category, directly after WORLD.
- Automatically loads the signed-in user's Trackmania friends.
- Shows friend PBs plus the local player's PB in one ranking.
- Uses Trackmania's native row styling, navigation and ghost controls.
- Refreshes friend PBs periodically and again after a completed run.
- Queries only explicit friend account IDs; it does not download full leaderboards.
- Respects `Permissions::ViewRecords()` so it does not expose records where Trackmania disallows them.
- Relies on Trackmania's native permissions/UI for playing record ghosts.

## Requirements

- Trackmania 2020 on PC.
- Openplanet.
- MLHook.

## Build

```powershell
./build.ps1
```

The package is written to `build/RecordsPlusPlus-<version>.op`.

For local development installation:

```powershell
./build.ps1 -Install
```

Unsigned development builds require Openplanet's **Developer** signature mode. Approved website builds are signed by Openplanet and can run in **Regular** mode.

## Releases

Push a tag matching the plugin version, for example `v0.3.0`. The GitHub Actions release workflow builds the `.op` package and attaches it to a GitHub Release.

Openplanet website publication is a separate review/signing step; see [PUBLISHING.md](PUBLISHING.md).

## Development disclosure

This project has used AI-assisted development. Any Openplanet website submission must accurately disclose that assistance and comply with Openplanet's current AI-classification and plugin-review rules.

## License

MIT. See [LICENSE](LICENSE).
