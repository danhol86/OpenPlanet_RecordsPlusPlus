# Friends Ghost Leaderboard

Openplanet plugin for Trackmania 2020 that turns the user's actual Ubisoft/Trackmania friend list into a live current-map leaderboard.

## Features

- Automatically loads the signed-in user's friends through Trackmania's `Friend_GetList` API.
- Fetches each friend's Personal Best for the current map.
- Sorts friends by time and shows the gap to the fastest friend.
- Automatically refreshes while the map stays open.
- `Race` loads/removes that friend's record as a ghost.
- `Watch` loads the ghost if needed and switches to replay/spectate view through MLHook.
- Optional automatic loading of the fastest friend ghosts.
- Refreshes automatically when the current map changes.

## Requirements

- Trackmania 2020 on PC.
- Openplanet.
- MLHook.
- Trackmania ghost/record access is required for Race/Watch actions. The time leaderboard itself is loaded from Trackmania services.
- For this local unsigned development build, set `Openplanet > Signature Mode > Developer`.

## Local install

The dev build is copied to:

`C:\Users\danho\OpenplanetNext\Plugins\FriendsGhostLeaderboard`

Open Openplanet with F3 and reload the plugin after code changes.
