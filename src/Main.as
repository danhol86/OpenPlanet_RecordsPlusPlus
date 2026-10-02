const MYScriptReplacement

const string page = "RecordsPlusPlus_First";

class FriendsTime {
    string id;
    string name;
    uint time;
    uint place;
}

array<FriendsTime@> friends;
string seenMap = "";

//used to check if already getting times as in a loop
bool gettingTimes = false;

//if loaded for current map, then dont load again
bool loadedOnce = false;

array<string> debugLines;

//settings for debugging only. is this ok in production?
[Setting category="Debug" name="Show Popup"]
bool ShowPopup = false;

[Setting category="Debug" name="Enable debugging"]
bool DebugEnabled = false;

//add logs to the trace (shown in logs tab in Openplanet) then also log seperately to show in new debug popup
void Dbg(const string &in source, const string &in message) {
    if (!DebugEnabled) return;

    string line =
        "[" + tostring(Time::Now) + "] [" + source + "] " + message;

    // Openplanet log
    trace(line);

    // log line to show in popup
    debugLines.InsertLast(line);
}

//create hook to allow for messages to be passerd from ml events so can log exceptions etc
class ScriptDebugHook : MLHook::HookMLEventsByType {
    ScriptDebugHook() {
        super("RecordsPlusPlus_Debug");
    }

    void OnEvent(MLHook::PendingEvent@ event) override {
        string msg = "";

        for (uint i = 0; i < event.data.Length; i++) {
            if (i > 0)
                msg += " | ";

            msg += string(event.data[i]);
        }

        Dbg("MANIASCRIPT", msg);
    }
}

//shows popup if debugging enabled and show is true
void Render() {

    if(!ShowPopup) {
        return;
    }

    UI::SetNextWindowSize(900, 550, UI::Cond::FirstUseEver);

    UI::Begin("Records++ Debugging");

    UI::Separator();

    uint start = debugLines.Length > 40
        ? debugLines.Length - 40
        : 0;

    for (uint i = start; i < debugLines.Length; i++)
        UI::TextWrapped(debugLines[i]);


    UI::End();
}


ScriptDebugHook@ scriptDebugHook;

void Main() {

    Dbg("AS", "PLUGIN START");

    //register debugger on ML
    @scriptDebugHook = ScriptDebugHook();
    MLHook::RegisterMLHook(
            scriptDebugHook,
            "RecordsPlusPlus_Debug",
            true
        );

    
    //script is being injected here from the cs project Generated folder
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

void fetchfriends() {

    //log the map. so if changes during fetch it stops and doesnt get confused
    string requestedMap = seenMap;

    auto game = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
    if (game is null || game.UserMgr is null || game.ScoreMgr is null || game.UserMgr.Users.Length == 0) {
        gettingTimes = false;
        return;
    }

    auto currentUser = game.UserMgr.Users[0];
    auto user = currentUser.Id;

    auto friendsJob = game.UserMgr.Friend_GetList(user);
    while (friendsJob.IsProcessing) yield();
    if (friendsJob.HasFailed || !friendsJob.HasSucceeded || requestedMap != seenMap) {
        game.UserMgr.TaskResult_Release(friendsJob.Id);
        gettingTimes = false;
        return;
    }
    array<FriendsTime@> list;

    auto myInfo = GetApp().LocalPlayerInfo;

    if (myInfo !is null) {
        Dbg("AS", "Loaded main user info: " + myInfo.WebServicesUserId);

        FriendsTime@ currentEntry = FriendsTime();

        currentEntry.id = myInfo.WebServicesUserId;
        currentEntry.name = myInfo.Name;

        list.InsertLast(currentEntry);
    }

    for (uint i = 0; i < friendsJob.FriendList.Length; i++) {
        auto friend = friendsJob.FriendList[i];

        if (friend is null) continue;

        string id = friend.WebServicesUserId;
        FriendsTime@ entry = FriendsTime();
        entry.id = id;
        entry.name = string(friend.DisplayName);
        if (entry.name.Length == 0) entry.name = id;
        list.InsertLast(entry);
    }
    game.UserMgr.TaskResult_Release(friendsJob.Id);

    for (uint first = 0; first < list.Length; first += 50) {

        //if map changed or not allowed to view records then stop
        if (requestedMap != seenMap || !Permissions::ViewRecords()) break;
        MwFastBuffer<wstring> ids;
        uint end = Math::Min(first + 50, list.Length);
        for (uint i = first; i < end; i++) ids.Add(list[i].id);
        auto job = game.ScoreMgr.Map_GetPlayerListRecordList(user, ids, requestedMap, "PersonalBest", "", "TimeAttack", "");
        while (job.IsProcessing) yield();
        if (job.HasSucceeded && !job.HasFailed) {
            for (uint r = 0; r < job.MapRecordList.Length; r++) {
                auto record = job.MapRecordList[r];
                if (record is null || record.Time == 0 || record.Time == uint(-1)) continue;
                for (uint i = first; i < end; i++) {
                    if (list[i].id == record.WebServicesUserId || list[i].id == record.AccountId)
                        list[i].time = record.Time;
                }
            }
        }
        game.ScoreMgr.TaskResult_Release(job.Id);
    }

    //if map changed or not allowed to view records then stop
    if (requestedMap != seenMap || !Permissions::ViewRecords()) {
        gettingTimes = false;
        return;
    }

    for (uint i = 0; i < list.Length; i++) {
        if (list[i].time == 0) continue;

        //this now uses own api to get actual world place for friends/own time
        list[i].place = getWorldPlace(requestedMap, list[i].time);


        Dbg("AS", "Place for time " + list[i].name + " place " + list[i].place);

        Dbg("AS", "friend row " + list[i].name + " time " + list[i].time + " world " + list[i].place);

        //if map changed or not allowed to view records then stop
        if (requestedMap != seenMap || !Permissions::ViewRecords()) {
            gettingTimes = false;
            return;
        }
    }

    //now temp list updated, set to actual friends so shows
    friends = list;

    //reorder friends based on their time so shows in order
    for (uint i = 0; i < friends.Length; i++) {
        for (uint j = i + 1; j < friends.Length; j++) {
            if (friends[j].time > 0 && (friends[i].time == 0 || friends[j].time < friends[i].time)) {
                FriendsTime@ swap = friends[i];
                @friends[i] = friends[j];
                @friends[j] = swap;
            }
        }
    }

    //now call the manialink hook to reset before sending each row
    MLHook::Queue_MessageManialinkPlayground(page, {"reset"});

    //loop through each row and send message to manialink to add self and friends
    for (uint i = 0; i < friends.Length; i++) {
        if (friends[i].time == 0) continue;
        MLHook::Queue_MessageManialinkPlayground(page, {"row", friends[i].id, friends[i].name, tostring(friends[i].place), tostring(friends[i].time)});
    }
    gettingTimes = false;
    loadedOnce = true;
}

//use map id and score to get the place in world. set up own server as wouldnt work with my credneitlas.
//used this project - https://github.com/Banalian/ExtraLeaderboardAPI
uint getWorldPlace(string map, uint score) {
    string url = "https://extraleaderboardapi.agileapps.uk/ELP/api/leaderboard/map/" + map + "/time?time=" + tostring(score);

    Dbg("AS", "WORLD REQUEST score=" + tostring(score) + " url=" + url);

    auto request = Net::HttpRequest();

    request.Url = url;
    request.Method = Net::HttpMethod::Get;
    request.Start();

    while (!request.Finished())
        yield();

    if (map != seenMap)
        return 0;

    Dbg("AS", "WORLD RESPONSE data=" + request.String());

    if (request.ResponseCode() != 200)
        return 0;

    auto data = Json::Parse(request.String());

    if (data is null)
        return 0;

    auto positions = data["positions"];

    if (positions is null || positions.Length == 0)
        return 0;

    return uint(int(positions[0]["rank"]));
}

void OnDisabled() { MLHook::UnregisterMLHooksAndRemoveInjectedML(); }
void OnDestroyed() { MLHook::UnregisterMLHooksAndRemoveInjectedML(); }
