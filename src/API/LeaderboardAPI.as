//use map id and score to get the place in world. set up own server as wouldnt work with my credneitlas.
//used this project - https://github.com/Banalian/ExtraLeaderboardAPI
uint getWorldPlace(const string &in map, uint score) {
    string url = "https://extraleaderboardapi.agileapps.uk/ELP/api/leaderboard/map/" + map + "/time?time=" + tostring(score);

    Dbg("AS", "WORLD REQUEST score=" + tostring(score) + " url=" + url);

    auto request = Net::HttpRequest();
    request.Url = url;
    request.Method = Net::HttpMethod::Get;
    request.Start();

    while (!request.Finished())
        yield();

    if (map != seenMap)
        return 0;

    Dbg("AS", "WORLD RESPONSE data=" + request.String());

    if (request.ResponseCode() != 200)
        return 0;

    auto data = Json::Parse(request.String());
    if (data is null)
        return 0;

    auto positions = data["positions"];
    if (positions is null || positions.Length == 0)
        return 0;

    return uint(int(positions[0]["rank"]));
}
