pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// =========================================================================
// Shared music / MPRIS / Cava telemetry — SOLE OWNER.
// Consumed by TopBar.qml + SideBar.qml via live aliases
// (property var musicData: MusicState.musicData, ...), so both bars
// observe the same object with zero consumer-site rewrites.
//
// Consolidates the previously duplicated per-bar pipelines:
// exactly ONE metadata follower, ONE status follower, ONE music_info.sh
// invoker, ONE json watcher, ONE cava process, ONE interpolation timer,
// ONE drift timer — regardless of which bar (if any) is visible.
// Event flow (all native/event-driven, no polling):
//   playerctl --follow lines → optimistic status/title patch +
//     debounced music_info.sh → music_info.json → FileView → musicData;
//   musicData.status === "Playing" → cava + 1s interpolation + 45s drift;
//   stop/pause → cava + timers stop, bars zeroed.
// =========================================================================

Item {
    id: root

    // Never orphan followers on engine reload: Quickshell destroys QML
    // Process items without reliably SIGTERMing children, which used to
    // accumulate one stale playerctl pair per reload (PPID 1). Stopping
    // explicitly here keeps exactly one live pair across reloads.
    Component.onDestruction: {
        mprisWatcher.running = false;
        mprisStatusWatcher.running = false;
        cavaProcess.running = false;
        musicForceRefresh.running = false;
    }

    // --- State (live-aliased by both bars) ---
    property var musicData: { "status": "Stopped", "title": "", "artUrl": "", "timeStr": "", "artReady": "false" }
    readonly property bool isMediaActive: musicData.status !== "Stopped" && musicData.title !== ""
    readonly property bool isSpotify: isMediaActive && (
        (musicData.playerName && musicData.playerName.toLowerCase().indexOf("spotify") !== -1) ||
        (musicData.source && musicData.source.toLowerCase().indexOf("spotify") !== -1)
    )
    readonly property string displayTitle: isMediaActive ? musicData.title : ""
    readonly property string displayTime: isMediaActive ? musicData.timeStr : ""
    readonly property string displayArtUrl: isMediaActive ? musicData.artUrl : ""
    readonly property bool displayArtReady: isMediaActive && musicData.artReady === "true"
    readonly property bool hasVisibleMedia: displayTitle !== ""

    // Raw ascii bar levels (0-100 each) from cava_topbar.conf, one per bar.
    property var cavaBars: [0, 0, 0, 0, 0, 0, 0, 0]

    // --- Debounced refresh trigger (coalesces rapid mpris bursts) ---
    Timer {
        id: musicRefreshDebounce
        interval: 80
        repeat: false
        onTriggered: {
            musicForceRefresh.running = false;
            Qt.callLater(() => { musicForceRefresh.running = true; });
        }
    }

    function refreshMusic() {
        musicRefreshDebounce.restart();
    }

    // --- music_info.sh one-shot (cold-start fetch + retriggered) ---
    Process {
        id: musicForceRefresh
        running: true
        command: ["bash", "-c", "bash " + Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/music/music_info.sh > '" + Caching.getRunDir('music') + "/music_info.json.tmp' && mv '" + Caching.getRunDir('music') + "/music_info.json.tmp' '" + Caching.getRunDir('music') + "/music_info.json' && cat '" + Caching.getRunDir('music') + "/music_info.json'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try {
                        let newData = JSON.parse(txt);
                        let oldData = root.musicData || {};
                        let posDiff = Math.abs(newData.position - (oldData.position || 0));

                        if (oldData.title !== newData.title || oldData.status !== newData.status || oldData.artUrl !== newData.artUrl || posDiff >= 1) {
                            root.musicData = newData;
                        }
                    } catch(e) {}
                }
            }
        }
    }

    FileView {
        id: musicFileView
        path: Caching.getRunDir('music') + "/music_info.json"
        watchChanges: true
        onLoadedChanged: root.parseMusicFile()
        onTextChanged: root.parseMusicFile()
    }

    function parseMusicFile() {
        let txt = (musicFileView.text() || "").trim();
        if (txt !== "") {
            try {
                let newData = JSON.parse(txt);
                let oldData = root.musicData || {};
                let posDiff = Math.abs(newData.position - (oldData.position || 0));

                if (oldData.title !== newData.title || oldData.status !== newData.status || oldData.artUrl !== newData.artUrl || posDiff > 3) {
                    root.musicData = newData;
                }
            } catch(e) {}
        }
    }

    // 1s timeline advance (Playing only)
    Timer {
        interval: 1000
        running: root.musicData !== null && root.musicData.status === "Playing"
        repeat: true
        onTriggered: {
            if (!root.musicData || root.musicData.status !== "Playing") return;
            if (!root.musicData.timeStr || root.musicData.timeStr === "") return;

            let parts = root.musicData.timeStr.split(" / ");
            if (parts.length !== 2) return;

            let posParts = parts[0].split(":").map(Number);
            let lenParts = parts[1].split(":").map(Number);

            let posSecs = (posParts.length === 3)
                ? (posParts[0] * 3600 + posParts[1] * 60 + posParts[2])
                : (posParts[0] * 60 + posParts[1]);

            let lenSecs = (lenParts.length === 3)
                ? (lenParts[0] * 3600 + lenParts[1] * 60 + lenParts[2])
                : (lenParts[0] * 60 + lenParts[1]);

            if (isNaN(posSecs) || isNaN(lenSecs)) return;

            posSecs++;
            if (posSecs > lenSecs) posSecs = lenSecs;

            let newPosStr = "";
            if (posParts.length === 3) {
                let h = Math.floor(posSecs / 3600);
                let m = Math.floor((posSecs % 3600) / 60);
                let s = posSecs % 60;
                newPosStr = h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
            } else {
                let m = Math.floor(posSecs / 60);
                let s = posSecs % 60;
                newPosStr = (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
            }

            let newData = Object.assign({}, root.musicData);
            newData.timeStr = newPosStr + " / " + parts[1];
            newData.positionStr = newPosStr;
            newData.position = posSecs;
            if (lenSecs > 0) newData.percent = (posSecs / lenSecs) * 100;

            root.musicData = newData;
        }
    }

    // Position drift correction ONLY (Playing only). MPRIS emits no
    // continuous position stream, so the 1s interpolation above
    // accumulates a small offset over long playback.
    Timer {
        interval: 45000
        running: root.isMediaActive && root.musicData.status === "Playing"
        repeat: true
        onTriggered: {
            musicRefreshDebounce.restart();
        }
    }

    // Follows all players (-a superset covering both bars' old commands).
    // Optimistic status/title patch for instant UI response; full refresh
    // (art, position, duration) follows via debounce.
    Process {
        id: mprisWatcher
        running: true
        command: ["playerctl", "-a", "--follow", "metadata", "--format", "{{status}}|{{title}}"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                let trimmed = line.trim();
                if (trimmed !== "") {
                    let sep = trimmed.indexOf("|");
                    let status = sep !== -1 ? trimmed.substring(0, sep).trim() : trimmed;
                    let title = sep !== -1 ? trimmed.substring(sep + 1).trim() : "";
                    if (status !== "" && status !== "null") {
                        let cur = Object.assign({}, root.musicData || {});
                        cur.status = status;
                        if (title !== "") cur.title = title;
                        root.musicData = cur;
                    }
                }
                musicRefreshDebounce.restart();
            }
        }
    }

    // Catches play/pause/stop transitions that don't trigger metadata changes
    Process {
        id: mprisStatusWatcher
        running: true
        command: ["playerctl", "-a", "--follow", "status"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                let status = line.trim();
                if (status === "Playing" || status === "Paused" || status === "Stopped") {
                    let cur = Object.assign({}, root.musicData || {});
                    if (cur.status !== status) {
                        cur.status = status;
                        root.musicData = cur;
                        musicRefreshDebounce.restart();
                    }
                }
            }
        }
    }

    // Audio visualizer. Bound to status === "Playing" specifically (not
    // just "not stopped") so it only spawns while media is genuinely
    // playing — avoids running cava (and burning CPU on FFT of silence)
    // during a pause. cava_topbar.conf outputs raw ascii bar levels
    // (0-100, semicolon-separated) once per frame at 30fps directly to
    // stdout — no intermediate FIFO or wrapper script needed.
    // `nice -n 10` deprioritizes it relative to everything else on the
    // system — purely cosmetic background process.
    Process {
        id: cavaProcess
        running: root.musicData.status === "Playing"
        command: ["nice", "-n", "10", "cava", "-p", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/cava_topbar.conf"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                let segs = line.split(";");
                let out = [];
                for (let i = 0; i < segs.length && out.length < 8; i++) {
                    if (segs[i].length === 0) continue;
                    let v = parseInt(segs[i], 10);
                    if (isNaN(v)) { out = null; break; }
                    out.push(v < 0 ? 0 : (v > 100 ? 100 : v));
                }
                if (out && out.length === 8) root.cavaBars = out;
            }
        }
        onRunningChanged: {
            // Decay bars to resting (empty) state immediately when playback
            // stops/pauses, rather than freezing at the last loud frame.
            if (!running) root.cavaBars = [0, 0, 0, 0, 0, 0, 0, 0];
        }
    }
}
