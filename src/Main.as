const string page = "RecordsPlusPlus_First";

class BuddyTime {
    string id;
    string name;
    uint time;
    uint place;
}

array<BuddyTime@> buddies;
string seenMap = "";
bool gettingTimes = false;
bool loadedOnce = false;

const string script = """
 #Include "TextLib" as T
 #Struct K_TMGame_Record_Record { Integer Rank; Text AccountId; Text DisplayName; Integer Score; }
 #Struct K_TMGame_Record_Records { Text ZoneName; Integer WorstScore; Boolean IsFull; Integer Type; K_TMGame_Record_Record[] Records; }

main() {
    declare K_TMGame_Record_Records[] TMGame_Record_ZonesRecords for ClientUI;
    declare Integer TMGame_Record_ZonesRecordsUpdate for ClientUI;
    declare Text[][] MLHook_Inbound_RecordsPlusPlus_First for ClientUI = [];
    declare K_TMGame_Record_Record[] people;
    declare Boolean enabled = False;
    declare Boolean changed = False;
    declare Integer lastUpdate = -1;
    while (True) {
        yield;
        declare Integer x = 0;
        x = 0;
        while (x < MLHook_Inbound_RecordsPlusPlus_First.count) {
            declare Text[] msg;
            msg = MLHook_Inbound_RecordsPlusPlus_First[x];
            if (msg.count > 0) {
                if (msg[0] == "reset") {
                    people = [];
                    enabled = True;
                    changed = True;
                }
                if (msg[0] == "row" && msg.count == 5) {
                    people.add(K_TMGame_Record_Record {
                        Rank = T::ToInteger(msg[3]),
                        AccountId = msg[1],
                        DisplayName = msg[2],
                        Score = T::ToInteger(msg[4])
                    });
                    changed = True;
                }
                if (msg[0] == "off") {
                    enabled = False;
                    people = [];
                    changed = True;
                }
            }
            x += 1;
        }
        MLHook_Inbound_RecordsPlusPlus_First = [];
        declare Integer found = -1;
        found = -1;
        x = 0;
        while (x < TMGame_Record_ZonesRecords.count) {
            if (TMGame_Record_ZonesRecords[x].ZoneName == "FRIENDS") found = x;
            x += 1;
        }
        if (enabled && TMGame_Record_ZonesRecords.count > 0 && (changed || found < 0 || lastUpdate != TMGame_Record_ZonesRecordsUpdate)) {
            declare Integer worst = 0;
            worst = 0;
            x = 0;
            while (x < people.count) {
                if (people[x].Score > worst) worst = people[x].Score;
                x += 1;
            }
            declare K_TMGame_Record_Records friends;
            friends = K_TMGame_Record_Records {
                ZoneName = "FRIENDS", WorstScore = worst, IsFull = True, Type = 1, Records = people
            };
            if (found >= 0) {
                TMGame_Record_ZonesRecords[found] = friends;
            } else {
                declare K_TMGame_Record_Records[] zones;
                zones = [];
                zones.add(TMGame_Record_ZonesRecords[0]);
                zones.add(friends);
                x = 1;
                while (x < TMGame_Record_ZonesRecords.count) {
                    zones.add(TMGame_Record_ZonesRecords[x]);
                    x += 1;
                }
                TMGame_Record_ZonesRecords = zones;
            }
            TMGame_Record_ZonesRecordsUpdate += 1;
            changed = False;
        }
        if (!enabled && found >= 0) {
            TMGame_Record_ZonesRecords.removekey(found);
            TMGame_Record_ZonesRecordsUpdate += 1;
            changed = False;
        }
        lastUpdate = TMGame_Record_ZonesRecordsUpdate;
    }
}
""";

void Main() {
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
            buddies.Resize(0);
            if (map.Length == 0) MLHook::Queue_MessageManialinkPlayground(page, {"off"});
            else MLHook::Queue_MessageManialinkPlayground(page, {"reset"});
        }
        if (map.Length > 0 && !gettingTimes && !loadedOnce) {
            gettingTimes = true;
            startnew(fetchBuddies);
        }
        sleep(1000);
    }
}

void fetchBuddies() {
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
    array<BuddyTime@> list;
    for (uint i = 0; i < friendsJob.FriendList.Length; i++) {
        auto friend = friendsJob.FriendList[i];
        if (friend is null) continue;
        string id = friend.WebServicesUserId;
        if (id.Length == 0) id = friend.AccountId;
        if (id.Length == 0) continue;
        BuddyTime@ entry = BuddyTime();
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
    buddies = list;
    for (uint i = 0; i < buddies.Length; i++) {
        for (uint j = i + 1; j < buddies.Length; j++) {
            if (buddies[j].time > 0 && (buddies[i].time == 0 || buddies[j].time < buddies[i].time)) {
                BuddyTime@ swap = buddies[i];
                @buddies[i] = buddies[j];
                @buddies[j] = swap;
            }
        }
    }
    MLHook::Queue_MessageManialinkPlayground(page, {"reset"});
    for (uint i = 0; i < buddies.Length; i++) {
        if (buddies[i].time == 0) continue;
        MLHook::Queue_MessageManialinkPlayground(page, {"row", buddies[i].id, buddies[i].name, tostring(buddies[i].place), tostring(buddies[i].time)});
    }
    gettingTimes = false;
    loadedOnce = true;
    trace("friends shown " + buddies.Length);
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
