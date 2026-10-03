import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: barWindow
            visible: Config.topBarVisible && Config.topBarPosition === "left"
            required property var modelData
            screen: modelData

            IpcHandler {
                target: "sidebar"
                function forceReload() {
                    Quickshell.reload(true);
                }
                function queueReload() {
                    Quickshell.reload(true);
                }
                function refreshMusic() {
                    musicRefreshDebounce.restart();
                }
                function toggle() {
                    Config.topBarVisible = !Config.topBarVisible;
                }
                function hide() {
                    Config.topBarVisible = false;
                }
                function show() {
                    Config.topBarVisible = true;
                }
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: false
            }

            Scaler {
                id: scaler
                currentWidth: Screen.width
            }

            property real baseScale: scaler.baseScale

            function s(val) {
                return scaler.s(val);
            }

            property int barThickness: s(46)

            // ── Auto-Hide Architecture ──
            property bool autohide: Config.barAutohide !== undefined ? Config.barAutohide : false
            property int autohideTimeout: 1000

            HoverHandler {
                id: barHover
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            }

            Timer {
                id: hideTimer
                interval: barWindow.autohideTimeout
            }

            function checkHideTimer() {
                if (!barHover.hovered && barWindow.autohide && !(Config.isPopupOpen !== undefined && Config.isPopupOpen)) {
                    hideTimer.restart();
                } else {
                    hideTimer.stop();
                }
            }

            Connections {
                target: barHover
                function onHoveredChanged() { barWindow.checkHideTimer(); }
            }

            Connections {
                target: Config
                function onIsPopupOpenChanged() { barWindow.checkHideTimer(); }
            }

            readonly property bool isRevealed: !autohide || barHover.hovered || hideTimer.running || (Config.isPopupOpen !== undefined && Config.isPopupOpen)

            implicitWidth: barThickness
            implicitHeight: Screen.height
            margins { top: s(4); bottom: s(4); left: s(4); right: 0 }
            exclusiveZone: autohide ? 0 : (barThickness - s(2))
            color: "transparent"
            WlrLayershell.namespace: "quickshell"
            WlrLayershell.layer: WlrLayer.Top

            Theme {
                id: mocha
            }

            readonly property color accentColor: (Config.accentColorSource && mocha[Config.accentColorSource]) ? mocha[Config.accentColorSource] : mocha.primary

            readonly property color cardBg: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, Config.effectivePopupOpacity)
            readonly property color cardBorder: (Config.borderWidth > 0 && Config.borderOpacity > 0)
                ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, Config.borderOpacity)
                : Qt.rgba(255, 255, 255, Config.glassSpecular)

            // ── Dynamic JSON Modules ──
            property var activeModules: ({
                "workspaces": true,
                "focus": true,
                "media": true,
                "timedate": true,
                "weather": true,
                "sysmon": true,
                "quickstatus": true,
                "tray": true,
                "record": true,
                "battery": true
            })

            function isModuleActive(name) {
                return activeModules[name] !== false;
            }

            // ── Clock & Date ──
            property string timeStr: ""
            property string fullDateStr: ""
            property string dayNumStr: ""
            property string monthStr: ""

            Timer {
                id: clockTimer
                interval: 0
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    let d = new Date();
                    barWindow.timeStr = Qt.formatDateTime(d, "HH:mm");
                    barWindow.fullDateStr = Qt.formatDateTime(d, "dddd, MMMM dd");
                    barWindow.dayNumStr = Qt.formatDateTime(d, "dd");
                    barWindow.monthStr = Qt.formatDateTime(d, "MMM");
                    interval = 60000 - (d.getSeconds() * 1000 + d.getMilliseconds()) + 50;
                    restart();
                }
            }

            // ── Recording state ──
            property bool isRecording: false
            FileView {
                id: recFileView
                path: Quickshell.env("HOME") + "/.cache/quickshell/recording/rec_pid"
                watchChanges: true
                onLoadedChanged: barWindow.checkRecording()
                onTextChanged: barWindow.checkRecording()
            }
            function checkRecording() {
                let txt = (recFileView.text() || "").trim();
                barWindow.isRecording = (txt.length > 0);
            }

            // ── Battery / AC state (SysData singleton) ──
            readonly property bool isDesktop: !SysData.hasBattery
            readonly property int batCap: SysData.batCapacity
            readonly property bool isCharging: SysData.acOnline
            readonly property string batIcon: _batIcon(SysData.batCapacity, SysData.acOnline)
            function _batIcon(percent, online) {
                if (online) {
                    if (percent >= 90) return "󰂅";
                    if (percent >= 80) return "󰂋";
                    if (percent >= 60) return "󰂊";
                    if (percent >= 40) return "󰢞";
                    if (percent >= 20) return "󰂆";
                    return "󰢜";
                }
                if (percent >= 90) return "󰁹";
                if (percent >= 80) return "󰂂";
                if (percent >= 70) return "󰂁";
                if (percent >= 60) return "󰂀";
                if (percent >= 50) return "󰁿";
                if (percent >= 40) return "󰁾";
                if (percent >= 30) return "󰁽";
                if (percent >= 20) return "󰁼";
                if (percent >= 10) return "󰁻";
                return "󰁺";
            }
            readonly property string iconFont: "JetBrainsMono Nerd Font, Iosevka Nerd Font, Symbols Nerd Font"
            readonly property color batDynamicColor: barWindow.accentColor

            // ── Workspaces Model & Native Bindings ──
            ListModel {
                id: workspacesModel
                property int activeIndex: 0
                ListElement { wsId: "1"; wsState: "active" }
                ListElement { wsId: "2"; wsState: "empty" }
                ListElement { wsId: "3"; wsState: "empty" }
                ListElement { wsId: "4"; wsState: "empty" }
                ListElement { wsId: "5"; wsState: "empty" }
                ListElement { wsId: "6"; wsState: "empty" }
            }

            function updateNativeWorkspaces() {
                let focusedId = (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id) ? Hyprland.focusedWorkspace.id : 1;
                let occupiedMap = {};
                let maxWs = 6;
                if (focusedId > maxWs) maxWs = focusedId;

                if (Hyprland.toplevels && Hyprland.toplevels.values) {
                    let tls = Hyprland.toplevels.values;
                    for (let i = 0; i < tls.length; i++) {
                        let tl = tls[i];
                        let w = (tl && tl.workspace) ? tl.workspace.id : 0;
                        if (w > 0) {
                            occupiedMap[w] = true;
                            if (w > maxWs) maxWs = w;
                        }
                    }
                }

                if (Hyprland.workspaces && Hyprland.workspaces.values) {
                    let values = Hyprland.workspaces.values;
                    for (let i = 0; i < values.length; i++) {
                        let ws = values[i];
                        if (ws && ws.id > 0) {
                            let winCount = 0;
                            if (ws.lastIpcObject && ws.lastIpcObject.windows !== undefined) {
                                winCount = ws.lastIpcObject.windows;
                            } else if (ws.toplevels && ws.toplevels.values) {
                                winCount = ws.toplevels.values.length;
                            } else if (ws.windows !== undefined) {
                                winCount = ws.windows;
                            }
                            if (winCount > 0) {
                                occupiedMap[ws.id] = true;
                                if (ws.id > maxWs) maxWs = ws.id;
                            }
                        }
                    }
                }

                let newActive = -1;
                let totalWs = maxWs;

                while (workspacesModel.count < totalWs) {
                    let nextId = (workspacesModel.count + 1).toString();
                    workspacesModel.append({ "wsId": nextId, "wsState": "empty" });
                }
                while (workspacesModel.count > totalWs) {
                    workspacesModel.remove(workspacesModel.count - 1);
                }

                for (let i = 1; i <= totalWs; i++) {
                    let st = (i === focusedId) ? "active" : (occupiedMap[i] ? "occupied" : "empty");
                    let idx = i - 1;
                    if (workspacesModel.get(idx).wsState !== st) {
                        workspacesModel.setProperty(idx, "wsState", st);
                    }
                    if (i === focusedId) newActive = idx;
                }

                if (newActive !== -1 && workspacesModel.activeIndex !== newActive) {
                    workspacesModel.activeIndex = newActive;
                }
            }

            Connections {
                target: Hyprland
                function onFocusedWorkspaceChanged() { barWindow.updateNativeWorkspaces(); }
                function onActiveToplevelChanged() { Qt.callLater(barWindow.updateNativeWorkspaces); }
                function onRawEvent(name, data) {
                    if (name === "workspace" || name === "createworkspace" || name === "destroyworkspace"
                        || name === "focusedmon" || name === "moveworkspace" || name === "moveworkspacev2"
                        || name === "openwindow" || name === "closewindow" || name === "movewindow" || name === "movewindowv2"
                        || name === "renameworkspace") {
                        Qt.callLater(barWindow.updateNativeWorkspaces);
                    }
                }
            }

            Component.onCompleted: {
                barWindow.updateNativeWorkspaces();
                Qt.callLater(barWindow.updateNativeWorkspaces);
                barWindow.checkRecording();
                weatherPoller.running = true;
                barWindow.parseMusicFile();
            }

            // ── Focused Window Tracking ──
            readonly property string focusedTitle: (Hyprland.activeToplevel && Hyprland.activeToplevel.title) ? Hyprland.activeToplevel.title : ""
            readonly property string focusedAppId: (Hyprland.activeToplevel && Hyprland.activeToplevel.waylandAppId) ? Hyprland.activeToplevel.waylandAppId : ""
            readonly property bool hasFocusedWindow: focusedTitle !== ""

            // ── Weather Data Process ──
            property var weatherData: null
            readonly property string weatherIcon: (weatherData && weatherData.current_icon) ? weatherData.current_icon : ""
            readonly property string weatherTemp: {
                if (!weatherData || !weatherData.current_temp) return "";
                let n = Math.round(Number(weatherData.current_temp));
                return isNaN(n) ? "" : n + "°";
            }
            readonly property color weatherHex: (weatherData && weatherData.current_hex) ? weatherData.current_hex : mocha.yellow

            Process {
                id: weatherPoller
                command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/calendar/weather.sh", "--json"]
                running: false
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try { barWindow.weatherData = JSON.parse(txt); } catch(e) {}
                        }
                    }
                }
            }

            Timer {
                interval: 900000 // 15 mins
                running: true
                repeat: true
                onTriggered: {
                    weatherPoller.running = false;
                    weatherPoller.running = true;
                }
            }

            // ── Music / MPRIS Live Processes ──
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

            Timer {
                id: musicRefreshDebounce
                interval: 80
                repeat: false
                onTriggered: {
                    musicForceRefresh.running = false;
                    Qt.callLater(() => { musicForceRefresh.running = true; });
                }
            }

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
                                barWindow.musicData = newData;
                            } catch(e) {}
                        }
                    }
                }
            }

            FileView {
                id: musicFileView
                path: Caching.getRunDir('music') + "/music_info.json"
                watchChanges: true
                onLoadedChanged: barWindow.parseMusicFile()
                onTextChanged: barWindow.parseMusicFile()
            }

            function parseMusicFile() {
                let txt = (musicFileView.text() || "").trim();
                if (txt !== "") {
                    try {
                        let newData = JSON.parse(txt);
                        barWindow.musicData = newData;
                    } catch(e) {}
                }
            }

            // 1s timeline advance
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

            Timer {
                interval: 45000
                running: barWindow.isMediaActive && barWindow.musicData.status === "Playing"
                repeat: true
                onTriggered: {
                    musicRefreshDebounce.restart();
                }
            }

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
                                let cur = Object.assign({}, barWindow.musicData || {});
                                cur.status = status;
                                if (title !== "") cur.title = title;
                                barWindow.musicData = cur;
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
                            let cur = Object.assign({}, barWindow.musicData || {});
                            if (cur.status !== status) {
                                cur.status = status;
                                barWindow.musicData = cur;
                                musicRefreshDebounce.restart();
                            }
                        }
                    }
                }
            }

            // ── CAVA Visualizer Process ──
            property var cavaBars: [0, 0, 0, 0, 0, 0, 0, 0]

            Process {
                id: cavaProcess
                running: barWindow.musicData.status === "Playing"
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
                        if (out && out.length === 8) barWindow.cavaBars = out;
                    }
                }
                onRunningChanged: {
                    if (!running) barWindow.cavaBars = [0, 0, 0, 0, 0, 0, 0, 0];
                }
            }

            function cavaBarColor(barIndex, barCount, segIndex, segCount) {
                let mode = Config.cavaGradient || "soft";
                let topColor = barWindow.accentColor;
                let t = (segCount <= 1) ? 1.0 : (segIndex / (segCount - 1));

                if (mode === "soft") {
                    let alpha = 0.35 + (0.65 * t);
                    return Qt.rgba(topColor.r, topColor.g, topColor.b, alpha);
                }

                let bottomColor = topColor;
                if (mode === "warm") {
                    bottomColor = (mocha.peach && mocha.peach !== mocha.surface0) ? mocha.peach : (mocha.mauve || topColor);
                } else if (mode === "ivory") {
                    bottomColor = mocha.subtext0 || mocha.text;
                } else if (mode === "sapphire") {
                    bottomColor = (mocha.sapphire && mocha.sapphire !== mocha.surface0) ? mocha.sapphire : (mocha.blue || mocha.subtext0);
                } else if (mocha[mode]) {
                    bottomColor = mocha[mode];
                }

                return Qt.rgba(
                    Math.max(0.0, Math.min(1.0, bottomColor.r + (topColor.r - bottomColor.r) * t)),
                    Math.max(0.0, Math.min(1.0, bottomColor.g + (topColor.g - bottomColor.g) * t)),
                    Math.max(0.0, Math.min(1.0, bottomColor.b + (topColor.b - bottomColor.b) * t)),
                    1.0
                );
            }

            // ── Audio / Volume Service ──
            PwObjectTracker {
                objects: Pipewire.nodes.values
            }

            readonly property var currentAudioSink: Pipewire.defaultAudioSink
            readonly property int sysVolume: (currentAudioSink && currentAudioSink.audio) ? Math.round(currentAudioSink.audio.volume * 100) : 50
            readonly property bool isMuted: (currentAudioSink && currentAudioSink.audio) ? currentAudioSink.audio.muted : false
            property bool showVolPct: false
            property bool volFeedbackReady: false
            readonly property string volIcon: (isMuted || sysVolume === 0) ? "󰝟" : (sysVolume >= 60 ? "󰕾" : (sysVolume > 20 ? "󰖀" : "󰕿"))

            Timer {
                id: volInitDelay
                interval: 800
                running: true
                onTriggered: barWindow.volFeedbackReady = true
            }

            onSysVolumeChanged: {
                if (volFeedbackReady) {
                    showVolPct = true;
                    volPctTimer.restart();
                }
            }

            onIsMutedChanged: {
                if (volFeedbackReady) {
                    showVolPct = true;
                    volPctTimer.restart();
                }
            }

            Timer {
                id: volPctTimer
                interval: 1200
                repeat: false
                onTriggered: barWindow.showVolPct = false
            }

            // ── Main Content Wrapper (With Smooth Auto-Hide Translation) ──
            Item {
                id: barContent
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: barWindow.barThickness
                x: barWindow.isRevealed ? 0 : -(barWindow.barThickness - barWindow.s(4))
                opacity: barWindow.isRevealed ? 1.0 : 0.0
                Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                // ── Top Zone: Workspaces & Window Focus ──
                Column {
                    id: topZone
                    anchors.top: parent.top
                    anchors.topMargin: barWindow.s(16)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: barWindow.s(8)

                    // Clock / Date Card (Enlarged, roomy fonts, no blinking dot)
                    Rectangle {
                        id: centerBox
                        visible: barWindow.isModuleActive("timedate")
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: barWindow.barThickness
                        height: centerCol.implicitHeight + barWindow.s(24)
                        radius: barWindow.s(14)
                        color: barWindow.cardBg
                        border.width: Math.max(1, Config.borderWidth)
                        border.color: clockMouse.containsMouse ? barWindow.accentColor : barWindow.cardBorder
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, Config.antiBleedOpacity)
                            z: -1
                        }

                        Column {
                            id: centerCol
                            anchors.centerIn: parent
                            spacing: barWindow.s(4)

                            // Hours (Enlarged to 19px JetBrains Mono Black, dynamic wallpaper accent)
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: barWindow.timeStr.split(":")[0] || "00"
                                font.family: "JetBrains Mono"
                                font.pixelSize: barWindow.s(19)
                                font.weight: Font.Black
                                color: barWindow.accentColor
                            }

                            // Minutes (Enlarged to 19px JetBrains Mono Black, text white)
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: barWindow.timeStr.split(":")[1] || "00"
                                font.family: "JetBrains Mono"
                                font.pixelSize: barWindow.s(19)
                                font.weight: Font.Black
                                color: mocha.text
                            }

                            // Thin accent divider line
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: barWindow.s(20)
                                height: barWindow.s(2)
                                radius: barWindow.s(1)
                                color: Qt.rgba(barWindow.accentColor.r, barWindow.accentColor.g, barWindow.accentColor.b, 0.45)
                            }

                            // Day of Month (Enlarged to 14px, secondary clock palette)
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: barWindow.dayNumStr
                                font.family: "JetBrains Mono"
                                font.pixelSize: barWindow.s(14)
                                font.weight: Font.Bold
                                color: (mocha[Config.clockColorSource] && Config.clockColorSource !== "text") ? mocha[Config.clockColorSource] : (mocha.sapphire || mocha.text)
                            }

                            // Month (Enlarged to 12px)
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: barWindow.monthStr
                                font.family: "JetBrains Mono"
                                font.pixelSize: barWindow.s(12)
                                font.weight: Font.Bold
                                color: mocha.subtext0
                            }
                        }

                        MouseArea {
                            id: clockMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh toggle calendar"]);
                            }
                        }
                    }

                    // Music Pill (Chunky CAVA, directly below Clock)
                    Rectangle {
                        id: mediaBox
                        readonly property bool activeNow: barWindow.isModuleActive("media") && barWindow.musicData.status === "Playing"
                        visible: height > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: barWindow.barThickness
                        height: activeNow ? (cavaVisualizer.fullH + barWindow.s(22)) : 0
                        radius: barWindow.s(14)
                        color: barWindow.cardBg
                        border.width: Math.max(1, Config.borderWidth)
                        border.color: barWindow.cardBorder
                        clip: true
                        opacity: activeNow ? 1.0 : 0.0

                        Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, Config.antiBleedOpacity)
                            z: -1
                        }

                        // Vertical Columns CAVA Visualizer (Bouncing bottom to top)
                        Item {
                            id: cavaVisualizer
                            anchors.centerIn: parent
                            readonly property int colCount: 5
                            readonly property int segCount: 8
                            readonly property real barW: barWindow.s(4.4)
                            readonly property real barGap: barWindow.s(1.6)
                            readonly property real segH: barWindow.s(2.6)
                            readonly property real segGap: barWindow.s(1.2)
                            readonly property real fullW: colCount * barW + (colCount - 1) * barGap
                            readonly property real fullH: segCount * segH + (segCount - 1) * segGap

                            width: fullW
                            height: fullH

                            Row {
                                anchors.centerIn: parent
                                spacing: cavaVisualizer.barGap

                                Repeater {
                                    model: cavaVisualizer.colCount
                                    delegate: Item {
                                        id: colItem
                                        required property int index
                                        width: cavaVisualizer.barW
                                        height: cavaVisualizer.fullH

                                        // Sample 5 columns across CAVA 8-frequency bins
                                        readonly property var binMap: [0, 1, 3, 5, 7]
                                        property int rawVal: barWindow.cavaBars[binMap[index]] || 0
                                        property int activeSegs: Math.round((rawVal / 100) * cavaVisualizer.segCount)

                                        Column {
                                            anchors.fill: parent
                                            spacing: cavaVisualizer.segGap

                                            // In Column, index 0 is top, index 7 is bottom.
                                            // segFromBottom (0=bottom, 7=top) grows bottom to top.
                                            Repeater {
                                                model: cavaVisualizer.segCount
                                                delegate: Rectangle {
                                                    required property int index
                                                    width: cavaVisualizer.barW
                                                    height: cavaVisualizer.segH
                                                    radius: barWindow.s(0.8)

                                                    readonly property int segFromBottom: (cavaVisualizer.segCount - 1) - index
                                                    property bool isLit: segFromBottom < colItem.activeSegs
                                                    opacity: isLit ? 1.0 : 0.15
                                                    color: barWindow.cavaBarColor(colItem.index, cavaVisualizer.colCount, segFromBottom, cavaVisualizer.segCount)
                                                    Behavior on opacity { NumberAnimation { duration: 80 } }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh toggle music"])
                        }
                    }
                }

                // ── Center Zone: Workspaces Capsule (Centered on vertical bar) ──
                Item {
                    id: centerZone
                    anchors.centerIn: parent
                    width: barWindow.barThickness
                    height: workspacesBox.height
                    visible: workspacesBox.visible

                    // Workspaces Capsule (Serpantinum style)
                    Rectangle {
                        id: workspacesBox
                        visible: barWindow.isModuleActive("workspaces") && workspacesModel.count > 0
                        anchors.centerIn: parent
                        width: barWindow.barThickness
                        height: wsCol.implicitHeight + barWindow.s(16)
                        implicitHeight: height
                        radius: barWindow.s(14)
                        color: barWindow.cardBg
                        border.width: Math.max(1, Config.borderWidth)
                        border.color: barWindow.cardBorder
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, Config.antiBleedOpacity)
                            z: -1
                        }

                        // Sliding Active Highlight
                        Rectangle {
                            id: activeHighlight
                            z: 0
                            x: (parent.width - width) / 2
                            width: barWindow.s(28)
                            radius: barWindow.s(8)
                            color: barWindow.accentColor

                            property int curIdx: workspacesModel.activeIndex
                            property real targetTop: curIdx >= 0 ? (wsCol.y + curIdx * (barWindow.s(28) + wsCol.spacing)) : 0
                            y: targetTop
                            height: curIdx >= 0 ? barWindow.s(28) : 0
                            visible: curIdx >= 0

                            Behavior on y {
                                enabled: barWindow.visible
                                NumberAnimation { duration: 320; easing.type: Easing.OutQuint }
                            }
                            Behavior on height { NumberAnimation { duration: 200 } }
                        }

                        Column {
                            id: wsCol
                            anchors.centerIn: parent
                            spacing: barWindow.s(4)

                            Repeater {
                                model: workspacesModel
                                delegate: Item {
                                    id: wsPill
                                    required property int index
                                    required property var modelData

                                    width: barWindow.s(28)
                                    height: barWindow.s(28)

                                    readonly property bool isActive: modelData.wsState === "active"
                                    readonly property bool isOccupied: modelData.wsState === "occupied"
                                    readonly property bool isHovered: wsMouse.containsMouse

                                    Text {
                                        anchors.centerIn: parent
                                        text: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"][index] || (index + 1)
                                        font.family: "Noto Sans CJK JP, JetBrainsMono Nerd Font"
                                        font.pixelSize: barWindow.s(12)
                                        font.weight: wsPill.isActive ? Font.Black : (wsPill.isOccupied ? Font.Bold : Font.Medium)
                                        color: wsPill.isActive ? mocha.crust : (wsPill.isHovered ? mocha.text : (wsPill.isOccupied ? mocha.text : mocha.subtext0))
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        id: wsMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh " + (index + 1)])
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            property real lastWheelTime: 0
                            onWheel: (wheel) => {
                                let now = Date.now();
                                if (now - lastWheelTime < 50) return;
                                lastWheelTime = now;
                                if (wheel.angleDelta.y > 0) {
                                    Quickshell.execDetached(["bash", "-c", "hyprctl dispatch workspace e-1"]);
                                } else if (wheel.angleDelta.y < 0) {
                                    Quickshell.execDetached(["bash", "-c", "hyprctl dispatch workspace e+1"]);
                                }
                            }
                        }
                    }
                }

                // ── Bottom Zone: System Tray, Sunset, Volume, Network, Battery ──
                Column {
                    id: bottomZone
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: barWindow.s(16)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: barWindow.s(8)

                    // System Tray Card (At the top of bottom icons)
                    Rectangle {
                        id: trayBox
                        property var filteredTrayItems: {
                            let raw = (SystemTray.items && SystemTray.items.values) ? SystemTray.items.values : [];
                            let res = [];
                            for (let i = 0; i < raw.length; i++) {
                                let item = raw[i];
                                if (!item) continue;
                                let idStr = (item.id || "").toLowerCase();
                                let titleStr = (item.title || "").toLowerCase();
                                if (idStr.includes("blueman") || idStr.includes("bluetooth") ||
                                    idStr.includes("kdeconnect") || idStr.includes("kde connect") ||
                                    titleStr.includes("blueman") || titleStr.includes("bluetooth") ||
                                    titleStr.includes("kdeconnect") || titleStr.includes("kde connect")) continue;
                                res.push(item);
                            }
                            return res;
                        }
                        visible: barWindow.isModuleActive("tray") && filteredTrayItems.length > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: barWindow.barThickness
                        height: visible ? (trayCol.implicitHeight + barWindow.s(12)) : 0
                        radius: barWindow.s(14)
                        color: barWindow.cardBg
                        border.width: Math.max(1, Config.borderWidth)
                        border.color: barWindow.cardBorder
                        clip: false

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, Config.antiBleedOpacity)
                            z: -1
                        }

                        Column {
                            id: trayCol
                            anchors.centerIn: parent
                            spacing: barWindow.s(6)

                            Repeater {
                                model: trayBox.filteredTrayItems
                                delegate: Image {
                                    id: trayIconItem
                                    required property var modelData
                                    width: barWindow.s(18)
                                    height: barWindow.s(18)
                                    source: modelData.icon || ""
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize: Qt.size(barWindow.s(18), barWindow.s(18))

                                    property bool isHovered: trayMouse.containsMouse
                                    opacity: isHovered ? 1.0 : 0.85
                                    scale: isHovered ? 1.15 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                    Behavior on scale { NumberAnimation { duration: 150 } }

                                    QsMenuAnchor {
                                        id: menuAnchor
                                        anchor.window: barWindow
                                        anchor.item: trayIconItem
                                        menu: modelData.menu
                                    }

                                    MouseArea {
                                        id: trayMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: (event) => {
                                            if (event.button === Qt.LeftButton) {
                                                if (modelData.isMenuOnly || modelData.onlyMenu) {
                                                    menuAnchor.open();
                                                } else if (typeof modelData.activate === "function") {
                                                    modelData.activate();
                                                }
                                            } else if (event.button === Qt.RightButton) {
                                                if (modelData.menu) {
                                                    menuAnchor.open();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Hyprsunset / Night Light Pill
                    Rectangle {
                        id: sunsetBox
                        visible: true
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: barWindow.barThickness
                        height: barWindow.s(36)
                        radius: barWindow.s(14)
                        color: barWindow.cardBg
                        border.width: Math.max(1, Config.borderWidth)
                        border.color: sunsetMouse.containsMouse ? barWindow.accentColor : barWindow.cardBorder
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, Config.antiBleedOpacity)
                            z: -1
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰖙"
                            font.family: barWindow.iconFont
                            font.pixelSize: barWindow.s(16)
                            color: sunsetMouse.containsMouse ? mocha.text : barWindow.accentColor
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: sunsetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/toggle_sunset.sh"]);
                                } else {
                                    Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh toggle sunset"]);
                                }
                            }
                        }
                    }

                    // Volume Pill (Theme accent color)
                    Rectangle {
                        id: volBox
                        visible: barWindow.isModuleActive("volume")
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: barWindow.barThickness
                        height: barWindow.s(36)
                        radius: barWindow.s(14)
                        color: barWindow.cardBg
                        border.width: Math.max(1, Config.borderWidth)
                        border.color: volMouse.containsMouse ? barWindow.accentColor : barWindow.cardBorder
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, Config.antiBleedOpacity)
                            z: -1
                        }

                        Text {
                            anchors.centerIn: parent
                            text: barWindow.showVolPct ? (barWindow.isMuted ? "MUT" : barWindow.sysVolume + "%") : barWindow.volIcon
                            font.family: barWindow.showVolPct ? "JetBrains Mono" : barWindow.iconFont
                            font.pixelSize: barWindow.showVolPct ? barWindow.s(10.5) : barWindow.s(16)
                            font.weight: barWindow.showVolPct ? Font.Black : Font.Normal
                            color: barWindow.isMuted ? mocha.red : barWindow.accentColor
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: volMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    let sink = barWindow.currentAudioSink;
                                    if (sink && sink.audio) {
                                        sink.audio.muted = !sink.audio.muted;
                                    } else {
                                        Quickshell.execDetached(["bash", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"]);
                                    }
                                } else {
                                    Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh toggle volume"]);
                                }
                            }
                            onWheel: (wheel) => {
                                let sink = barWindow.currentAudioSink;
                                if (sink && sink.audio) {
                                    let step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                    let newVol = Math.max(0.0, Math.min(1.0, Math.round((sink.audio.volume + step) * 100) / 100));
                                    sink.audio.volume = newVol;
                                    if (sink.audio.muted && step > 0) sink.audio.muted = false;
                                } else {
                                    if (wheel.angleDelta.y > 0) {
                                        Quickshell.execDetached(["bash", "-c", "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"]);
                                    } else {
                                        Quickshell.execDetached(["bash", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"]);
                                    }
                                }
                            }
                        }
                    }

                    // Network Pill (Discrete WiFi and Bluetooth halves)
                    Rectangle {
                        id: netBox
                        visible: barWindow.isModuleActive("network")
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: barWindow.barThickness
                        height: barWindow.s(66)
                        radius: barWindow.s(14)
                        color: barWindow.cardBg
                        border.width: Math.max(1, Config.borderWidth)
                        border.color: (wifiMouse.containsMouse || btMouse.containsMouse) ? barWindow.accentColor : barWindow.cardBorder
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, Config.antiBleedOpacity)
                            z: -1
                        }

                        Column {
                            anchors.fill: parent

                            // Wifi Half
                            Item {
                                width: parent.width
                                height: barWindow.s(32)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰤨"
                                    font.family: barWindow.iconFont
                                    font.pixelSize: barWindow.s(15)
                                    color: wifiMouse.containsMouse ? mocha.text : barWindow.accentColor
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    id: wifiMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh open network wifi"])
                                }
                            }

                            // Divider
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - barWindow.s(12)
                                height: 1
                                color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.12)
                            }

                            // Bluetooth Half
                            Item {
                                width: parent.width
                                height: barWindow.s(32)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰂯"
                                    font.family: barWindow.iconFont
                                    font.pixelSize: barWindow.s(15)
                                    color: btMouse.containsMouse ? mocha.text : barWindow.accentColor
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    id: btMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh open network bt"])
                                }
                            }
                        }
                    }

                    // Recording Pill
                    Rectangle {
                        id: recButton
                        visible: barWindow.isModuleActive("record") && barWindow.isRecording
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: barWindow.barThickness
                        height: barWindow.isRecording ? barWindow.s(36) : 0
                        radius: barWindow.s(14)
                        color: recMouse.containsMouse ? mocha.surface2 : mocha.surface1
                        border.width: Math.max(1, Config.borderWidth)
                        border.color: barWindow.accentColor
                        opacity: barWindow.isRecording ? 1.0 : 0.0
                        clip: true

                        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 250 } }

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font.family: barWindow.iconFont
                            font.pixelSize: barWindow.s(18)
                            color: mocha.red

                            SequentialAnimation on scale {
                                running: barWindow.isRecording
                                loops: Animation.Infinite
                                NumberAnimation { to: 1.15; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                            }
                        }

                        MouseArea {
                            id: recMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                barWindow.isRecording = false;
                                Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/record.sh"]);
                            }
                        }
                    }

                    // Battery Pill (Dynamic icon only, no percentage text)
                    Rectangle {
                        id: batBox
                        visible: barWindow.isModuleActive("battery")
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: barWindow.barThickness
                        height: barWindow.s(38)
                        radius: barWindow.s(14)
                        color: barWindow.cardBg
                        border.width: Math.max(1, Config.borderWidth)
                        border.color: batMouse.containsMouse ? barWindow.accentColor : barWindow.cardBorder
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, Config.antiBleedOpacity)
                            z: -1
                        }

                        Text {
                            anchors.centerIn: parent
                            text: barWindow.isDesktop ? "" : barWindow.batIcon
                            font.family: barWindow.iconFont
                            font.pixelSize: barWindow.s(18)
                            color: barWindow.batDynamicColor
                            Behavior on color { ColorAnimation { duration: 250 } }
                        }

                        MouseArea {
                            id: batMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh toggle battery"])
                        }
                    }
                }
            }
        }
    }
}
