using ManiaScriptSharp;
using static ManiaScriptSharp.ManiaScript;

namespace RecordsPlusPlus.ManiaScript;

public struct K_TMGame_Record_Record
{
    public int Rank;
    public string AccountId;
    public string DisplayName;
    public int Score;
}

public struct K_TMGame_Record_Records
{
    public string ZoneName;
    public int WorstScore;
    public bool IsFull;
    public int Type;
    public List<K_TMGame_Record_Record> Records;
}

public class FriendsRecords : CSmMlScriptIngame, IContext
{
    private void Dbg(string msg)
    {
        SendCustomEvent("RecordsPlusPlus_Debug", [msg]);
    }

    public void Main()
    {
        Dbg("SCRIPT STARTED");

        Local<List<K_TMGame_Record_Records>>.For(ClientUI, out var zonesRecords, name: "TMGame_Record_ZonesRecords");

        Dbg("Loaded zones records: " + zonesRecords.Value.Count.ToString());


        Local<int>.For(ClientUI, out var zonesRecordsUpdate, name: "TMGame_Record_ZonesRecordsUpdate");
        Local<List<List<string>>>.For(ClientUI, out var inbound, name: "MLHook_Inbound_RecordsPlusPlus_First");

        inbound.Value = [];

        var people = new List<K_TMGame_Record_Record>();
        var enabled = false;
        var changed = false;
        var lastUpdate = -1;

        while (true)
        {
            Yield();

            var x = 0;

            while (x < inbound.Value.Count)
            {
                var msg = inbound.Value[x];
                Dbg("New message: " + string.Join(", ", msg));
                if (msg.Count > 0)
                {
                    if (msg[0] == "reset")
                    {
                        people.Clear();
                        enabled = true;
                        changed = true;
                    }

                    if (msg[0] == "row" && msg.Count == 5)
                    {
                        people.Add(new K_TMGame_Record_Record
                        {
                            Rank = int.Parse(msg[3]),
                            AccountId = msg[1],
                            DisplayName = msg[2],
                            Score = int.Parse(msg[4])
                        });

                        changed = true;
                    }

                    if (msg[0] == "off")
                    {
                        enabled = false;
                        people.Clear();
                        changed = true;
                    }
                }

                x += 1;
            }

            inbound.Value = [];

            var found = -1;
            x = 0;

            while (x < zonesRecords.Value!.Count)
            {
                if (zonesRecords.Value![x].ZoneName == "FRIENDS")
                    found = x;

                x += 1;
            }

            if (enabled && zonesRecords.Value!.Count > 0 &&(changed || found < 0 || lastUpdate != zonesRecordsUpdate.Value))
            {
                var worst = 0;
                x = 0;

                while (x < people.Count)
                {
                    if (people[x].Score > worst)
                        worst = people[x].Score;

                    x += 1;
                }

                var friends = new K_TMGame_Record_Records
                {
                    ZoneName = "FRIENDS",
                    WorstScore = worst,
                    IsFull = true,
                    Type = 1,
                    Records = people
                };

                if (found >= 0)
                {
                    zonesRecords.Value![found] = friends;
                }
                else
                {
                    var zones = new List<K_TMGame_Record_Records>();

                    zones.Add(zonesRecords.Value![0]);
                    zones.Add(friends);

                    x = 1;
                    while (x < zonesRecords.Value!.Count)
                    {
                        zones.Add(zonesRecords.Value![x]);
                        x += 1;
                    }

                    zonesRecords.Value = zones;
                }

                zonesRecordsUpdate.Value += 1;
                changed = false;
            }

            if (!enabled && found >= 0)
            {
                zonesRecords.Value!.RemoveAt(found);
                zonesRecordsUpdate.Value += 1;
                changed = false;
            }

            lastUpdate = zonesRecordsUpdate.Value;
        }
    }

    public void Loop()
    {
    }
}
