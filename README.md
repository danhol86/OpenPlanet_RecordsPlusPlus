# Friends Ghost Leaderboard

Openplanet plugin for Trackmania 2020 that adds the user's actual Ubisoft/Trackmania friends directly into Trackmania's native Records leaderboard.

## Features

- Automatically loads the signed-in user's friends through Trackmania's `Friend_GetList` API.
- Fetches each friend's Personal Best for the current map.
- Adds a native `FRIENDS` Records zone using Trackmania's own leaderboard UI.
- Includes your own PB in the FRIENDS ranking for direct comparison.
- Keeps FRIENDS directly after WORLD for quick native arrow navigation.
- Automatically refreshes while the map stays open and immediately after a completed run.
- Uses Trackmania's native eye button to load/remove a friend's ghost.
- Uses Trackmania's own `HIDE PB GHOST` control while racing a friend.
- Uses the game's normal record/replay interactions instead of a separate plugin leaderboard window.
- Refreshes automatically when the current map changes.

## Requirements

- Trackmania 2020 on PC.
- Openplanet.
- MLHook.
- Trackmania ghost/record access is required for native ghost/replay actions. The time leaderboard itself is loaded from Trackmania services.
- For this local unsigned development build, set `Openplanet > Signature Mode > Developer`.

## Local install

The dev build is copied to:

`C:\Users\danho\OpenplanetNext\Plugins\FriendsGhostLeaderboard`

Open Openplanet with F3 and reload the plugin after code changes.
