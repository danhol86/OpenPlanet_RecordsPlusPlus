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

void Render() {

    if(!ShowPopup) {
        return;
    }

    UI::SetNextWindowSize(900, 550, UI::Cond::FirstUseEver);

    UI::Begin("Records++ Debug");

    UI::Text("Map: " + seenMap);
    UI::Text(
        "gettingTimes=" + tostring(gettingTimes)
        + " loadedOnce=" + tostring(loadedOnce)
        + " friends=" + tostring(friends.Length)
    );

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

    @scriptDebugHook = ScriptDebugHook();
    MLHook::RegisterMLHook(
            scriptDebugHook,
            "RecordsPlusPlus_Debug",
            true
        );

    NadeoServices::AddAudience("NadeoLiveServices");

    MLHook::InjectManialinkToPlayground(page, script, true);
    while (true) {
        auto app = GetApp();
        string map = "";
        if (app.RootMap !is null && app.RootMap.MapInfo !is null && Permissions::ViewRecords())
            map = app.RootMap.MapInfo.MapUid;
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
    string wanted = seenMap;
    trace("friends map " + wanted);
    auto game = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
    if (game is null || game.UserMgr is null || game.ScoreMgr is null || game.UserMgr.Users.Length == 0) {
        gettingTimes = false;
        return;
    }
    auto user = game.UserMgr.Users[0].Id;
    auto friendsJob = game.UserMgr.Friend_GetList(user);
    while (friendsJob.IsProcessing) yield();
    trace("friends request finished " + friendsJob.HasSucceeded + " count " + friendsJob.FriendList.Length);
    if (friendsJob.HasFailed || !friendsJob.HasSucceeded || wanted != seenMap) {
        game.UserMgr.TaskResult_Release(friendsJob.Id);
        gettingTimes = false;
        return;
    }
    array<FriendsTime@> list;
    for (uint i = 0; i < friendsJob.FriendList.Length; i++) {
        auto friend = friendsJob.FriendList[i];
        if (friend is null) continue;
        string id = friend.WebServicesUserId;
        if (id.Length == 0) id = friend.AccountId;
        if (id.Length == 0) continue;
        FriendsTime@ entry = FriendsTime();
        entry.id = id;
        entry.name = string(friend.DisplayName);
        if (entry.name.Length == 0) entry.name = id;
        list.InsertLast(entry);
    }
    game.UserMgr.TaskResult_Release(friendsJob.Id);
    trace("friend ids " + list.Length);

    for (uint first = 0; first < list.Length; first += 50) {
        if (wanted != seenMap || !Permissions::ViewRecords()) break;
        MwFastBuffer<wstring> ids;
        uint end = Math::Min(first + 50, list.Length);
        for (uint i = first; i < end; i++) ids.Add(list[i].id);
        auto job = game.ScoreMgr.Map_GetPlayerListRecordList(user, ids, wanted, "PersonalBest", "", "TimeAttack", "");
        while (job.IsProcessing) yield();
        trace("friend records " + job.HasSucceeded + " count " + job.MapRecordList.Length);
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
    if (wanted != seenMap || !Permissions::ViewRecords()) {
        gettingTimes = false;
        return;
    }

    for (uint i = 0; i < list.Length; i++) {
        if (list[i].time == 0) continue;
        list[i].place = getWorldPlace(wanted, list[i].time);
        trace("friend row " + list[i].name + " time " + list[i].time + " world " + list[i].place);
        if (wanted != seenMap || !Permissions::ViewRecords()) {
            gettingTimes = false;
            return;
        }
    }
    friends = list;
    for (uint i = 0; i < friends.Length; i++) {
        for (uint j = i + 1; j < friends.Length; j++) {
            if (friends[j].time > 0 && (friends[i].time == 0 || friends[j].time < friends[i].time)) {
                FriendsTime@ swap = friends[i];
                @friends[i] = friends[j];
                @friends[j] = swap;
            }
        }
    }
    MLHook::Queue_MessageManialinkPlayground(page, {"reset"});
    for (uint i = 0; i < friends.Length; i++) {
        if (friends[i].time == 0) continue;
        MLHook::Queue_MessageManialinkPlayground(page, {"row", friends[i].id, friends[i].name, tostring(friends[i].place), tostring(friends[i].time)});
    }
    gettingTimes = false;
    loadedOnce = true;
    trace("friends shown " + friends.Length);
}

uint getWorldPlace(string map, uint score) {
    uint64 started = Time::Now;
    while (!NadeoServices::IsAuthenticated("NadeoLiveServices")) {
        if (Time::Now - started > 10000 || map != seenMap) return 0;
        yield();
    }
    string url = NadeoServices::BaseURLLive() + "/api/token/leaderboard/group/map?scores[" + map + "]=" + score;
    string body = '{"maps":[{"mapUid":"' + map + '","groupUid":"Personal_Best"}]}';
    auto request = NadeoServices::Post("NadeoLiveServices", url, body);
    request.Start();
    while (!request.Finished()) yield();
    trace("world response " + request.ResponseCode() + " " + request.Error());
    if (request.ResponseCode() != 200) return 0;
    auto data = Json::Parse(request.String());
    if (data is null || data.Length == 0) return 0;
    auto zones = data[0]["zones"];
    if (zones is null) return 0;
    for (uint i = 0; i < zones.Length; i++) {
        if (string(zones[i]["zoneName"]) == "World")
            return uint(int(zones[i]["ranking"]["position"]));
    }
    return 0;
}

void OnDisabled() { MLHook::UnregisterMLHooksAndRemoveInjectedML(); }
void OnDestroyed() { MLHook::UnregisterMLHooksAndRemoveInjectedML(); }
