const string page = "RecordsPlusPlus_First";

array<FriendsTime@> friends;
string seenMap = "";

//used to check if already getting times as in a loop
bool gettingTimes = false;

//if loaded for current map, then dont load again
bool loadedOnce = false;

void Main() {
    Dbg("AS", "PLUGIN START");

    //all as files are auto added without needing to reference or inject. so calling script from here uses as in Generated folder 
    MLHook::InjectManialinkToPlayground(page, script, true);

    while (true) {
        auto app = GetApp();
        string map = "";

        //get current map
        if (app.RootMap !is null && app.RootMap.MapInfo !is null && Permissions::ViewRecords())
            map = app.RootMap.MapInfo.MapUid;

        //check if already loaded this map so dont create again. if different then reset view or remove it if out of any map
        if (map != seenMap) {
            seenMap = map;
            loadedOnce = false;
            friends.Resize(0);

            if (map.Length == 0) {
                MLHook::Queue_MessageManialinkPlayground(page, {"off"});
            } else {
                MLHook::Queue_MessageManialinkPlayground(page, {"reset"});
            }
        }

        if (map.Length > 0 && !gettingTimes && !loadedOnce) {
            gettingTimes = true;
            startnew(fetchfriends);
        }

        sleep(1000);
    }
}

void OnDisabled() { MLHook::UnregisterMLHooksAndRemoveInjectedML(); }
void OnDestroyed() { MLHook::UnregisterMLHooksAndRemoveInjectedML(); }
