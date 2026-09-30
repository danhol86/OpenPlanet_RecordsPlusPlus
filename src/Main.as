const string PluginName = "Friends Ghost Leaderboard";

[Setting hidden]
bool S_ShowWindow = true;

[Setting category="General" name="Auto refresh friend times"]
bool S_AutoRefresh = true;

[Setting category="General" name="Refresh interval (seconds)" min=10 max=300]
uint S_RefreshSeconds = 30;

[Setting category="General" name="Auto-load fastest friend ghosts"]
bool S_AutoLoadGhosts = false;

[Setting category="General" name="Maximum auto-loaded ghosts" min=0 max=20]
uint S_MaxAutoLoadedGhosts = 3;

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

array<FriendEntry@> g_Friends;
string g_MapUid = "";
uint g_MapGeneration = 0;
bool g_Refreshing = false;
bool g_FriendsLoaded = false;
bool g_RefreshRequested = false;
uint g_LastRefreshMs = 0;
string g_Status = "Open a map to load friend times.";

void Main() {
    trace(PluginName + " loaded");
    startnew(WatchMapLoop);
}

void RenderMenu() {
    if (UI::MenuItem("Friends Ghost Leaderboard", "", S_ShowWindow)) {
        S_ShowWindow = !S_ShowWindow;
    }
}

void RenderInterface() {
    if (!S_ShowWindow) return;
    if (GetCurrentMapUid().Length == 0) return;

    if (!UI::Begin("Friends Ghost Leaderboard")) {
        UI::End();
        return;
    }

    auto map = GetApp().RootMap;
    if (map !is null) {
        UI::Text("Map: " + string(map.MapInfo.Name));
    }

    UI::SameLine();
    UI::BeginDisabled(g_Refreshing);
    if (UI::Button(g_Refreshing ? "Refreshing..." : "Refresh now")) {
        startnew(RefreshAll);
    }
    UI::EndDisabled();

    if (g_LastRefreshMs > 0) {
        UI::SameLine();
        UI::Text("Updated " + ((Time::Now - g_LastRefreshMs) / 1000) + "s ago");
    }

    UI::Text(g_Status);

    if (!Permissions::PlayRecords()) {
        UI::Text("Ghost/replay actions require Trackmania record/ghost access.");
    }

    UI::Separator();

    uint withTimes = CountFriendsWithTimes();
    UI::Text("Friends: " + g_Friends.Length + " | Times on this map: " + withTimes);

    if (UI::BeginTable("##friends-live-table", 6)) {
        UI::TableNextRow();
        UI::TableNextColumn(); UI::Text("#");
        UI::TableNextColumn(); UI::Text("Friend");
        UI::TableNextColumn(); UI::Text("Time");
        UI::TableNextColumn(); UI::Text("Delta");
        UI::TableNextColumn(); UI::Text("Race");
        UI::TableNextColumn(); UI::Text("Replay");

        uint rank = 0;
        uint bestTime = GetBestFriendTime();
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
            UI::Text(f.TimeMs == bestTime ? "-" : "+" + FormatDelta(f.TimeMs - bestTime));

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
            uint refreshSeconds = S_RefreshSeconds < 10 ? 10 : S_RefreshSeconds;
            uint intervalMs = refreshSeconds * 1000;
            if (Time::Now - g_LastRefreshMs >= intervalMs) {
                startnew(RefreshRecordsOnly);
            }
        }
        sleep(500);
    }
}

void ResetMapState() {
    for (uint i = 0; i < g_Friends.Length; i++) {
        g_Friends[i].ResetRecord();
    }
    g_LastRefreshMs = 0;
    g_Status = g_MapUid.Length == 0 ? "Open a map to load friend times." : "Loading friends and current-map times...";
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
        SortFriends();
        g_LastRefreshMs = Time::Now;
        g_Status = "Live friend PBs loaded.";
        if (S_AutoLoadGhosts) AutoLoadFastestGhosts(generation);
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
        SortFriends();
        g_LastRefreshMs = Time::Now;
        g_Status = "Live friend PBs refreshed.";
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

void AutoLoadFastestGhosts(uint generation) {
    if (!Permissions::PlayRecords() || S_MaxAutoLoadedGhosts == 0) return;
    uint loaded = 0;
    for (uint i = 0; i < g_Friends.Length && loaded < S_MaxAutoLoadedGhosts; i++) {
        if (generation != g_MapGeneration) return;
        if (!g_Friends[i].HasRecord || g_Friends[i].GhostLoaded || g_Friends[i].ReplayUrl.Length == 0) continue;
        if (LoadGhost(g_Friends[i])) loaded++;
    }
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
