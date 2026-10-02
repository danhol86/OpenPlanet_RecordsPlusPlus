array<string> debugLines;

//settings for debugging only. is this ok in production?
[Setting category="Debug" name="Show Popup"]
bool ShowPopup = false;

[Setting category="Debug" name="Enable debugging"]
bool DebugEnabled = false;

ScriptDebugHook@ scriptDebugHook;

void RegisterDebug() {
    @scriptDebugHook = ScriptDebugHook();

    MLHook::RegisterMLHook(
        scriptDebugHook,
        "RecordsPlusPlus_Debug",
        true
    );
}

//add logs to the trace (shown in logs tab in Openplanet) then also log seperately to show in new debug popup
void Dbg(const string &in source, const string &in message) {
    if (!DebugEnabled) return;

    string line =
        "[" + tostring(Time::Now) + "] [" + source + "] " + message;

    trace(line);
    debugLines.InsertLast(line);
}

//create hook to allow for messages to be passerd from ml events so can log exceptions etc
class ScriptDebugHook : MLHook::HookMLEventsByType {
    ScriptDebugHook() {
        super("RecordsPlusPlus_Debug");
    }

    void OnEvent(MLHook::PendingEvent@ event) override {
        string msg = "";

        for (uint i = 0; i < event.data.Length; i++) {
            if (i > 0)
                msg += " | ";

            msg += string(event.data[i]);
        }

        Dbg("MANIASCRIPT", msg);
    }
}

//shows popup if debugging enabled and show is true
void Render() {
    if (!ShowPopup) return;

    UI::SetNextWindowSize(900, 550, UI::Cond::FirstUseEver);
    UI::Begin("Records++ Debugging");
    UI::Separator();

    uint start = debugLines.Length > 40
        ? debugLines.Length - 40
        : 0;

    for (uint i = start; i < debugLines.Length; i++)
        UI::TextWrapped(debugLines[i]);

    UI::End();
}
