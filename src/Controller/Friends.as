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

        game.UserMgr.TaskResult_Release(job.Id);
    }

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

        if (requestedMap != seenMap || !Permissions::ViewRecords()) {
            gettingTimes = false;
            return;
        }
    }

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

    MLHook::Queue_MessageManialinkPlayground(page, {"reset"});

    for (uint i = 0; i < friends.Length; i++) {
        if (friends[i].time == 0) continue;

        MLHook::Queue_MessageManialinkPlayground(
            page,
            {"row", friends[i].id, friends[i].name, tostring(friends[i].place), tostring(friends[i].time)}
        );
    }

    gettingTimes = false;
    loadedOnce = true;
}
