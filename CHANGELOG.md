# Changelog

## 0.3.0

- Renamed the plugin to **Records++** and prepared the repository/package for public distribution.
- Replaced the separate floating leaderboard with a genuine `FRIENDS` zone in Trackmania's native Records panel.
- FRIENDS uses the same layout, fonts, ranking rows, ghost eye controls and replay behaviour as WORLD/region records.
- Includes the local player's PB alongside friend PBs.
- Places FRIENDS directly after WORLD in native zone navigation.
- Native ghost toggle verified in-game against a friend PB.
- Trackmania's own `HIDE PB GHOST` checkbox is now used instead of custom PB-ghost state handling.
- Friend times refresh every 30 seconds by default and immediately after a finished run.
- Added `Permissions::ViewRecords()` checks before querying or injecting records.
- Removed the legacy custom leaderboard/ghost implementation now that native Records controls are used.
- Added repeatable packaging and tagged GitHub Release automation.

## 0.2.0

- Redesigned compact friend comparison leaderboard.
- Shows the player's current PB and position among friends.
- Red `BEHIND` and green `AHEAD` comparisons against the player's PB.
- Refreshes friend records every 10 seconds by default.
- Detects the Trackmania finish sequence and refreshes again after each completed run.
- Displays an absolute `Last updated HH:mm:ss` timestamp instead of a seconds-ago counter.
- Optional automatic PB-ghost hiding while a friend ghost is loaded; restores the PB ghost when the last friend ghost is removed.

## 0.1.0

- Automatic Ubisoft/Trackmania friend discovery.
- Current-map friend PB leaderboard with live refresh.
- Race against any friend's PB as a ghost.
- Watch/spectate a friend's replay through MLHook.
- Optional automatic loading of the fastest friend ghosts.
