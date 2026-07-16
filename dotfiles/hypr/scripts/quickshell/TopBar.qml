import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray

Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: barWindow
            property bool pendingReload: false


            IpcHandler {
                target: "topbar"
                function forceReload() {
                    Quickshell.reload(true)
                }
                function queueReload() {
                    Quickshell.reload(true)
                }
                function toggleUpdate() {
                    barWindow.forceUpdateShow = !barWindow.forceUpdateShow
                }
            }

            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            Scaler {
                id: scaler
                currentWidth: barWindow.width
            }

            property real baseScale: scaler.baseScale

            function s(val) {
                return scaler.s(val);
            }

            property int barHeight: s(48)

            implicitHeight: barHeight
            margins { top: s(2); bottom: 0; left: s(4); right: s(4) }
            exclusiveZone: barHeight - s(4)
            color: "transparent"

            MatugenColors {
                id: mocha
            }

            property bool showHelpIcon: true
            property bool isRecording: false

            property bool updateAvailable: false
            property bool forceUpdateShow: false
            property bool isUpdateVisible: updateAvailable || forceUpdateShow

            property int workspaceCount: 69

            property string activeWidget: ""

            Timer {
                interval: 2000
                running: true
                repeat: true
                onTriggered: {
                    widgetPoller.running = false; widgetPoller.running = true;
                    recPoller.running = false; recPoller.running = true;
                    updatePoller.running = false; updatePoller.running = true;
                    musicForceRefresh.running = false; musicForceRefresh.running = true;
                }
            }

            Process {
                id: widgetPoller
                command: ["bash", "-c", "cat '" + Caching.runDir + "/current_widget' 2>/dev/null || echo ''"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (barWindow.activeWidget !== txt) barWindow.activeWidget = txt;
                    }
                }
            }

            Process {
                id: recPoller
                command: ["bash", "-c", "if [ -s '" + Caching.getCacheDir('recording') + "/rec_pid' ] && kill -0 $(cat '" + Caching.getCacheDir('recording') + "/rec_pid') 2>/dev/null; then echo '1'; else echo '0'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.isRecording = (this.text.trim() === "1");
                    }
                }
            }

            Process {
                id: updatePoller
                command: ["bash", "-c", "if [ -f '" + Caching.getCacheDir('updater') + "/update_pending' ]; then echo '1'; else echo '0'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.updateAvailable = (this.text.trim() === "1");
                    }
                }
            }

            property bool isDesktop: false
            property string ethStatus: "Ethernet"

            Process {
                id: chassisDetector
                running: true
                command: ["bash", "-c", "if ls /sys/class/power_supply/BAT* 1> /dev/null 2>&1; then echo 'laptop'; else echo 'desktop'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.isDesktop = (this.text.trim() === "desktop");
                    }
                }
            }

            property bool isStartupReady: false
            Timer { interval: 10; running: true; onTriggered: barWindow.isStartupReady = true }

            property bool startupCascadeFinished: false
            Timer { interval: 1000; running: true; onTriggered: barWindow.startupCascadeFinished = true }

            // isDataReady used to be gated on a hardcoded 600ms Timer that
            // had nothing to do with real data — it fired on a fixed clock
            // regardless of whether any poller had actually returned
            // anything yet, then several more artificial per-widget delays
            // stacked on top of that for the tray/battery pill specifically
            // (~1.5s total before they became visible). Replaced with real
            // flags set the moment each relevant poller's stdout actually
            // resolves (see audioPoller/networkPoller/btPoller/batteryPoller
            // below) — on a local machine these all resolve in well under
            // 100ms, so the pills now appear as soon as they actually can,
            // with real data already populated, instead of waiting on an
            // arbitrary clock.
            property bool audioLoaded: false
            property bool networkLoaded: false
            property bool btLoaded: false
            property bool batteryLoaded: false
            property bool dataReadyFallbackTriggered: false
            property bool isDataReady: (audioLoaded && networkLoaded && btLoaded && batteryLoaded) || dataReadyFallbackTriggered

            // Safety net only, in case a poller script is ever broken/slow —
            // guarantees the bar never hangs forever waiting on one flag.
            Timer { interval: 800; running: true; onTriggered: barWindow.dataReadyFallbackTriggered = true }

            property string timeStr: ""
            property string fullDateStr: ""
            property int typeInIndex: 0
            property string dateStr: fullDateStr.substring(0, typeInIndex)

            property string wifiStatus: "Off"
            property string wifiIcon: "󰤮"
            property string wifiSsid: ""

            property string btStatus: "Off"
            property string btIcon: "󰂲"
            property string btDevice: ""

            property string volPercent: "0%"
            property string volIcon: "󰕾"
            property bool isMuted: false

            property string batPercent: "100%"
            property string batIcon: "󰁹"
            property string batStatus: "Unknown"

            property string kbLayout: "us"

            ListModel {
                id: workspacesModel
                property int activeIndex: 0
            }

            property var musicData: { "status": "Stopped", "title": "", "artUrl": "", "timeStr": "" }

            readonly property bool isMediaActive: musicData.status !== "Stopped" && musicData.title !== ""
            readonly property string displayTitle: isMediaActive ? musicData.title : ""
            readonly property string displayTime: isMediaActive ? musicData.timeStr : ""
            readonly property string displayArtUrl: isMediaActive ? musicData.artUrl : ""
            readonly property bool displayArtReady: isMediaActive && musicData.artReady === "true"
            readonly property bool hasVisibleMedia: displayTitle !== ""

            // Raw ascii bar levels (0-100 each) from cava_topbar.conf's raw
            // output, one value per bar. Zero baseline — the visualizer
            // itself fades to width/opacity 0 when not playing, so there
            // are no idle "dot" segments left sitting on screen.
            property var cavaBars: [0, 0, 0, 0, 0, 0, 0, 0]

            function _hexToRgb01(hex) {
                let h = hex.replace("#", "");
                return {
                    r: parseInt(h.substring(0, 2), 16) / 255,
                    g: parseInt(h.substring(2, 4), 16) / 255,
                    b: parseInt(h.substring(4, 6), 16) / 255
                };
            }

            // 3-stop gradient (mauve -> blue -> pink) across however many
            // bars there are, computed once per bar index (not per-frame —
            // bar color is static, only height animates).
            function cavaBarColor(index, count) {
                let stops = [mocha.mauve, mocha.blue, mocha.pink];
                let t = count > 1 ? index / (count - 1) : 0;
                let seg = t * (stops.length - 1);
                let segIndex = Math.min(Math.floor(seg), stops.length - 2);
                let localT = seg - segIndex;
                let c1 = barWindow._hexToRgb01(stops[segIndex]);
                let c2 = barWindow._hexToRgb01(stops[segIndex + 1]);
                return Qt.rgba(
                    c1.r + (c2.r - c1.r) * localT,
                    c1.g + (c2.g - c1.g) * localT,
                    c1.b + (c2.b - c1.b) * localT,
                    1.0
                );
            }

            property bool isWifiOn: barWindow.wifiStatus.toLowerCase() === "enabled" || barWindow.wifiStatus.toLowerCase() === "on"
            property bool isBtOn: barWindow.btStatus.toLowerCase() === "enabled" || barWindow.btStatus.toLowerCase() === "on"
            property bool showEthernet: barWindow.ethStatus === "Connected" || (barWindow.isDesktop && !barWindow.isWifiOn)

            property bool isSoundActive: !barWindow.isMuted && parseInt(barWindow.volPercent) > 0
            property int batCap: parseInt(barWindow.batPercent) || 0
            property bool isCharging: barWindow.batStatus === "Charging" || barWindow.batStatus === "Full"

            property color batDynamicColor: {
                if (isCharging) return mocha.mauve;
                if (batCap <= 20) return mocha.mauve;
                return mocha.text;
            }

            Process {
                id: wsDaemon
                command: ["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/workspaces.sh"]
                running: true
            }

            Process {
                id: wsReader
                running: true
                command: ["cat", Caching.getRunDir("workspaces") + "/workspaces.json"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let newData = JSON.parse(txt);

                                var diff = newData.length - workspacesModel.count;
if (diff > 0) {
    var workspaceBatch = [];
    for (var i = 0; i < diff; i++) {
        workspaceBatch.push({ "wsId": "", "wsState": "" });
    }
    workspacesModel.append(workspaceBatch);
}

                                while (workspacesModel.count > newData.length) {
                                    workspacesModel.remove(workspacesModel.count - 1);
                                }

                                let newActive = -1;

                                for (let i = 0; i < newData.length; i++) {
                                    if (newData[i].state === "active") newActive = i;

                                    if (workspacesModel.get(i).wsState !== newData[i].state) {
                                        workspacesModel.setProperty(i, "wsState", newData[i].state);
                                    }
                                    if (workspacesModel.get(i).wsId !== newData[i].id.toString()) {
                                        workspacesModel.setProperty(i, "wsId", newData[i].id.toString());
                                    }
                                }

                                if (newActive !== -1 && workspacesModel.activeIndex !== newActive) {
                                    workspacesModel.activeIndex = newActive;
                                }

                            } catch(e) {}
                        }
                    }
                }
            }

            Process {
                id: wsWatcher
                running: true
                command: ["bash", "-c", "while [ ! -f '" + Caching.getRunDir('workspaces') + "/workspaces.json' ]; do sleep 1; done; inotifywait -qq -e modify,close_write,move_self '" + Caching.getRunDir('workspaces') + "/workspaces.json'; sleep 0.05"]
                onExited: {
                    wsReader.running = false;
                    wsReader.running = true;
                    running = false;
                    running = true;
                }
            }

            Process {
                id: musicForceRefresh
                running: true
                command: ["bash", "-c", "bash " + Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/music/music_info.sh | tee '" + Caching.getRunDir('music') + "/music_info.json'"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try { 
                                let newData = JSON.parse(txt);
                                let oldData = barWindow.musicData || {};
                                let posDiff = Math.abs(newData.position - (oldData.position || 0));

                                if (oldData.title !== newData.title || oldData.status !== newData.status || oldData.artUrl !== newData.artUrl || posDiff > 3) {
                                    barWindow.musicData = newData;
                                }
                            } catch(e) {}
                        }
                    }
                }
            }

            Timer {
                interval: 1000
                running: barWindow.musicData !== null && barWindow.musicData.status === "Playing"
                repeat: true
                onTriggered: {
                    if (!barWindow.musicData || barWindow.musicData.status !== "Playing") return;
                    if (!barWindow.musicData.timeStr || barWindow.musicData.timeStr === "") return;

                    let parts = barWindow.musicData.timeStr.split(" / ");
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

                    let newData = Object.assign({}, barWindow.musicData);
                    newData.timeStr = newPosStr + " / " + parts[1];
                    newData.positionStr = newPosStr;
                    newData.position = posSecs; 
                    if (lenSecs > 0) newData.percent = (posSecs / lenSecs) * 100;

                    barWindow.musicData = newData;
                }
            }

            Process {
                id: mprisWatcher
                running: true
                command: ["bash", "-c", "dbus-monitor --session \"type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.mpris.MediaPlayer2.Player'\" \"type='signal',interface='org.mpris.MediaPlayer2.Player',member='Seeked'\" 2>/dev/null | grep -m 1 'member=' > /dev/null || sleep 2"]
                onExited: {
                    musicForceRefresh.running = false;
                    musicForceRefresh.running = true;
                    running = false;
                    running = true;
                }
            }

            // Topbar audio visualizer. Bound to status === "Playing"
            // specifically (not just "not stopped") so it only spawns
            // while media is genuinely playing — matches the visualizer's
            // own fade-away-when-not-playing behavior, and avoids running
            // cava (and burning CPU on FFT of silence) during a pause.
            // cava_topbar.conf outputs raw ascii bar levels (0-100,
            // semicolon-separated) once per frame at 30fps directly to
            // stdout — no intermediate FIFO or wrapper script needed.
            // `nice -n 10` deprioritizes it relative to everything else on
            // the system — this is a purely cosmetic background process and
            // shouldn't be able to delay anything time-sensitive (e.g. the
            // synthetic DBus Seeked signal music_info.sh's art-fetch fires
            // on completion, which mprisWatcher below is waiting on).
            Process {
                id: cavaProcess
                running: barWindow.musicData.status === "Playing"
                command: ["nice", "-n", "10", "cava", "-p", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/cava_topbar.conf"]
                stdout: SplitParser {
                    splitMarker: "\n"
                    onRead: (line) => {
                        // Single pass: tokenize, parse, and clamp into one
                        // fixed-size array instead of chaining
                        // filter/map/slice (each allocates a new array) —
                        // this runs on every cava frame, so keeping
                        // per-frame allocation low matters for avoiding GC
                        // pauses on the shared QML thread.
                        let segs = line.split(";");
                        let out = [];
                        for (let i = 0; i < segs.length && out.length < 8; i++) {
                            if (segs[i].length === 0) continue;
                            let v = parseInt(segs[i], 10);
                            if (isNaN(v)) { out = null; break; }
                            out.push(v < 0 ? 0 : (v > 100 ? 100 : v));
                        }
                        if (out && out.length === 8) barWindow.cavaBars = out;
                    }
                }
                onRunningChanged: {
                    // Decay bars to resting (empty) state immediately when
                    // playback stops/pauses, rather than freezing at the
                    // last loud frame until the next play.
                    if (!running) barWindow.cavaBars = [0, 0, 0, 0, 0, 0, 0, 0];
                }
            }

            
            Process {
                id: audioPoller; running: true
                command: ["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/audio_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.audioLoaded = true;
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                let newVol = data.volume.toString() + "%";
                                if (barWindow.volPercent !== newVol) barWindow.volPercent = newVol;
                                if (barWindow.volIcon !== data.icon) barWindow.volIcon = data.icon;
                                let newMuted = (data.is_muted === "true");
                                if (barWindow.isMuted !== newMuted) barWindow.isMuted = newMuted;
                            } catch(e) {}
                        }
                        audioWaiter.running = false;
                        audioWaiter.running = true;
                    }
                }
            }
            Process { id: audioWaiter; command: ["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/audio_wait.sh"]; onExited: { audioPoller.running = false; audioPoller.running = true; } }

            Process {
                id: networkPoller; running: true
                command: ["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/network_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.networkLoaded = true;
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                if (barWindow.wifiStatus !== data.status) barWindow.wifiStatus = data.status;
                                if (barWindow.wifiIcon !== data.icon) barWindow.wifiIcon = data.icon;
                                if (barWindow.wifiSsid !== data.ssid) barWindow.wifiSsid = data.ssid;
                                if (barWindow.ethStatus !== data.eth_status) barWindow.ethStatus = data.eth_status;
                            } catch(e) {}
                        }
                        networkWaiter.running = false;
                        networkWaiter.running = true;
                    }
                }
            }
            Process { id: networkWaiter; command: ["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/network_wait.sh"]; onExited: { networkPoller.running = false; networkPoller.running = true; } }

            Process {
                id: btPoller; running: true
                command: ["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/bt_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.btLoaded = true;
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                if (barWindow.btStatus !== data.status) barWindow.btStatus = data.status;
                                if (barWindow.btIcon !== data.icon) barWindow.btIcon = data.icon;
                                if (barWindow.btDevice !== data.connected) barWindow.btDevice = data.connected;
                            } catch(e) {}
                        }
                        btWaiter.running = false;
                        btWaiter.running = true;
                    }
                }
            }
            Process { id: btWaiter; command: ["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/bt_wait.sh"]; onExited: { btPoller.running = false; btPoller.running = true; } }

            Process {
                id: batteryPoller; running: true
                command: ["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/battery_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.batteryLoaded = true;
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                let pctNum = parseInt(data.percent);
                                if (!isNaN(pctNum) && pctNum >= 0 && pctNum <= 100) {
                                    let newBat = pctNum + "%";
                                    if (barWindow.batPercent !== newBat) barWindow.batPercent = newBat;
                                    if (barWindow.batIcon !== data.icon) barWindow.batIcon = data.icon;
                                    if (barWindow.batStatus !== data.status) barWindow.batStatus = data.status;
                                }
                            } catch(e) {}
                        }
                        batteryWaiter.running = false;
                        batteryWaiter.running = true;
                    }
                }
            }
            Process { id: batteryWaiter; command: ["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/watchers/battery_wait.sh"]; onExited: { batteryPoller.running = false; batteryPoller.running = true; } }

            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    let d = new Date();
                    barWindow.timeStr = Qt.formatDateTime(d, "HH:mm");
                    barWindow.fullDateStr = Qt.formatDateTime(d, "dddd, MMMM dd");
                    if (barWindow.typeInIndex >= barWindow.fullDateStr.length) {
                        barWindow.typeInIndex = barWindow.fullDateStr.length;
                    }
                }
            }

            Timer {
                id: typewriterTimer
                interval: 40
                running: barWindow.isStartupReady && barWindow.typeInIndex < barWindow.fullDateStr.length
                repeat: true
                onTriggered: barWindow.typeInIndex += 1
            }

            Item {
                anchors.fill: parent

                Row {
                    id: globalCenterContainer
                    anchors.centerIn: parent
                    spacing: barWindow.s(6)
                    height: barWindow.barHeight

                    Rectangle {
                        id: workspacesBox
                        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                        radius: barWindow.s(14)
                        border.width: 1
                        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                        height: barWindow.barHeight
                        clip: true

                        width: workspacesModel.count > 0 ? wsLayout.implicitWidth + barWindow.s(20) : 0

                        function toKanji(num) {
                            let n = parseInt(num);
                            if (isNaN(n) || n <= 0) return num;

                            let kanjiNums = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"];
                            let ten = "十";

                            if (n < 10) return kanjiNums[n];

                            let tensDigit = Math.floor(n / 10);
                            let onesDigit = n % 10;

                            let tensPrefix = (tensDigit > 1) ? kanjiNums[tensDigit] : "";
                            let onesSuffix = kanjiNums[onesDigit];

                            return tensPrefix + ten + onesSuffix;
                        }

                        property bool limitActive: false

                        visible: width > 0 || opacity > 0
                        opacity: workspacesModel.count > 0 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        Rectangle {
                            id: activeHighlight
                            y: (workspacesBox.height - barWindow.s(32)) / 2
                            height: barWindow.s(32)
                            radius: barWindow.s(10)
                            color: mocha.mauve
                            z: 0

                            property var activePill: (workspacesModel.activeIndex >= 0 && workspacesModel.activeIndex < wsRepeater.count)
                                                     ? wsRepeater.itemAt(workspacesModel.activeIndex)
                                                     : null

                            property real targetLeft: activePill ? (wsLayout.x + activePill.x) : 0
                            property real targetWidth: activePill ? activePill.width : 0

                            property real actualLeft: targetLeft
                            property real actualWidth: targetWidth

                            Behavior on actualLeft { NumberAnimation { id: leftAnim; duration: 250; easing.type: Easing.OutExpo } }
                            Behavior on actualWidth { NumberAnimation { id: widthAnim; duration: 250; easing.type: Easing.OutExpo } }

                            x: actualLeft
                            width: actualWidth
                            opacity: (workspacesModel.count > 0 && activePill && activePill.visible) ? 1 : 0
                        }

                        Row {
                            id: wsLayout
                            anchors.centerIn: parent
                            spacing: barWindow.s(6)

                            Repeater {
                                id: wsRepeater
                                model: workspacesModel
                                delegate: Rectangle {
                                    id: wsPill

                                    property string stateLabel: model.wsState
                                    property string wsName: model.wsId
                                    property bool isItemVisible: !isLimited && (stateLabel === "active" || stateLabel === "occupied")

                                    property bool isLimited: workspacesBox.limitActive && index >= 6
                                    visible: isItemVisible

                                    property bool isHovered: wsPillMouse.containsMouse

                                    property real targetWidth: isItemVisible ? barWindow.s(32) : 0
                                    width: targetWidth
                                    Behavior on targetWidth { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                                    height: isItemVisible ? barWindow.s(32) : 0
                                    radius: barWindow.s(10)

                                    color: isHovered ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.1) : (stateLabel === "occupied" ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.15) : "transparent")

                                    scale: isHovered && stateLabel !== "active" ? 1.08 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                                    property bool initAnimTrigger: false
                                    opacity: initAnimTrigger && isItemVisible ? 1 : 0
                                    transform: Translate {
                                        y: wsPill.initAnimTrigger ? 0 : barWindow.s(15)
                                        Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                                    }

                                    Component.onCompleted: {
                                        if (!barWindow.startupCascadeFinished) {
                                            animTimer.interval = index * 60;
                                            animTimer.start();
                                        } else {
                                            initAnimTrigger = true;
                                        }
                                    }

                                    Timer {
                                        id: animTimer
                                        running: false
                                        repeat: false
                                        onTriggered: wsPill.initAnimTrigger = true
                                    }

                                    Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 250 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: wsPill.isItemVisible ? workspacesBox.toKanji(wsName) : ""
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: barWindow.s(14)
                                        font.weight: stateLabel === "active" ? Font.Black : (stateLabel === "occupied" ? Font.Bold : Font.Medium)

                                        color: index === workspacesModel.activeIndex ? mocha.crust : (isHovered ? mocha.text : (stateLabel === "occupied" ? mocha.text : mocha.overlay0))

                                        Behavior on color { ColorAnimation { duration: 250 } }
                                    }

                                    MouseArea {
                                        id: wsPillMouse
                                        hoverEnabled: true
                                        anchors.fill: parent
                                        enabled: wsPill.isItemVisible
                                        onClicked: (event) => {
                                            Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh " + wsName])
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: mediaBox
                        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                        radius: barWindow.s(14); border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                        height: barWindow.barHeight
                        clip: true

                        width: barWindow.hasVisibleMedia ? innerMediaLayout.implicitWidth + barWindow.s(24) : 0

                        visible: width > 0
                        opacity: 1.0

                        Item {
                            id: mediaLayoutContainer
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: barWindow.s(12)
                            height: parent.height
                            width: innerMediaLayout.implicitWidth

                            // No separate Behavior/transform here anymore.
                            // mediaBox (the outer pill) already animates its
                            // own width+opacity in over 400ms — this inner
                            // Item used to layer a SECOND, slower fade
                            // (500ms opacity) and slide (700ms transform) on
                            // top of the exact same trigger. On a normal
                            // play->pause transition that never mattered
                            // (the box was already visible, so neither
                            // animation replayed), but on a fresh reload,
                            // both start from scratch at once — the box
                            // finishes its 400ms transition and sits there
                            // fully sized/colored while this inner content
                            // was still mid-fade for another 100-300ms,
                            // which is exactly the "empty box" you were
                            // seeing. Tracking hasVisibleMedia directly with
                            // no extra lag keeps content in lockstep with
                            // the box instead of trailing behind it.
                            opacity: barWindow.hasVisibleMedia ? 1.0 : 0.0

                            Row {
                                id: innerMediaLayout
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: barWindow.width < 1920 ? barWindow.s(6) : barWindow.s(10)

                                MouseArea {
                                    id: mediaInfoMouse
                                    width: infoLayout.width
                                    height: infoLayout.implicitHeight
                                    hoverEnabled: true
                                    onClicked: (event) => {
                                        Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh toggle music"])
                                    }

                                    Row {
                                        id: infoLayout
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: barWindow.s(10)

                                        scale: mediaInfoMouse.containsMouse ? 1.02 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                                        Rectangle {
                                            width: barWindow.s(32); height: barWindow.s(32); radius: barWindow.s(8)
                                            color: "transparent"
                                            border.width: barWindow.displayArtReady && barWindow.musicData.status === "Playing" ? 1 : 0
                                            border.color: mocha.mauve
                                            clip: true

                                            // Nothing renders here until real art actually
                                            // exists. Spotify's Linux client doesn't populate
                                            // mpris:artUrl in dbus metadata until the FIRST
                                            // playback event fires this session — before that
                                            // there is no URL to fetch at all, so there's
                                            // nothing legitimate to show. Rather than filling
                                            // that gap with a flat placeholder square (the
                                            // "blank black box"), we show nothing and fade the
                                            // real art in the instant it's ready (artReady flips
                                            // true — typically right after you press play once).
                                            Image {
                                                id: artImage
                                                anchors.fill: parent
                                                source: barWindow.displayArtReady && barWindow.displayArtUrl ? "file://" + barWindow.displayArtUrl : ""
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                cache: false
                                                smooth: true
                                                mipmap: true
                                                // Supersample well above the 32px display size,
                                                // scaled for the screen's actual pixel density —
                                                // a flat 32x32 sourceSize gets upscaled (blurry)
                                                // on any scaled/HiDPI output, since it was
                                                // rendering at logical pixels, not physical ones.
                                                sourceSize.width: barWindow.s(32) * 3 * (Screen.devicePixelRatio || 1)
                                                sourceSize.height: barWindow.s(32) * 3 * (Screen.devicePixelRatio || 1)
                                                opacity: status === Image.Ready ? 1 : 0
                                                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                visible: artImage.opacity > 0
                                                opacity: artImage.opacity
                                                color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.2)
                                            }
                                        }
                                        Column {
                                            // Matches the clock widget's day/date column: spacing 0
                                            // (not the old -2, which was actually overlapping the
                                            // two lines), both lines the same font size (was 13/10 —
                                            // that mismatch is what made the timestamp look small
                                            // and orphaned under a long title), and a width that
                                            // hugs the actual content instead of always reserving
                                            // maxColWidth's worth of space regardless of how short
                                            // the title is. Long titles still elide at the cap.
                                            id: mediaInfoColumn
                                            spacing: 0
                                            anchors.verticalCenter: parent.verticalCenter
                                            property real maxColWidth: barWindow.width < 1920 ? barWindow.s(140) : barWindow.s(200)
                                            width: Math.min(Math.max(titleMetrics.width, timeMetrics.width), maxColWidth)

                                            TextMetrics {
                                                id: titleMetrics
                                                font: titleText.font
                                                text: barWindow.displayTitle
                                            }
                                            TextMetrics {
                                                id: timeMetrics
                                                font: timeText.font
                                                text: barWindow.displayTime
                                            }

                                            Text {
                                                id: titleText
                                                text: barWindow.displayTitle;
                                                font.family: "JetBrains Mono";
                                                font.weight: Font.Black;
                                                font.pixelSize: barWindow.s(11);
                                                color: mocha.text;
                                                width: parent.width
                                                elide: Text.ElideRight;
                                            }
                                            Text {
                                                id: timeText
                                                text: barWindow.displayTime;
                                                font.family: "JetBrains Mono";
                                                font.weight: Font.Bold;
                                                font.pixelSize: barWindow.s(11);
                                                color: mocha.subtext0;
                                                width: parent.width
                                                elide: Text.ElideRight;
                                            }
                                        }
                                    }
                                }

                                // Cava audio visualizer — solid bars, one
                                // per frequency band, matching the plain
                                // terminal-cava look (not a segmented LED
                                // grid). Gradient across the bars kept from
                                // before. Tied to status === "Playing"
                                // specifically — width and opacity both
                                // collapse to 0 when not actually playing,
                                // so it fades away and stops taking up
                                // space rather than sitting there flat.
                                Item {
                                    id: cavaVisualizer
                                    anchors.verticalCenter: parent.verticalCenter
                                    readonly property bool activeNow: barWindow.musicData.status === "Playing"
                                    readonly property int barCount: 8
                                    readonly property real barW: barWindow.s(9)
                                    readonly property real barGap: barWindow.s(4)
                                    readonly property real maxBarH: barWindow.s(32)
                                    readonly property real fullWidth: barCount * barW + (barCount - 1) * barGap

                                    width: activeNow ? fullWidth : 0
                                    height: maxBarH
                                    opacity: activeNow ? 1.0 : 0.0
                                    visible: width > 0 || opacity > 0
                                    clip: true

                                    Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

                                    Repeater {
                                        model: cavaVisualizer.barCount
                                        delegate: Rectangle {
                                            required property int index
                                            width: cavaVisualizer.barW
                                            radius: barWindow.s(0)
                                            x: index * (cavaVisualizer.barW + cavaVisualizer.barGap)
                                            anchors.bottom: parent.bottom
                                            height: Math.max(barWindow.s(2), ((barWindow.cavaBars[index] || 0) / 100) * cavaVisualizer.maxBarH)
                                            color: barWindow.cavaBarColor(index, cavaVisualizer.barCount)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: centerBox
                        property bool isHovered: centerMouse.containsMouse
                        color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.95) : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                        radius: barWindow.s(14); border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, isHovered ? 0.15 : 0.05)
                        height: barWindow.barHeight
                        width: centerLayout.implicitWidth + barWindow.s(36)

                        property bool showLayout: false
                        opacity: showLayout ? 1 : 0
                        transform: Translate {
                            y: centerBox.showLayout ? 0 : barWindow.s(-30)
                            Behavior on y { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                        }

                        Timer {
                            running: barWindow.isStartupReady
                            interval: 150
                            onTriggered: centerBox.showLayout = true
                        }

                        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                        scale: isHovered ? 1.03 : 1.0
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                        Behavior on color { ColorAnimation { duration: 250 } }

                        MouseArea {
                            id: centerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: (event) => {
                                Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh toggle calendar"])
                            }
                        }

                        RowLayout {
                            id: centerLayout
                            anchors.centerIn: parent
                            spacing: barWindow.s(12)

                            Text {
                                text: barWindow.timeStr
                                font.family: "JetBrains Mono"
                                font.pixelSize: barWindow.s(18)
                                font.weight: Font.Black
                                color: mocha.mauve
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: barWindow.dateStr.split(',')[0] || ""
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: barWindow.s(10)
                                    font.weight: Font.Black
                                    color: mocha.text
                                    horizontalAlignment: Text.AlignLeft
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: (barWindow.dateStr.split(',')[1] || "").trim()
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: barWindow.s(10)
                                    font.weight: Font.Bold
                                    color: mocha.subtext0
                                    horizontalAlignment: Text.AlignLeft
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    Row {
                        id: rightContent
                        spacing: barWindow.s(4)

                        property bool showLayout: false
                        opacity: showLayout ? 1 : 0
                        transform: Translate {
                            x: rightContent.showLayout ? 0 : barWindow.s(30)
                            Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                        }

                        Timer {
                            running: barWindow.isStartupReady && barWindow.isDataReady
                            interval: 50
                            onTriggered: rightContent.showLayout = true
                        }

                        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                        Rectangle {
                            height: barWindow.barHeight
                            radius: barWindow.s(14)
                            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                            border.width: 1
                            color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)

                            property real targetWidth: trayRepeater.count > 0 ? trayLayout.width + barWindow.s(24) : 0
                            width: targetWidth
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }

                            visible: targetWidth > 0
                            opacity: targetWidth > 0 ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 300 } }

                            Row {
                                id: trayLayout
                                anchors.centerIn: parent
                                spacing: barWindow.s(10)

                                Repeater {
                                    id: trayRepeater
                                    model: SystemTray.items
                                    delegate: Image {
                                        id: trayIcon
                                        source: modelData.icon || ""
                                        fillMode: Image.PreserveAspectFit

                                        sourceSize: Qt.size(barWindow.s(18), barWindow.s(18))
                                        width: barWindow.s(18)
                                        height: barWindow.s(18)
                                        anchors.verticalCenter: parent.verticalCenter

                                        property bool isHovered: trayMouse.containsMouse
                                        property bool initAnimTrigger: false
                                        opacity: initAnimTrigger ? (isHovered ? 1.0 : 0.8) : 0.0
                                        scale: initAnimTrigger ? (isHovered ? 1.15 : 1.0) : 0.0

                                        Component.onCompleted: {
                                            if (!barWindow.startupCascadeFinished) {
                                                trayAnimTimer.interval = index * 50;
                                                trayAnimTimer.start();
                                            } else {
                                                initAnimTrigger = true;
                                            }
                                        }
                                        Timer {
                                            id: trayAnimTimer
                                            running: false
                                            repeat: false
                                            onTriggered: trayIcon.initAnimTrigger = true
                                        }

                                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                                        QsMenuAnchor {
                                            id: menuAnchor
                                            anchor.window: barWindow
                                            anchor.item: trayIcon
                                            menu: modelData.menu
                                        }

                                        MouseArea {
                                            id: trayMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                            onClicked: (event) => {
                                                if (event.button === Qt.LeftButton) {
                                                    if (modelData.isMenuOnly || modelData.onlyMenu) {
                                                        menuAnchor.open();
                                                    } else if (typeof modelData.activate === "function") {
                                                        modelData.activate();
                                                    }
                                                } else if (event.button === Qt.MiddleButton) {
                                                    if (typeof modelData.secondaryActivate === "function") {
                                                        modelData.secondaryActivate();
                                                    }
                                                } else if (event.button === Qt.RightButton) {
                                                    if (modelData.menu) {
                                                        menuAnchor.open();
                                                    } else if (typeof modelData.contextMenu === "function") {
                                                        modelData.contextMenu(event.x, event.y);
                                                    } else {
                                                        modelData.activate();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            height: barWindow.barHeight
                            radius: barWindow.s(14)
                            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                            border.width: 1
                            color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                            clip: true

                            width: sysLayout.implicitWidth + barWindow.s(20)

                            Row {
                                id: sysLayout
                                anchors.centerIn: parent
                                spacing: barWindow.s(8)

                                property int pillHeight: barWindow.s(34)

                                Rectangle {
                                    id: sysBatPill
                                    property bool isHovered: batMouse.containsMouse
                                    color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                                    radius: barWindow.s(10); height: sysLayout.pillHeight;
                                    clip: true

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: barWindow.s(10)
                                        opacity: 1.0
                                        Behavior on opacity { NumberAnimation { duration: 300 } }
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: mocha.mauve }
                                            GradientStop { position: 1.0; color: Qt.lighter(mocha.mauve, 1.3) }
                                        }
                                    }

                                    property real targetWidth: barWindow.isDesktop ? barWindow.s(34) : batLayoutRow.implicitWidth + barWindow.s(24)
                                    width: targetWidth
                                    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

                                    scale: isHovered ? 1.05 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    // Was gated on its own extra 200ms Timer stacked on top of
                                    // rightContent's reveal — pure added latency for no reason.
                                    // Now triggers the instant rightContent itself is shown.
                                    property bool initAnimTrigger: rightContent.showLayout
                                    opacity: initAnimTrigger ? 1 : 0
                                    transform: Translate { y: sysBatPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                    Row {
                                        id: batLayoutRow
                                        anchors.centerIn: parent
                                        spacing: barWindow.s(8)
                                        Text { anchors.verticalCenter: parent.verticalCenter; text: barWindow.isDesktop ? "" : barWindow.batIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.isDesktop ? barWindow.s(18) : barWindow.s(16); color: mocha.base; Behavior on color { ColorAnimation { duration: 300 } } }
                                        Text { anchors.verticalCenter: parent.verticalCenter; visible: !barWindow.isDesktop; text: barWindow.batPercent; font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(13); font.weight: Font.Black; color: mocha.base; Behavior on color { ColorAnimation { duration: 300 } } }
                                    }
                                    MouseArea {
                                        id: batMouse; hoverEnabled: true; anchors.fill: parent;
                                        onClicked: (event) => {
                                            Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh toggle battery"])
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: recButton
                            property bool isHovered: recMouse.containsMouse

                            color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.95) : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                            radius: barWindow.s(14)
                            border.width: 1
                            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, isHovered ? 0.15 : 0.05)

                            property real targetWidth: barWindow.isRecording ? barWindow.barHeight : 0
                            width: targetWidth
                            height: barWindow.barHeight

                            visible: targetWidth > 0 || opacity > 0
                            opacity: barWindow.isRecording ? 1.0 : 0.0
                            clip: true

                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                            Behavior on opacity { NumberAnimation { duration: 300 } }

                            scale: isHovered ? 1.05 : 1.0
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            Behavior on color { ColorAnimation { duration: 200 } }

                            Text {
                                id: recIcon
                                anchors.centerIn: parent
                                text: ""
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: barWindow.s(20)
                                color: mocha.mauve

                                SequentialAnimation on opacity {
                                    running: barWindow.isRecording && !recButton.isHovered
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                                }
                                SequentialAnimation on scale {
                                    running: barWindow.isRecording && !recButton.isHovered
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 1.15; duration: 600; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                                }
                            }

                            MouseArea {
                                id: recMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: (event) => {
                                    barWindow.isRecording = false;
                                    Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/record.sh"]);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
