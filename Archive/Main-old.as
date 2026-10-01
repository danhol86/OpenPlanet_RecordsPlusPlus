const string PluginName = "Records++";
const string NativeRecordsPageUid = "RecordsPlusPlus_Friends";

// The native Records module stores its zones in ClientUI variables. This small
// ManiaLink companion adds a FRIENDS zone to that same data model, so Trackmania
// renders it with its own rows, navigation, ghost eye buttons and PB controls.
const string NativeRecordsManialink = """
 #Struct K_TMGame_Record_Record { Integer Rank; Text AccountId; Text DisplayName; Integer Score; }
 #Struct K_TMGame_Record_Records { Text ZoneName; Integer WorstScore; Boolean IsFull; Integer Type; K_TMGame_Record_Record[] Records; }

Integer RecordsPlusPlus_Digit(Text _Digit) {
    if (_Digit == "0") return 0;
    if (_Digit == "1") return 1;
    if (_Digit == "2") return 2;
    if (_Digit == "3") return 3;
    if (_Digit == "4") return 4;
    if (_Digit == "5") return 5;
    if (_Digit == "6") return 6;
    if (_Digit == "7") return 7;
    if (_Digit == "8") return 8;
    if (_Digit == "9") return 9;
    return 0;
}

main() {
    declare K_TMGame_Record_Records[] TMGame_Record_ZonesRecords for ClientUI;
    declare Integer TMGame_Record_ZonesRecordsUpdate for ClientUI;
    declare Text[][] MLHook_Inbound_RecordsPlusPlus_Friends for ClientUI = [];

    declare K_TMGame_Record_Record[] FriendsRecords;
    declare Boolean FriendsEnabled = False;
    declare Boolean Dirty = False;
    declare Integer LastSharedUpdate = -987654;

    while (True) {
        yield;

        foreach (Event in MLHook_Inbound_RecordsPlusPlus_Friends) {
            if (Event.count <= 0) continue;

            if (Event[0] == "Reset") {
                FriendsRecords = [];
                FriendsEnabled = True;
                Dirty = True;
            } else if (Event[0] == "Add" && Event.count >= 6) {
                declare Integer Rank = 0;
                declare Integer Score = 0;
                declare Boolean ReadingScore = False;

                // MLHook messages are text arrays. Rank and score are sent one
                // digit at a time to avoid depending on TextLib conversion.
                for (I, 3, Event.count - 1) {
                    if (Event[I] == "|") {
                        ReadingScore = True;
                    } else if (ReadingScore) {
                        Score = Score * 10 + RecordsPlusPlus_Digit(Event[I]);
                    } else {
                        Rank = Rank * 10 + RecordsPlusPlus_Digit(Event[I]);
                    }
                }

                declare K_TMGame_Record_Record Record = K_TMGame_Record_Record {
                    Rank = Rank,
                    AccountId = Event[1],
                    DisplayName = Event[2],
                    Score = Score
                };
                FriendsRecords.add(Record);
                Dirty = True;
            } else if (Event[0] == "Disable") {
                FriendsEnabled = False;
                Dirty = True;
            } else if (Event[0] == "Apply") {
                Dirty = True;
            }
        }
        MLHook_Inbound_RecordsPlusPlus_Friends = [];

        declare Integer FriendsZoneIx = -1;
        foreach (Ix => Zone in TMGame_Record_ZonesRecords) {
            if (Zone.ZoneName == "FRIENDS") {
                FriendsZoneIx = Ix;
                break;
            }
        }

        // Nadeo periodically rebuilds the native zone array. Re-apply FRIENDS
        // whenever that happens, and keep it directly after WORLD.
        if (FriendsEnabled && (Dirty || FriendsZoneIx < 0 || LastSharedUpdate != TMGame_Record_ZonesRecordsUpdate)) {
            declare Integer WorstScore = 0;
            foreach (Ix => Record in FriendsRecords) {
                if (Record.Score > WorstScore) WorstScore = Record.Score;
            }

            declare K_TMGame_Record_Records FriendsZone = K_TMGame_Record_Records {
                ZoneName = "FRIENDS",
                WorstScore = WorstScore,
                IsFull = True,
                Type = 1,
                Records = FriendsRecords
            };

            if (FriendsZoneIx == 1 || (FriendsZoneIx == 0 && TMGame_Record_ZonesRecords.count == 1)) {
                TMGame_Record_ZonesRecords[FriendsZoneIx] = FriendsZone;
            } else {
                if (FriendsZoneIx >= 0) TMGame_Record_ZonesRecords.removekey(FriendsZoneIx);

                declare K_TMGame_Record_Records[] ReorderedZones;
                if (TMGame_Record_ZonesRecords.count <= 0) {
                    ReorderedZones.add(FriendsZone);
                } else {
                    ReorderedZones.add(TMGame_Record_ZonesRecords[0]);
                    ReorderedZones.add(FriendsZone);
                    for (I, 1, TMGame_Record_ZonesRecords.count - 1) {
                        ReorderedZones.add(TMGame_Record_ZonesRecords[I]);
                    }
                }
                TMGame_Record_ZonesRecords = ReorderedZones;
            }

            TMGame_Record_ZonesRecordsUpdate += 1;
            LastSharedUpdate = TMGame_Record_ZonesRecordsUpdate;
            Dirty = False;
        } else if (!FriendsEnabled && FriendsZoneIx >= 0) {
            TMGame_Record_ZonesRecords.removekey(FriendsZoneIx);
            TMGame_Record_ZonesRecordsUpdate += 1;
            LastSharedUpdate = TMGame_Record_ZonesRecordsUpdate;
            Dirty = False;
        } else {
            LastSharedUpdate = TMGame_Record_ZonesRecordsUpdate;
        }
    }
}
""";

[Setting category="Friends" name="Auto refresh friend times"]
bool S_AutoRefresh = true;

[Setting category="Friends" name="Refresh interval (seconds)" min=15 max=300]
uint S_RefreshSeconds = 30;

class FriendEntry {
    string AccountId;
    string WsId;
    string Name;
    bool HasRecord = false;
    uint TimeMs = 0;

    FriendEntry(const string &in accountId, const string &in wsId, const string &in name) {
        AccountId = accountId;
        WsId = wsId;
        Name = name;
    }

    void ResetRecord() {
        HasRecord = false;
        TimeMs = 0;
    }
}

class NativeRecordRow {
    uint Rank;
    string WsId;
    string Name;
    uint TimeMs;
    bool IsLocal;

    NativeRecordRow(const string &in wsid, const string &in name, uint timeMs, bool isLocal) {
        WsId = wsid;
        Name = name;
        TimeMs = timeMs;
        IsLocal = isLocal;
    }
}

array<FriendEntry@> g_Friends;
string g_MapUid = "";
uint g_MapGeneration = 0;
bool g_Refreshing = false;
bool g_FriendsLoaded = false;
bool g_RefreshRequested = false;
bool g_NativeRecordsInjected = false;
bool g_LastCanViewRecords = false;
uint g_LastRefreshMs = 0;
uint g_PlayerPBTime = 0;
int g_LastUISequence = -1;

void Main() {
    trace(PluginName + " loaded");
    g_LastCanViewRecords = Permissions::ViewRecords();
    startnew(InitNativeRecordsIntegration);
    startnew(WatchMapLoop);
}

void OnDestroyed() {
    DisableNativeFriendsZone();
    MLHook::UnregisterMLHooksAndRemoveInjectedML();
}

void OnDisabled() {
    DisableNativeFriendsZone();
    MLHook::UnregisterMLHooksAndRemoveInjectedML();
}

void WatchMapLoop() {
    while (true) {
        bool canViewRecords = Permissions::ViewRecords();
        if (canViewRecords != g_LastCanViewRecords) {
            g_LastCanViewRecords = canViewRecords;
            if (canViewRecords && GetCurrentMapUid().Length > 0) {
                g_RefreshRequested = true;
            } else {
                DisableNativeFriendsZone();
            }
        }

        string uid = GetCurrentMapUid();
        if (uid != g_MapUid) {
            g_MapUid = uid;
            g_MapGeneration++;
            ResetMapState();
            g_RefreshRequested = canViewRecords && uid.Length > 0;
        } else if (canViewRecords && uid.Length > 0 && g_RefreshRequested && !g_Refreshing) {
            g_RefreshRequested = false;
            startnew(RefreshAll);
        } else if (canViewRecords && uid.Length > 0 && S_AutoRefresh && !g_Refreshing && g_LastRefreshMs > 0) {
            uint refreshSeconds = S_RefreshSeconds < 15 ? 15 : S_RefreshSeconds;
            if (Time::Now - g_LastRefreshMs >= refreshSeconds * 1000) {
                startnew(RefreshRecordsOnly);
            }
        }

        if (canViewRecords && uid.Length > 0) DetectFinishedRun();
        sleep(250);
    }
}

void ResetMapState() {
    for (uint i = 0; i < g_Friends.Length; i++) g_Friends[i].ResetRecord();
    g_LastRefreshMs = 0;
    g_PlayerPBTime = 0;
    g_LastUISequence = -1;

    if (Permissions::ViewRecords() && g_MapUid.Length > 0) SyncNativeFriendsZone();
    else DisableNativeFriendsZone();
}

void RefreshAll() {
    if (g_Refreshing || g_MapUid.Length == 0 || !Permissions::ViewRecords()) return;

    g_Refreshing = true;
    uint generation = g_MapGeneration;
    string uid = g_MapUid;

    bool friendsOk = LoadFriendList(generation);
    if (!friendsOk || generation != g_MapGeneration || uid != g_MapUid || !Permissions::ViewRecords()) {
        g_Refreshing = false;
        return;
    }

    LoadRecordsForCurrentFriends(uid, generation);
    if (generation == g_MapGeneration && uid == g_MapUid && Permissions::ViewRecords()) {
        g_PlayerPBTime = GetPlayerPBTime();
        g_LastRefreshMs = Time::Now;
        SyncNativeFriendsZone();
    }
    g_Refreshing = false;
}

void RefreshRecordsOnly() {
    if (g_Refreshing || g_MapUid.Length == 0 || !Permissions::ViewRecords()) return;
    if (!g_FriendsLoaded) {
        RefreshAll();
        return;
    }

    g_Refreshing = true;
    uint generation = g_MapGeneration;
    string uid = g_MapUid;

    for (uint i = 0; i < g_Friends.Length; i++) g_Friends[i].ResetRecord();

    LoadRecordsForCurrentFriends(uid, generation);
    if (generation == g_MapGeneration && uid == g_MapUid && Permissions::ViewRecords()) {
        g_PlayerPBTime = GetPlayerPBTime();
        g_LastRefreshMs = Time::Now;
        SyncNativeFriendsZone();
    }
    g_Refreshing = false;
}

bool LoadFriendList(uint generation) {
    CSmArenaRulesMode@ ps = GetRulesMode();
    if (ps is null || ps.UserMgr is null || ps.UserMgr.Users.Length == 0) return false;

    auto userMgr = ps.UserMgr;
    auto task = userMgr.Friend_GetList(userMgr.Users[0].Id);
    bool cancelled = false;
    while (task.IsProcessing) {
        if (generation != g_MapGeneration || !Permissions::ViewRecords()) cancelled = true;
        yield();
    }

    if (cancelled) {
        userMgr.TaskResult_Release(task.Id);
        return false;
    }

    if (task.HasFailed || !task.HasSucceeded) {
        warn("Friend_GetList failed: " + task.ErrorDescription);
        userMgr.TaskResult_Release(task.Id);
        return false;
    }

    array<FriendEntry@> nextFriends;
    for (uint i = 0; i < task.FriendList.Length; i++) {
        auto fr = task.FriendList[i];
        if (fr is null) continue;

        string wsid = fr.WebServicesUserId;
        if (wsid.Length == 0) wsid = fr.AccountId;
        if (wsid.Length == 0) continue;

        string name = string(fr.DisplayName);
        if (name.Length == 0) name = wsid;
        nextFriends.InsertLast(FriendEntry(fr.AccountId, wsid, name));
    }

    userMgr.TaskResult_Release(task.Id);
    if (generation != g_MapGeneration) return false;

    g_Friends = nextFriends;
    g_FriendsLoaded = true;
    return true;
}

void LoadRecordsForCurrentFriends(const string &in mapUid, uint generation) {
    if (g_Friends.Length == 0 || !Permissions::ViewRecords()) return;

    CSmArenaRulesMode@ ps = GetRulesMode();
    if (ps is null || ps.ScoreMgr is null || ps.UserMgr is null || ps.UserMgr.Users.Length == 0) return;

    // The API accepts explicit account IDs. Query friends in bounded batches;
    // this is deliberately not a full-leaderboard request.
    const uint BatchSize = 50;
    for (uint start = 0; start < g_Friends.Length; start += BatchSize) {
        if (generation != g_MapGeneration || mapUid != g_MapUid || !Permissions::ViewRecords()) return;

        MwFastBuffer<wstring> ids;
        uint end = Math::Min(start + BatchSize, g_Friends.Length);
        for (uint i = start; i < end; i++) ids.Add(g_Friends[i].WsId);

        auto task = ps.ScoreMgr.Map_GetPlayerListRecordList(
            ps.UserMgr.Users[0].Id,
            ids,
            mapUid,
            "PersonalBest",
            "",
            "TimeAttack",
            ""
        );

        bool cancelled = false;
        while (task.IsProcessing) {
            if (generation != g_MapGeneration || !Permissions::ViewRecords()) cancelled = true;
            yield();
        }

        if (cancelled) {
            ps.ScoreMgr.TaskResult_Release(task.Id);
            return;
        }

        if (!task.HasFailed && task.HasSucceeded) {
            for (uint r = 0; r < task.MapRecordList.Length; r++) {
                auto rec = task.MapRecordList[r];
                FriendEntry@ f = FindFriendForRecord(rec);
                if (f is null || rec.Time == 0) continue;
                f.HasRecord = true;
                f.TimeMs = rec.Time;
            }
        } else {
            warn("Map_GetPlayerListRecordList failed: " + task.ErrorDescription);
        }

        ps.ScoreMgr.TaskResult_Release(task.Id);
    }
}

FriendEntry@ FindFriendForRecord(CMapRecord@ rec) {
    if (rec is null) return null;
    for (uint i = 0; i < g_Friends.Length; i++) {
        if ((rec.WebServicesUserId.Length > 0 && g_Friends[i].WsId == rec.WebServicesUserId)
            || (rec.AccountId.Length > 0 && g_Friends[i].AccountId == rec.AccountId)
            || (rec.AccountId.Length > 0 && g_Friends[i].WsId == rec.AccountId)) {
            return g_Friends[i];
        }
    }
    return null;
}

CSmArenaRulesMode@ GetRulesMode() {
    return cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
}

string GetCurrentMapUid() {
    auto map = GetApp().RootMap;
    if (map is null || map.MapInfo is null) return "";
    return map.MapInfo.MapUid;
}

uint GetPlayerPBTime() {
    if (!Permissions::ViewRecords()) return 0;
    CSmArenaRulesMode@ ps = GetRulesMode();
    auto map = GetApp().RootMap;
    if (ps is null || ps.ScoreMgr is null || ps.UserMgr is null || ps.UserMgr.Users.Length == 0 || map is null) return 0;
    return ps.ScoreMgr.Map_GetRecord_v2(ps.UserMgr.Users[0].Id, map.MapInfo.MapUid, "PersonalBest", "", "TimeAttack", "");
}

void DetectFinishedRun() {
    CSmArenaRulesMode@ ps = GetRulesMode();
    if (ps is null || ps.UIManager is null || ps.UIManager.UIAll is null) return;

    int sequence = int(ps.UIManager.UIAll.UISequence);
    if (sequence == int(CGamePlaygroundUIConfig::EUISequence::Finish) && g_LastUISequence != sequence) {
        startnew(RefreshAfterFinishedRun);
    }
    g_LastUISequence = sequence;
}

void RefreshAfterFinishedRun() {
    // Give the online PB a short moment to settle after the finish event.
    sleep(900);
    if (!Permissions::ViewRecords()) return;
    if (!g_Refreshing) RefreshRecordsOnly();
    else g_RefreshRequested = true;
}

void InitNativeRecordsIntegration() {
    MLHook::InjectManialinkToPlayground(NativeRecordsPageUid, NativeRecordsManialink, true);
    g_NativeRecordsInjected = true;

    // Allow MLHook to create the page when the plugin is hot-loaded mid-map.
    sleep(500);
    if (Permissions::ViewRecords() && GetCurrentMapUid().Length > 0) SyncNativeFriendsZone();
}

void DisableNativeFriendsZone() {
    if (!g_NativeRecordsInjected) return;
    auto app = GetApp();
    if (app.Network is null || app.Network.ClientManiaAppPlayground is null) return;
    MLHook::Queue_MessageManialinkPlayground(NativeRecordsPageUid, {"Disable"});
}

void SyncNativeFriendsZone() {
    if (!g_NativeRecordsInjected || GetCurrentMapUid().Length == 0) return;
    if (!Permissions::ViewRecords()) {
        DisableNativeFriendsZone();
        return;
    }

    auto app = GetApp();
    if (app.Network is null || app.Network.ClientManiaAppPlayground is null) return;

    array<NativeRecordRow@> rows = BuildNativeRecordRows();
    MLHook::Queue_MessageManialinkPlayground(NativeRecordsPageUid, {"Reset"});

    for (uint i = 0; i < rows.Length; i++) {
        NativeRecordRow@ row = rows[i];
        array<string> message = {"Add", row.WsId, row.Name};
        AppendIntegerDigits(message, row.Rank);
        message.InsertLast("|");
        AppendIntegerDigits(message, row.TimeMs);
        MLHook::Queue_MessageManialinkPlayground(NativeRecordsPageUid, message);
    }

    MLHook::Queue_MessageManialinkPlayground(NativeRecordsPageUid, {"Apply"});
}

void AppendIntegerDigits(array<string> &inout message, uint value) {
    uint divisor = 1;
    while (value / divisor >= 10 && divisor <= 100000000) divisor *= 10;
    while (divisor > 0) {
        message.InsertLast(tostring((value / divisor) % 10));
        divisor /= 10;
    }
}

array<NativeRecordRow@> BuildNativeRecordRows() {
    array<NativeRecordRow@> allRows;

    for (uint i = 0; i < g_Friends.Length; i++) {
        FriendEntry@ f = g_Friends[i];
        if (!f.HasRecord || f.WsId.Length == 0 || f.TimeMs == 0) continue;
        allRows.InsertLast(NativeRecordRow(f.WsId, f.Name, f.TimeMs, false));
    }

    auto localPlayer = GetApp().LocalPlayerInfo;
    if (g_PlayerPBTime > 0 && localPlayer !is null) {
        string wsid = localPlayer.WebServicesUserId;
        string name = string(localPlayer.Name);
        if (wsid.Length > 0) allRows.InsertLast(NativeRecordRow(wsid, name, g_PlayerPBTime, true));
    }

    for (uint i = 0; i < allRows.Length; i++) {
        for (uint j = i + 1; j < allRows.Length; j++) {
            if (allRows[j].TimeMs < allRows[i].TimeMs
                || (allRows[j].TimeMs == allRows[i].TimeMs && allRows[j].Name.ToLower() < allRows[i].Name.ToLower())) {
                NativeRecordRow@ tmp = allRows[i];
                @allRows[i] = allRows[j];
                @allRows[j] = tmp;
            }
        }
    }

    for (uint i = 0; i < allRows.Length; i++) {
        if (i == 0 || allRows[i].TimeMs != allRows[i - 1].TimeMs) allRows[i].Rank = i + 1;
        else allRows[i].Rank = allRows[i - 1].Rank;
    }

    // The native Records panel shows a compact list. Match its normal layout:
    // top 5, then a small window around the local player when needed.
    if (allRows.Length <= 8) return allRows;

    array<NativeRecordRow@> shown;
    for (uint i = 0; i < 5; i++) shown.InsertLast(allRows[i]);

    int localIx = -1;
    for (uint i = 0; i < allRows.Length; i++) {
        if (allRows[i].IsLocal) {
            localIx = int(i);
            break;
        }
    }

    if (localIx < 5) {
        for (uint i = 5; i < 8; i++) shown.InsertLast(allRows[i]);
        return shown;
    }

    int start = localIx - 1;
    if (start < 5) start = 5;
    if (start + 3 > int(allRows.Length)) start = int(allRows.Length) - 3;
    for (int i = start; i < start + 3; i++) shown.InsertLast(allRows[i]);
    return shown;
}