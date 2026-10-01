const string page = "RecordsPlusPlus_First";
bool freindsEnabled = false;

const string script = """
 #Include "TextLib" as T
 #Struct K_TMGame_Record_Record { Integer Rank; Text AccountId; Text DisplayName; Integer Score; }
 #Struct K_TMGame_Record_Records { Text ZoneName; Integer WorstScore; Boolean IsFull; Integer Type; K_TMGame_Record_Record[] Records; }

main() {
    declare K_TMGame_Record_Records[] TMGame_Record_ZonesRecords for ClientUI;
    declare Integer TMGame_Record_ZonesRecordsUpdate for ClientUI;
    declare Text[][] MLHook_Inbound_RecordsPlusPlus_First for ClientUI = [];
    declare Boolean enabled = False;
    SendCustomEvent("MLHook_Event_RecordsPlusPlus_Check", ["ready"]);
    while (True) {
        yield;
        declare Integer messageNumber = 0;
        messageNumber = 0;
        while (messageNumber < MLHook_Inbound_RecordsPlusPlus_First.count) {
            if (MLHook_Inbound_RecordsPlusPlus_First[messageNumber].count > 0) {
                if (MLHook_Inbound_RecordsPlusPlus_First[messageNumber][0] == "on") {
                    enabled = True;
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
        if (enabled && found < 0 && TMGame_Record_ZonesRecords.count > 0) {
            declare K_TMGame_Record_Record[] empty;
            declare K_TMGame_Record_Records friends = K_TMGame_Record_Records {
                ZoneName = "FRIENDS",
                WorstScore = 0,
                IsFull = True,
                Type = 1,
                Records = empty
            };
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
            SendCustomEvent("MLHook_Event_RecordsPlusPlus_Check", ["added", "1", T::ToText(zones.count), zones[0].ZoneName]);
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
            if (Permissions::ViewRecords()) {
                freindsEnabled = true;
            }
        }
        if (app.Network !is null) {
            if (app.Network.ClientManiaAppPlayground !is null) {
                if (freindsEnabled) {
                    MLHook::Queue_MessageManialinkPlayground(page, {"on"});
                } else {
                    MLHook::Queue_MessageManialinkPlayground(page, {"off"});
                }
            }
        }
        sleep(1000);
    }
}

void OnDisabled() {
    MLHook::UnregisterMLHooksAndRemoveInjectedML();
}

void OnDestroyed() {
    MLHook::UnregisterMLHooksAndRemoveInjectedML();
}
