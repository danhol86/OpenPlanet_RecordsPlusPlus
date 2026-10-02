# Records++

Adds a new FRIENDS tab into the normal Trackmania records UI and shows yourself and friends times and world positions (thinking to add option to toggle this off and show rank vs friends)

## What I used

Openplanet + AngelScript for the main plugin:

https://openplanet.dev/

MLHook to inject/send messages to the ManiaScript (added as dependency):

https://github.com/openplanet-nl/mlhook

ManiaScriptSharp so I can write the ManiaScript part in C# and have it generate the actual ManiaScript:

https://github.com/BigBang1112/maniascript-sharp

I used the Trackmania records scripts in that repo to work out the records structs and the `TMGame_Record_ZonesRecords` variables:

https://github.com/BigBang1112/maniascript-sharp/blob/main/src/ManiaScriptSharp.Trackmania/Scripts/Libs/Nadeo/TMGame/Modes/Base/UIModules/Record_Common.Script.txt

For world positions I host my own copy of:

https://github.com/Banalian/ExtraLeaderboardAPI

API:

```
https://extraleaderboardapi.agileapps.uk/ELP
```

## How it works

AngelScript is split into a few files like other Openplanet plugins:

- `src/Main.as` - starts plugin and watches for map changes
- `src/Controller/Friends.as` - gets friends and PB times
- `src/API/LeaderboardAPI.as` - gets world rank from my API
- `src/Debug/Debug.as` - debug popup/logging
- `src/Model/FriendsTime.as` - small data class

`ManiaScript/RecordsPlusPlus.ManiaScript/Class1.cs`

- this is C# but ManiaScriptSharp converts it to ManiaScript
- reads the normal Trackmania `TMGame_Record_ZonesRecords`
- adds/updates a `FRIENDS` records section

The generated ManiaScript is wrapped in its own `Generated/FriendsRecords.as` file. Openplanet compiles the `.as` files in the plugin together, so it doesnt need to be pasted into `Main.as`.

## Testing

Run:

```powershell
.\build.ps1 -Install
```

This builds the C# ManiaScript project, generates the ManiaScript, creates the separate `Generated/FriendsRecords.as` wrapper and builds the final `.op` file under `build`.

Then copies into the users plugins folder for openplanet to pick up

```
%USERPROFILE%\OpenplanetNext\Plugins\RecordsPlusPlus
```

There are debug settings in the plugin if need to see what it is doing.

## To do

- Selecting friend doesnt show ghost yet
- Allow to manually add other friends/filter out who want to see if have multiple friends
