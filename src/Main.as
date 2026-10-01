const string page = "RecordsPlusPlus_First";
bool freindsEnabled = false;
string didThisMap = "";
uint danTime = 0;

const string script = """
 #Include "TextLib" as T
 #Struct K_TMGame_Record_Record { Integer Rank; Text AccountId; Text DisplayName; Integer Score; }
 #Struct K_TMGame_Record_Records { Text ZoneName; Integer WorstScore; Boolean IsFull; Integer Type; K_TMGame_Record_Record[] Records; }

main() {
    declare K_TMGame_Record_Records[] TMGame_Record_ZonesRecords for ClientUI;
    declare Integer TMGame_Record_ZonesRecordsUpdate for ClientUI;
    declare Text[][] MLHook_Inbound_RecordsPlusPlus_First for ClientUI = [];
    declare Boolean enabled = False;
    declare Integer danScore = 0;
    declare Boolean updateIt = False;
    SendCustomEvent("MLHook_Event_RecordsPlusPlus_Check", ["ready"]);
    while (True) {
        yield;
        declare Integer messageNumber = 0;
        messageNumber = 0;
        while (messageNumber < MLHook_Inbound_RecordsPlusPlus_First.count) {
            if (MLHook_Inbound_RecordsPlusPlus_First[messageNumber].count > 0) {
                if (MLHook_Inbound_RecordsPlusPlus_First[messageNumber][0] == "on") {
                    enabled = True;
                    if (MLHook_Inbound_RecordsPlusPlus_First[messageNumber].count == 2) {
                        declare Integer incomingTime;
                        incomingTime = T::ToInteger(MLHook_Inbound_RecordsPlusPlus_First[messageNumber][1]);
                        if (incomingTime != danScore) {
                            danScore = incomingTime;
                            updateIt = True;
                        }
                    }
                } else {
                    enabled = False;
                }
            }
            messageNumber += 1;
        }
        MLHook_Inbound_RecordsPlusPlus_First = [];
        declare Integer found = -1;
        found = -1;
        declare Integer i = 0;
        i = 0;
        while (i < TMGame_Record_ZonesRecords.count) {
            if (TMGame_Record_ZonesRecords[i].ZoneName == "FRIENDS") {
                found = i;
            }
            i += 1;
        }
        if (enabled && (found < 0 || updateIt) && TMGame_Record_ZonesRecords.count > 0) {
            declare K_TMGame_Record_Record[] empty;
            empty = [];
            if (danScore > 0) {
                empty.add(K_TMGame_Record_Record {
                    Rank = 1,
                    AccountId = "44ad47cb-6d97-4a55-bcc3-768cf76acaf0",
                    DisplayName = "Daniel",
                    Score = danScore
                });
            }
            declare K_TMGame_Record_Records friends;
            friends = K_TMGame_Record_Records {
                ZoneName = "FRIENDS",
                WorstScore = danScore,
                IsFull = True,
                Type = 1,
                Records = empty
            };
            if (found >= 0) {
                TMGame_Record_ZonesRecords[found] = friends;
                TMGame_Record_ZonesRecordsUpdate += 1;
                updateIt = False;
                SendCustomEvent("MLHook_Event_RecordsPlusPlus_Check", ["pb", T::ToText(danScore), T::ToText(empty.count)]);
                continue;
            }
            declare K_TMGame_Record_Records[] zones;
            zones = [];
            zones.add(TMGame_Record_ZonesRecords[0]);
            zones.add(friends);
            i = 1;
            while (i < TMGame_Record_ZonesRecords.count) {
                zones.add(TMGame_Record_ZonesRecords[i]);
                i += 1;
            }
            TMGame_Record_ZonesRecords = zones;
            TMGame_Record_ZonesRecordsUpdate += 1;
            updateIt = False;
            SendCustomEvent("MLHook_Event_RecordsPlusPlus_Check", ["added", "1", T::ToText(zones.count), zones[0].ZoneName]);
            SendCustomEvent("MLHook_Event_RecordsPlusPlus_Check", ["pb", T::ToText(danScore), T::ToText(empty.count)]);
        }
        if (!enabled && found >= 0) {
            TMGame_Record_ZonesRecords.removekey(found);
            TMGame_Record_ZonesRecordsUpdate += 1;
            SendCustomEvent("MLHook_Event_RecordsPlusPlus_Check", ["removed"]);
        }
    }
}
""";

void Main() {
    MLHook::RegisterMLHook(MLHook::DebugLogAllHook("RecordsPlusPlus_Check"));
    MLHook::InjectManialinkToPlayground(page, script, true);
    trace("Records++ first part loaded");
    while (true) {
        auto app = GetApp();
        freindsEnabled = false;
        if (app.RootMap !is null) {
            if (app.RootMap.MapInfo !is null) {
                if (Permissions::ViewRecords()) {
                    freindsEnabled = true;
                }
            }
        }
        if (app.Network !is null) {
            if (app.Network.ClientManiaAppPlayground !is null) {
                if (freindsEnabled) {
                    string trackNow = app.RootMap.MapInfo.MapUid;
                    if (trackNow != didThisMap) {
                        danTime = askForHisTime(trackNow);
                        didThisMap = trackNow;
                    }
                    MLHook::Queue_MessageManialinkPlayground(page, {"on", tostring(danTime)});
                } else {
                    MLHook::Queue_MessageManialinkPlayground(page, {"off"});
                    didThisMap = "";
                    danTime = 0;
                }
            }
        }
        sleep(1000);
    }
}

uint askForHisTime(string trackWanted) {
    auto gameBits = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
    if (gameBits is null) return 0;
    if (gameBits.UserMgr is null) return 0;
    if (gameBits.ScoreMgr is null) return 0;
    if (gameBits.UserMgr.Users.Length == 0) return 0;

    MwFastBuffer<wstring> oneGuy;
    oneGuy.Add("44ad47cb-6d97-4a55-bcc3-768cf76acaf0");
    auto theManager = gameBits.ScoreMgr;
    auto theThing = theManager.Map_GetPlayerListRecordList(gameBits.UserMgr.Users[0].Id, oneGuy, trackWanted, "PersonalBest", "", "TimeAttack", "");
    while (theThing.IsProcessing) {
        yield();
    }

    uint answer = 0;
    auto mapAfterWait = GetApp().RootMap;
    if (mapAfterWait !is null && Permissions::ViewRecords()) {
        if (mapAfterWait.MapInfo !is null) {
            if (mapAfterWait.MapInfo.MapUid == trackWanted) {
                if (theThing.HasSucceeded && !theThing.HasFailed) {
                    if (theThing.MapRecordList.Length > 0) {
                        auto firstResult = theThing.MapRecordList[0];
                        if (firstResult !is null) {
                            if (firstResult.Time != uint(-1)) {
                                answer = firstResult.Time;
                            }
                        }
                    }
                }
            }
        }
    }
    theManager.TaskResult_Release(theThing.Id);
    trace("Daniel test time: " + answer);
    return answer;
}

void OnDisabled() {
    MLHook::UnregisterMLHooksAndRemoveInjectedML();
}

void OnDestroyed() {
    MLHook::UnregisterMLHooksAndRemoveInjectedML();
}
