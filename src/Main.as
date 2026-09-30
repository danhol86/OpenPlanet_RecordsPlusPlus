const string PluginName = "Friends Ghost Leaderboard";
const string NativeRecordsPageUid = "FriendsNativeRecords";

const string NativeRecordsManialink = """
 #Struct K_TMGame_Record_Record { Integer Rank; Text AccountId; Text DisplayName; Integer Score; }
 #Struct K_TMGame_Record_Records { Text ZoneName; Integer WorstScore; Boolean IsFull; Integer Type; K_TMGame_Record_Record[] Records; }

Integer FriendsLeaderboard_Digit(Text _Digit) {
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
    declare Text[][] MLHook_Inbound_FriendsNativeRecords for ClientUI = [];

    declare K_TMGame_Record_Record[] FriendsRecords;
    declare Boolean FriendsEnabled = False;
    declare Boolean Dirty = False;
    declare Integer LastSharedUpdate = -987654;

    while (True) {
        yield;

        foreach (Event in MLHook_Inbound_FriendsNativeRecords) {
            if (Event.count <= 0) continue;

            if (Event[0] == "Reset") {
                FriendsRecords = [];
                FriendsEnabled = True;
                Dirty = True;
            } else if (Event[0] == "Add" && Event.count >= 6) {
                declare Integer Rank = 0;
                declare Integer Score = 0;
                declare Boolean ReadingScore = False;
                for (I, 3, Event.count - 1) {
                    if (Event[I] == "|") {
                        ReadingScore = True;
                    } else if (ReadingScore) {
                        Score = Score * 10 + FriendsLeaderboard_Digit(Event[I]);
                    } else {
                        Rank = Rank * 10 + FriendsLeaderboard_Digit(Event[I]);
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
        MLHook_Inbound_FriendsNativeRecords = [];

        declare Integer FriendsZoneIx = -1;
        foreach (Ix => Zone in TMGame_Record_ZonesRecords) {
            if (Zone.ZoneName == "FRIENDS") {
                FriendsZoneIx = Ix;
                break;
            }
        }

        // Nadeo periodically rebuilds the shared records array. Re-apply our
        // zone whenever that happens, as well as whenever friend data changes.
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

            // Keep FRIENDS directly after WORLD (the first native zone), so it
            // is only one native Records arrow press away from the default view.
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

[Setting hidden]
bool S_ShowLegacyWindow = false;

[Setting category="General" name="Auto refresh friend times"]
bool S_AutoRefresh = true;

[Setting category="General" name="Refresh interval (seconds)" min=5 max=300]
uint S_RefreshSeconds = 10;

class FriendEntry {
    string AccountId;
    string WsId;
    string Name;
    string Presence;
    string Relationship;

    bool HasRecord = false;
    uint TimeMs = 0;
    uint RecordTimestamp = 0;
    wstring FileName;
    string ReplayUrl;

    bool GhostLoaded = false;
    bool GhostBusy = false;
    MwId GhostInstanceId;
    string ErrorText;

    FriendEntry(const string &in accountId, const string &in wsId, const string &in name,
                const string &in presence, const string &in relationship) {
        AccountId = accountId;
        WsId = wsId;
        Name = name;
        Presence = presence;
        Relationship = relationship;
    }

    void ResetRecord() {
        HasRecord = false;
        TimeMs = 0;
        RecordTimestamp = 0;
        FileName = "";
        ReplayUrl = "";
        GhostLoaded = false;
        GhostBusy = false;
        ErrorText = "";
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
uint g_LastRefreshMs = 0;
int64 g_LastRefreshStamp = 0;
uint g_PlayerPBTime = 0;
int g_LastUISequence = -1;
string g_Status = "Open a map to load friend times.";

void Main() {
    trace(PluginName + " loaded");
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

void RenderMenu() {
}

void RenderInterface() {
    if (!S_ShowLegacyWindow) return;
    if (GetCurrentMapUid().Length == 0) return;

    if (!UI::Begin("Friends Ghost Leaderboard")) {
        UI::End();
        return;
    }

    auto map = GetApp().RootMap;
    if (map !is null) UI::Text(string(map.MapInfo.Name));

    if (g_PlayerPBTime > 0) {
        uint rank = GetPlayerRankAmongFriends();
        uint fieldSize = CountFriendsWithTimes() + 1;
        UI::PushStyleColor(UI::Col::Text, vec4(0.35, 0.85, 1.0, 1.0));
        UI::Text("YOUR PB  " + FormatTime(g_PlayerPBTime) + "   |   #" + rank + " of " + fieldSize);
        UI::PopStyleColor();
    } else {
        UI::Text("YOUR PB  --:--.---");
    }

    UI::BeginDisabled(g_Refreshing);
    if (UI::Button(g_Refreshing ? "Refreshing..." : "Refresh")) {
        startnew(RefreshAll);
    }
    UI::EndDisabled();

    if (g_LastRefreshStamp > 0) {
        UI::SameLine();
        UI::Text("Last updated " + Time::FormatString("%H:%M:%S", g_LastRefreshStamp));
    }

    if (g_Status.Length > 0) UI::Text(g_Status);

    if (!Permissions::PlayRecords()) {
        UI::Text("Ghost/replay actions require Trackmania record/ghost access.");
    }

    UI::Separator();

    uint withTimes = CountFriendsWithTimes();
    UI::Text("FRIENDS  " + withTimes + " with a time");

    if (UI::BeginTable("##friends-live-table", 6)) {
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 28.0);
        UI::TableSetupColumn("Friend", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("PB", UI::TableColumnFlags::WidthFixed, 82.0);
        UI::TableSetupColumn("vs you", UI::TableColumnFlags::WidthFixed, 118.0);
        UI::TableSetupColumn("Race", UI::TableColumnFlags::WidthFixed, 70.0);
        UI::TableSetupColumn("Replay", UI::TableColumnFlags::WidthFixed, 70.0);
        UI::TableHeadersRow();

        uint rank = 0;
        for (uint i = 0; i < g_Friends.Length; i++) {
            FriendEntry@ f = g_Friends[i];
            if (!f.HasRecord) continue;
            rank++;

            UI::PushID(f.WsId.Length > 0 ? f.WsId : f.AccountId);
            UI::TableNextRow();

            UI::TableNextColumn();
            UI::Text("" + rank);

            UI::TableNextColumn();
            UI::Text(f.Name);

            UI::TableNextColumn();
            UI::Text(FormatTime(f.TimeMs));

            UI::TableNextColumn();
            DrawPBComparison(f.TimeMs);

            UI::TableNextColumn();
            UI::BeginDisabled(!Permissions::PlayRecords() || f.GhostBusy || f.ReplayUrl.Length == 0);
            string raceLabel = f.GhostBusy ? "Loading..." : (f.GhostLoaded ? "Remove" : "Race");
            if (UI::Button(raceLabel)) {
                if (f.GhostLoaded) {
                    UnloadGhost(f);
                } else {
                    startnew(CoroutineFuncUserdata(ToggleGhostCoro), f);
                }
            }
            UI::EndDisabled();

            UI::TableNextColumn();
            UI::BeginDisabled(!Permissions::PlayRecords() || f.GhostBusy || f.ReplayUrl.Length == 0);
            if (UI::Button("Watch")) {
                startnew(CoroutineFuncUserdata(WatchReplayCoro), f);
            }
            UI::EndDisabled();

            UI::PopID();
        }

        UI::EndTable();
    }

    if (withTimes == 0 && !g_Refreshing) {
        UI::Text("None of your loaded friends has a PB on this map yet.");
    }

    if (g_Friends.Length > withTimes) {
        UI::Separator();
        if (UI::TreeNode("Friends without a time (" + (g_Friends.Length - withTimes) + ")")) {
            for (uint i = 0; i < g_Friends.Length; i++) {
                if (!g_Friends[i].HasRecord) UI::Text(g_Friends[i].Name);
            }
            UI::TreePop();
        }
    }

    UI::End();
}

void WatchMapLoop() {
    while (true) {
        string uid = GetCurrentMapUid();
        if (uid != g_MapUid) {
            g_MapUid = uid;
            g_MapGeneration++;
            ResetMapState();
            g_RefreshRequested = uid.Length > 0;
        } else if (uid.Length > 0 && g_RefreshRequested && !g_Refreshing) {
            g_RefreshRequested = false;
            startnew(RefreshAll);
        } else if (uid.Length > 0 && S_AutoRefresh && !g_Refreshing && g_LastRefreshMs > 0) {
            uint refreshSeconds = S_RefreshSeconds < 5 ? 5 : S_RefreshSeconds;
            uint intervalMs = refreshSeconds * 1000;
            if (Time::Now - g_LastRefreshMs >= intervalMs) {
                startnew(RefreshRecordsOnly);
            }
        }

        if (uid.Length > 0) {
            uint currentPB = GetPlayerPBTime();
            if (currentPB > 0) g_PlayerPBTime = currentPB;
            DetectFinishedRun();
        }
        sleep(250);
    }
}

void ResetMapState() {
    for (uint i = 0; i < g_Friends.Length; i++) {
        g_Friends[i].ResetRecord();
    }
    g_LastRefreshMs = 0;
    g_LastRefreshStamp = 0;
    g_PlayerPBTime = 0;
    g_LastUISequence = -1;
    g_Status = g_MapUid.Length == 0 ? "Open a map to load friend times." : "Loading friends and current-map times...";
    if (g_MapUid.Length > 0) SyncNativeFriendsZone();
}

void RefreshAll() {
    if (g_Refreshing || g_MapUid.Length == 0) return;
    g_Refreshing = true;
    uint generation = g_MapGeneration;
    string uid = g_MapUid;
    g_Status = "Loading Ubisoft friends...";

    bool friendsOk = LoadFriendList(generation);
    if (!friendsOk || generation != g_MapGeneration || uid != g_MapUid) {
        g_Refreshing = false;
        return;
    }

    LoadRecordsForCurrentFriends(uid, generation);
    if (generation == g_MapGeneration && uid == g_MapUid) {
        g_PlayerPBTime = GetPlayerPBTime();
        SortFriends();
        g_LastRefreshMs = Time::Now;
        g_LastRefreshStamp = Time::Stamp;
        g_Status = "";
        SyncNativeFriendsZone();
    }
    g_Refreshing = false;
}

void RefreshRecordsOnly() {
    if (g_Refreshing || g_MapUid.Length == 0) return;
    if (!g_FriendsLoaded || g_Friends.Length == 0) {
        RefreshAll();
        return;
    }

    g_Refreshing = true;
    uint generation = g_MapGeneration;
    string uid = g_MapUid;
    g_Status = "Refreshing friend PBs...";

    for (uint i = 0; i < g_Friends.Length; i++) {
        bool wasLoaded = g_Friends[i].GhostLoaded;
        MwId oldInstance = g_Friends[i].GhostInstanceId;
        g_Friends[i].HasRecord = false;
        g_Friends[i].TimeMs = 0;
        g_Friends[i].RecordTimestamp = 0;
        g_Friends[i].FileName = "";
        g_Friends[i].ReplayUrl = "";
        g_Friends[i].ErrorText = "";
        g_Friends[i].GhostLoaded = wasLoaded;
        g_Friends[i].GhostInstanceId = oldInstance;
    }

    LoadRecordsForCurrentFriends(uid, generation);
    if (generation == g_MapGeneration && uid == g_MapUid) {
        g_PlayerPBTime = GetPlayerPBTime();
        SortFriends();
        g_LastRefreshMs = Time::Now;
        g_LastRefreshStamp = Time::Stamp;
        g_Status = "";
        SyncNativeFriendsZone();
    }
    g_Refreshing = false;
}

bool LoadFriendList(uint generation) {
    CSmArenaRulesMode@ ps = GetRulesMode();
    if (ps is null || ps.UserMgr is null || ps.UserMgr.Users.Length == 0) {
        g_Status = "Trackmania user services are not available in this mode.";
        return false;
    }

    auto userMgr = ps.UserMgr;
    auto task = userMgr.Friend_GetList(userMgr.Users[0].Id);
    bool cancelled = false;
    while (task.IsProcessing) {
        if (generation != g_MapGeneration) cancelled = true;
        yield();
    }
    if (cancelled) {
        userMgr.TaskResult_Release(task.Id);
        return false;
    }

    if (task.HasFailed || !task.HasSucceeded) {
        g_Status = "Could not load Ubisoft friends: " + task.ErrorDescription;
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
        FriendEntry@ next = FriendEntry(fr.AccountId, wsid, name, fr.Presence, fr.Relationship);
        FriendEntry@ previous = FindFriendByWsId(wsid);
        if (previous !is null) {
            next.GhostLoaded = previous.GhostLoaded;
            next.GhostBusy = previous.GhostBusy;
            next.GhostInstanceId = previous.GhostInstanceId;
        }
        nextFriends.InsertLast(next);
    }

    userMgr.TaskResult_Release(task.Id);
    if (generation != g_MapGeneration) return false;

    g_Friends = nextFriends;
    g_FriendsLoaded = true;
    g_Status = "Loaded " + g_Friends.Length + " friends. Loading current-map PBs...";
    return true;
}

void LoadRecordsForCurrentFriends(const string &in mapUid, uint generation) {
    if (g_Friends.Length == 0) return;

    CSmArenaRulesMode@ ps = GetRulesMode();
    if (ps is null || ps.ScoreMgr is null || ps.UserMgr is null || ps.UserMgr.Users.Length == 0) {
        g_Status = "Score services are not available in this mode.";
        return;
    }

    const uint BatchSize = 50;
    for (uint start = 0; start < g_Friends.Length; start += BatchSize) {
        if (generation != g_MapGeneration || mapUid != g_MapUid) return;

        MwFastBuffer<wstring> ids;
        uint end = Math::Min(start + BatchSize, g_Friends.Length);
        for (uint i = start; i < end; i++) {
            ids.Add(g_Friends[i].WsId);
        }

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
            if (generation != g_MapGeneration) cancelled = true;
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
                if (f is null) continue;

                f.HasRecord = true;
                f.TimeMs = rec.Time;
                f.RecordTimestamp = rec.Timestamp;
                f.FileName = rec.FileName;
                f.ReplayUrl = rec.ReplayUrl;
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

FriendEntry@ FindFriendByWsId(const string &in wsid) {
    for (uint i = 0; i < g_Friends.Length; i++) {
        if (g_Friends[i].WsId == wsid || (g_Friends[i].AccountId.Length > 0 && g_Friends[i].AccountId == wsid)) {
            return g_Friends[i];
        }
    }
    return null;
}

void SortFriends() {
    for (uint i = 0; i < g_Friends.Length; i++) {
        for (uint j = i + 1; j < g_Friends.Length; j++) {
            if (FriendComesBefore(g_Friends[j], g_Friends[i])) {
                FriendEntry@ temp = g_Friends[i];
                @g_Friends[i] = g_Friends[j];
                @g_Friends[j] = temp;
            }
        }
    }
}

bool FriendComesBefore(FriendEntry@ a, FriendEntry@ b) {
    if (a.HasRecord != b.HasRecord) return a.HasRecord;
    if (a.HasRecord && b.HasRecord && a.TimeMs != b.TimeMs) return a.TimeMs < b.TimeMs;
    return a.Name.ToLower() < b.Name.ToLower();
}

void ToggleGhostCoro(ref@ userdata) {
    FriendEntry@ f = cast<FriendEntry>(userdata);
    if (f is null || f.GhostLoaded) return;
    LoadGhost(f);
}

void WatchReplayCoro(ref@ userdata) {
    FriendEntry@ f = cast<FriendEntry>(userdata);
    if (f is null) return;

    if (!f.GhostLoaded) {
        if (!LoadGhost(f)) return;
        sleep(100);
    }

    if (f.WsId.Length == 0) return;
    trace("Watching friend replay: " + f.Name + " (" + FormatTime(f.TimeMs) + ")");
    MLHook::Queue_SH_SendCustomEvent("TMGame_Record_SpectateGhost", {f.WsId});

    sleep(350);
    CSmArenaRulesMode@ ps = GetRulesMode();
    bool spectating = ps !is null && ps.UIManager !is null && ps.UIManager.UIAll.ForceSpectator;
    if (!spectating) {
        // Ghosts++ uses the newer playground event on current Trackmania builds.
        // Keep the Any Ghost event above for compatibility, then fall back here.
        MLHook::Queue_PG_SendCustomEvent("TMGame_Record_Spectate", {f.WsId});
        sleep(350);
        @ps = GetRulesMode();
        spectating = ps !is null && ps.UIManager !is null && ps.UIManager.UIAll.ForceSpectator;
    }

    trace("Friend replay spectator state: " + tostring(spectating));
    if (spectating) {
        g_Status = "Watching " + f.Name + " replay.";
    } else {
        g_Status = "Replay requested for " + f.Name + ".";
    }
}

bool LoadGhost(FriendEntry@ f) {
    if (f is null || f.GhostBusy || f.ReplayUrl.Length == 0 || !Permissions::PlayRecords()) return false;

    CSmArenaRulesMode@ ps = GetRulesMode();
    if (ps is null || ps.DataFileMgr is null || ps.GhostMgr is null) return false;

    f.GhostBusy = true;
    f.ErrorText = "";
    string mapAtStart = g_MapUid;

    auto task = ps.DataFileMgr.Ghost_Download(f.FileName, f.ReplayUrl);
    bool cancelled = false;
    while (task.IsProcessing) {
        if (mapAtStart != g_MapUid) cancelled = true;
        yield();
    }
    if (cancelled) {
        ps.DataFileMgr.TaskResult_Release(task.Id);
        f.GhostBusy = false;
        return false;
    }

    if (task.HasFailed || !task.HasSucceeded || task.Ghost is null) {
        f.ErrorText = "Could not download ghost";
        warn("Ghost_Download failed for " + f.Name + ": " + task.ErrorDescription);
        ps.DataFileMgr.TaskResult_Release(task.Id);
        f.GhostBusy = false;
        return false;
    }

    f.GhostInstanceId = ps.GhostMgr.Ghost_Add(task.Ghost, true);
    f.GhostLoaded = true;
    f.GhostBusy = false;
    trace("Loaded friend ghost: " + f.Name + " (" + FormatTime(f.TimeMs) + ")");
    ps.DataFileMgr.TaskResult_Release(task.Id);
    return true;
}

void UnloadGhost(FriendEntry@ f) {
    if (f is null || !f.GhostLoaded) return;
    CSmArenaRulesMode@ ps = GetRulesMode();
    if (ps !is null && ps.GhostMgr !is null) {
        try {
            ps.GhostMgr.Ghost_Remove(f.GhostInstanceId);
        } catch {
            warn("Could not remove ghost for " + f.Name);
        }
    }
    f.GhostLoaded = false;
}

CSmArenaRulesMode@ GetRulesMode() {
    return cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
}

string GetCurrentMapUid() {
    auto map = GetApp().RootMap;
    if (map is null || map.MapInfo is null) return "";
    return map.MapInfo.MapUid;
}

uint CountFriendsWithTimes() {
    uint count = 0;
    for (uint i = 0; i < g_Friends.Length; i++) if (g_Friends[i].HasRecord) count++;
    return count;
}

uint GetBestFriendTime() {
    for (uint i = 0; i < g_Friends.Length; i++) {
        if (g_Friends[i].HasRecord) return g_Friends[i].TimeMs;
    }
    return 0;
}

uint GetPlayerPBTime() {
    CSmArenaRulesMode@ ps = GetRulesMode();
    auto map = GetApp().RootMap;
    if (ps is null || ps.ScoreMgr is null || ps.UserMgr is null || ps.UserMgr.Users.Length == 0 || map is null) return 0;
    return ps.ScoreMgr.Map_GetRecord_v2(ps.UserMgr.Users[0].Id, map.MapInfo.MapUid, "PersonalBest", "", "TimeAttack", "");
}

uint GetPlayerRankAmongFriends() {
    if (g_PlayerPBTime == 0) return 0;
    uint rank = 1;
    for (uint i = 0; i < g_Friends.Length; i++) {
        if (g_Friends[i].HasRecord && g_Friends[i].TimeMs < g_PlayerPBTime) rank++;
    }
    return rank;
}

void DrawPBComparison(uint friendTime) {
    if (g_PlayerPBTime == 0) {
        UI::Text("--");
        return;
    }

    int delta = int(g_PlayerPBTime) - int(friendTime);
    if (delta > 0) {
        UI::PushStyleColor(UI::Col::Text, vec4(1.0, 0.35, 0.35, 1.0));
        UI::Text("BEHIND +" + FormatDelta(uint(delta)));
        UI::PopStyleColor();
    } else if (delta < 0) {
        UI::PushStyleColor(UI::Col::Text, vec4(0.3, 0.95, 0.45, 1.0));
        UI::Text("AHEAD " + FormatDelta(uint(-delta)));
        UI::PopStyleColor();
    } else {
        UI::Text("EVEN");
    }
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
    // The local PB updates immediately; give the online record a moment to settle.
    sleep(900);
    uint pb = GetPlayerPBTime();
    if (pb > 0) g_PlayerPBTime = pb;
    if (!g_Refreshing) RefreshRecordsOnly();
    else g_RefreshRequested = true;
}

void InitNativeRecordsIntegration() {
    MLHook::InjectManialinkToPlayground(NativeRecordsPageUid, NativeRecordsManialink, true);
    g_NativeRecordsInjected = true;

    // Give MLHook a moment to create the page when the plugin is hot-loaded in a map.
    sleep(500);
    if (GetCurrentMapUid().Length > 0) SyncNativeFriendsZone();
}

void DisableNativeFriendsZone() {
    if (!g_NativeRecordsInjected) return;
    auto app = GetApp();
    if (app.Network is null || app.Network.ClientManiaAppPlayground is null) return;
    MLHook::Queue_MessageManialinkPlayground(NativeRecordsPageUid, {"Disable"});
}

void SyncNativeFriendsZone() {
    if (!g_NativeRecordsInjected || GetCurrentMapUid().Length == 0) return;
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

string FormatTime(uint ms) {
    uint minutes = ms / 60000;
    uint seconds = (ms % 60000) / 1000;
    uint millis = ms % 1000;
    return tostring(minutes) + ":" + Text::Format("%02d", seconds) + "." + Text::Format("%03d", millis);
}

string FormatDelta(uint ms) {
    uint seconds = ms / 1000;
    uint millis = ms % 1000;
    if (seconds >= 60) {
        uint minutes = seconds / 60;
        seconds %= 60;
        return tostring(minutes) + ":" + Text::Format("%02d", seconds) + "." + Text::Format("%03d", millis);
    }
    return tostring(seconds) + "." + Text::Format("%03d", millis);
}
