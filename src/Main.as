class FriendScore
{
    string AccountId;
    string Name;
    uint Time;

    FriendScore(const string &in accountId, const string &in name)
    {
        AccountId = accountId;
        Name = name;
    }
}

array<FriendScore@> FriendScores;
string CurrentMapUid = "";
bool IsLoading = false;
string Status = "";

void Main()
{
    while (true)
    {
        string mapUid = GetMapUid();

        if (mapUid != CurrentMapUid)
        {
            CurrentMapUid = mapUid;
            FriendScores = array<FriendScore@>();

            if (CurrentMapUid.Length > 0)
            {
                startnew(LoadFriendScores);
            }
        }

        sleep(500);
    }
}

void RenderInterface()
{
    if (CurrentMapUid.Length == 0)
        return;

    if (!UI::Begin("Records++"))
    {
        UI::End();
        return;
    }

    UI::Text("Friends");

    if (IsLoading)
    {
        UI::Text("Loading...");
    }
    else if (Status.Length > 0)
    {
        UI::Text(Status);
    }
    else if (FriendScores.Length == 0)
    {
        UI::Text("No friend times found.");
    }
    else if (UI::BeginTable("FriendScores", 2))
    {
        UI::TableSetupColumn("Friend");
        UI::TableSetupColumn("Time");
        UI::TableHeadersRow();

        for (uint i = 0; i < FriendScores.Length; i++)
        {
            UI::TableNextRow();
            UI::TableNextColumn();
            UI::Text(FriendScores[i].Name);
            UI::TableNextColumn();
            UI::Text(FormatTime(FriendScores[i].Time));
        }

        UI::EndTable();
    }

    UI::End();
}

void LoadFriendScores()
{
    if (IsLoading)
        return;

    IsLoading = true;
    Status = "";

    string mapUid = CurrentMapUid;
    CSmArenaRulesMode@ rules = WaitForRulesMode(mapUid);

    if (rules is null)
    {
        IsLoading = false;
        return;
    }

    auto userManager = rules.UserMgr;
    auto friendTask = userManager.Friend_GetList(userManager.Users[0].Id);

    while (friendTask.IsProcessing)
    {
        if (mapUid != CurrentMapUid)
        {
            IsLoading = false;
            return;
        }

        yield();
    }

    if (friendTask.HasFailed || !friendTask.HasSucceeded)
    {
        Status = "Unable to load friends.";
        userManager.TaskResult_Release(friendTask.Id);
        IsLoading = false;
        return;
    }

    array<FriendScore@> scores;
    MwFastBuffer<wstring> accountIds;

    for (uint i = 0; i < friendTask.FriendList.Length; i++)
    {
        auto friend = friendTask.FriendList[i];
        if (friend is null)
            continue;

        string accountId = friend.WebServicesUserId;

        if (accountId.Length == 0)
            accountId = friend.AccountId;

        if (accountId.Length == 0)
            continue;

        string name = string(friend.DisplayName);

        if (name.Length == 0)
            name = accountId;

        scores.InsertLast(FriendScore(accountId, name));
        accountIds.Add(accountId);
    }

    userManager.TaskResult_Release(friendTask.Id);

    if (accountIds.Length == 0)
    {
        FriendScores = scores;
        IsLoading = false;
        return;
    }

    auto scoreTask = rules.ScoreMgr.Map_GetPlayerListRecordList(
        userManager.Users[0].Id,
        accountIds,
        mapUid,
        "PersonalBest",
        "",
        "TimeAttack",
        ""
    );

    while (scoreTask.IsProcessing)
    {
        if (mapUid != CurrentMapUid)
        {
            IsLoading = false;
            return;
        }

        yield();
    }

    if (scoreTask.HasFailed || !scoreTask.HasSucceeded)
    {
        Status = "Unable to load friend times.";
        rules.ScoreMgr.TaskResult_Release(scoreTask.Id);
        IsLoading = false;
        return;
    }

    for (uint i = 0; i < scoreTask.MapRecordList.Length; i++)
    {
        auto record = scoreTask.MapRecordList[i];
        FriendScore@ score = FindFriendScore(scores, record);

        if (score !is null)
            score.Time = record.Time;
    }

    rules.ScoreMgr.TaskResult_Release(scoreTask.Id);

    FriendScores = GetScoresWithTimes(scores);
    SortScores();
    IsLoading = false;
}

CSmArenaRulesMode@ WaitForRulesMode(const string &in mapUid)
{
    while (mapUid == CurrentMapUid)
    {
        CSmArenaRulesMode@ rules = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);

        if (rules !is null
            && rules.UserMgr !is null
            && rules.ScoreMgr !is null
            && rules.UserMgr.Users.Length > 0)
        {
            return rules;
        }

        sleep(100);
    }

    return null;
}

FriendScore@ FindFriendScore(array<FriendScore@> &in scores, CMapRecord@ record)
{
    if (record is null)
        return null;

    for (uint i = 0; i < scores.Length; i++)
    {
        if (scores[i].AccountId == record.WebServicesUserId
            || scores[i].AccountId == record.AccountId)
        {
            return scores[i];
        }
    }

    return null;
}

array<FriendScore@> GetScoresWithTimes(array<FriendScore@> &in scores)
{
    array<FriendScore@> result;

    for (uint i = 0; i < scores.Length; i++)
    {
        if (scores[i].Time > 0)
            result.InsertLast(scores[i]);
    }

    return result;
}

void SortScores()
{
    for (uint i = 0; i < FriendScores.Length; i++)
    {
        for (uint j = i + 1; j < FriendScores.Length; j++)
        {
            if (FriendScores[j].Time < FriendScores[i].Time)
            {
                FriendScore@ score = FriendScores[i];
                @FriendScores[i] = FriendScores[j];
                @FriendScores[j] = score;
            }
        }
    }
}

string GetMapUid()
{
    auto map = GetApp().RootMap;

    if (map is null || map.MapInfo is null)
        return "";

    return map.MapInfo.MapUid;
}

string FormatTime(uint time)
{
    uint minutes = time / 60000;
    uint seconds = (time % 60000) / 1000;
    uint milliseconds = time % 1000;

    return tostring(minutes)
        + ":"
        + Text::Format("%02d", seconds)
        + "."
        + Text::Format("%03d", milliseconds);
}
