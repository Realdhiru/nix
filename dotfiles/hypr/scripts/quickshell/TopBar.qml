import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: barWindow
            // Staggered position-switch handoff: when this bar loses its
            // edge, stay mapped briefly so the incoming bar's space
            // reservation lands first (correct-edge motion), then release.
            // Without this, the outgoing top strip and incoming left strip
            // animate as one top-originated move.
            visible: Config.topBarVisible && Config.topBarPosition !== "left"
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
                function toggle() {
                    Config.topBarVisible = !Config.topBarVisible;
                }
                function hide() {
                    Config.topBarVisible = false;
                }
                function show() {
                    Config.topBarVisible = true;
                }
                function setPosition(pos: string): void {
                    Config.setTopBarPosition(pos);
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
                currentWidth: Screen.width
            }

            property real baseScale: scaler.baseScale

            function s(val) {
                return scaler.s(val);
            }

            property int barHeight: s(46)

            implicitHeight: barHeight
            implicitWidth: Screen.width
            margins { top: s(2); bottom: 0; left: s(4); right: s(4) }
            exclusiveZone: barHeight - s(4)
            color: "transparent"

            Theme {
                id: mocha
            }

            readonly property color accentColor: (Config.accentColorSource && mocha[Config.accentColorSource]) ? mocha[Config.accentColorSource] : mocha.primary

            readonly property color pillBg: {
                let baseCol = Config.topbarColorSource === "glass" ? Qt.rgba(1, 1, 1, 1) : (mocha[Config.topbarColorSource] || mocha.surface1);
                return Qt.rgba(baseCol.r, baseCol.g, baseCol.b, Config.topbarPillOpacity);
            }

            readonly property color pillBgHover: {
                let baseCol = Config.topbarColorSource === "glass" ? Qt.rgba(1, 1, 1, 1) : (mocha[Config.topbarColorSource] || mocha.surface0);
                return Qt.rgba(baseCol.r, baseCol.g, baseCol.b, Config.topbarPillHoverOpacity);
            }

            readonly property color pillBorder: (Config.borderWidth > 0 && Config.borderOpacity > 0) ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, Config.borderOpacity) : "transparent"

            readonly property color pillBorderHover: (Config.borderWidth > 0 && Config.borderOpacity > 0) ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, Config.borderOpacity * 2) : "transparent"

            property bool isRecording: false

            property bool updateAvailable: false
            property bool forceUpdateShow: false
            property bool isUpdateVisible: updateAvailable || forceUpdateShow

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

            FileView {
                id: updateFileView
                path: Caching.getCacheDir('updater') + "/update_pending"
                watchChanges: true
                onLoadedChanged: barWindow.updateAvailable = updateFileView.loaded
                onTextChanged: barWindow.updateAvailable = updateFileView.loaded
            }

            readonly property bool isDesktop: !SysData.hasBattery

            property bool isStartupReady: false
            Timer { interval: 10; running: true; onTriggered: barWindow.isStartupReady = true }

            property bool startupCascadeFinished: false
            Timer { interval: 300; running: true; onTriggered: barWindow.startupCascadeFinished = true }

            // Render rightContent immediately; live telemetry is bound reactively to SysData
            property bool isDataReady: true

            property string timeStr: ""
            property string fullDateStr: ""
            property int typeInIndex: 0
            property string dateStr: fullDateStr.substring(0, typeInIndex)

            readonly property string batPercent: SysData.batCapacity + "%"
            // Battery/AC: single authoritative source = SysData singleton's
            // always-on udevadm event watcher. TopBar no longer runs its own
            // duplicate batteryPoller/batteryWaiter pair.
            property bool acOnline: SysData.acOnline
            property string batIcon: _batIcon(SysData.batCapacity, SysData.acOnline)
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

            ListModel {
                id: workspacesModel
                property int activeIndex: 0
            }

            // ── Shared music/cava telemetry (MusicState singleton, sole owner) ──
            // Live aliases — not copies. MusicState owns the MPRIS followers,
            // music_info.sh, json watcher, cava, and timers; this bar only reads.
            property var musicData: MusicState.musicData
            property var cavaBars: MusicState.cavaBars
            readonly property bool isMediaActive: MusicState.isMediaActive
            readonly property bool isSpotify: MusicState.isSpotify
            readonly property string displayTitle: MusicState.displayTitle
            readonly property string displayTime: MusicState.displayTime
            readonly property string displayArtUrl: MusicState.displayArtUrl
            readonly property bool displayArtReady: MusicState.displayArtReady
            readonly property bool hasVisibleMedia: MusicState.hasVisibleMedia

            function _hexToRgb01(hex) {
                let h = hex.replace("#", "");
                return {
                    r: parseInt(h.substring(0, 2), 16) / 255,
                    g: parseInt(h.substring(2, 4), 16) / 255,
                    b: parseInt(h.substring(4, 6), 16) / 255
                };
            }

            function cavaBarColor(barIndex, barCount, segIndex, segCount) {
                let mode = Config.cavaGradient || "soft";
                let topColor = barWindow.accentColor;
                let t = (segCount <= 1) ? 1.0 : (segIndex / (segCount - 1));

                if (mode === "soft") {
                    // Soft monochromatic luminescence: gentle 0.35 tint at base rising to full 1.0 radiance at peaks
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

            property int batCap: parseInt(barWindow.batPercent) || 0
            property bool isCharging: barWindow.acOnline
            property color batDynamicColor: {
                if (isCharging) return barWindow.accentColor;
                if (batCap <= 20) return barWindow.accentColor;
                return mocha.text;
            }

            function updateNativeWorkspaces() {
                let focusedId = (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id) ? Hyprland.focusedWorkspace.id : 1;
                let occupiedMap = {};
                let maxWs = 6;
                if (focusedId > maxWs) maxWs = focusedId;

                // 1. Authoritative scan of live toplevel windows
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

                // 2. Discover occupied workspaces from workspace models
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

            Timer {
                id: wsStartupSyncTimer
                interval: 100
                running: false
                repeat: false
                onTriggered: barWindow.updateNativeWorkspaces()
            }

            Component.onCompleted: {
                barWindow.updateNativeWorkspaces();
                Qt.callLater(barWindow.updateNativeWorkspaces);
                wsStartupSyncTimer.start();
                barWindow.checkRecording();
            }

            // (Music pipeline lives in MusicState singleton — sole owner.)

            // (1s interpolation lives in MusicState singleton.)

            // (Drift timer + MPRIS followers live in MusicState singleton.)

            // (Cava process lives in MusicState singleton.)

            // NOTE: the old audioPoller/networkPoller/btPoller fetch-wait
            // chains (pw-mon / nmcli monitor / dbus-monitor) were removed:
            // their state properties had no UI consumers. Live volume and
            // brightness feedback is the osd.sh → notification → NotifTicker
            // OSD path; network/bluetooth popups own their own fetchers.

            // Clock shows HH:mm only, so it fires once per minute instead of
            // once per second — re-armed just past each minute boundary.
            // (Presentation clock; this is the one legitimate timer here.)
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
                    if (barWindow.typeInIndex >= barWindow.fullDateStr.length) {
                        barWindow.typeInIndex = barWindow.fullDateStr.length;
                    }
                    interval = 60000 - (d.getSeconds() * 1000 + d.getMilliseconds()) + 50;
                    restart();
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
                        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, Config.effectivePopupOpacity)
                        radius: barWindow.s(14)
                        border.width: Math.max(1, Config.borderWidth)
                        border.color: Config.borderWidth > 0 ? barWindow.pillBorder : Qt.rgba(255, 255, 255, Config.glassSpecular)
                        Behavior on color { ColorAnimation { duration: 250 } }
                        Behavior on border.color { ColorAnimation { duration: 250 } }
                        height: barWindow.barHeight
                        clip: true

                        // Anti-bleed base layer
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, Config.antiBleedOpacity)
                            z: -1
                        }


                        width: workspacesModel.count > 0 ? wsLayout.implicitWidth + barWindow.s(20) : 0

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                        }

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
                            color: Qt.rgba(barWindow.accentColor.r, barWindow.accentColor.g, barWindow.accentColor.b, 0.78)
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
                                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                    property bool initAnimTrigger: false
                                    opacity: initAnimTrigger && isItemVisible ? 1 : 0
                                    transform: Translate {
                                        y: wsPill.initAnimTrigger ? 0 : barWindow.s(10)
                                        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                    }

                                    Component.onCompleted: {
                                        if (!barWindow.startupCascadeFinished) {
                                            animTimer.interval = index * 25;
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

                                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 180 } }

                                    Text {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: barWindow.s(-1)
                                        text: wsPill.isItemVisible ? workspacesBox.toKanji(wsName) : ""
                                        font.family: "Noto Sans CJK JP, JetBrains Mono"
                                        font.pixelSize: barWindow.s(14)
                                        font.weight: stateLabel === "active" ? Font.Black : (stateLabel === "occupied" ? Font.Bold : Font.Medium)
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter

                                        color: index === workspacesModel.activeIndex ? mocha.crust : (isHovered ? mocha.text : (stateLabel === "occupied" ? mocha.text : mocha.overlay0))

                                        Behavior on color { ColorAnimation { duration: 250 } }
                                    }

                                    MouseArea {
                                        id: wsPillMouse
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
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
                        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, Config.effectivePopupOpacity)
                        radius: barWindow.s(14)
                        border.width: Math.max(1, Config.borderWidth)
                        border.color: Config.borderWidth > 0 ? barWindow.pillBorder : Qt.rgba(255, 255, 255, Config.glassSpecular)
                        Behavior on color { ColorAnimation { duration: 250 } }
                        Behavior on border.color { ColorAnimation { duration: 250 } }
                        height: barWindow.barHeight
                        clip: true

                        // Anti-bleed base layer
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, Config.antiBleedOpacity)
                            z: -1
                        }


                        readonly property bool activeNow: barWindow.musicData.status === "Playing" && barWindow.hasVisibleMedia
                        width: activeNow ? infoLayout.implicitWidth + barWindow.s(24) : 0
                        Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

                        visible: width > 0
                        opacity: activeNow ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

                        MouseArea {
                            id: mediaInfoMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (event) => {
                                Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh toggle music"])
                            }


                            property real lastWheelTime: 0
                            onWheel: (wheel) => {
                                let now = Date.now();
                                if (now - lastWheelTime < 50) return;
                                lastWheelTime = now;
                                if (wheel.angleDelta.y > 0) {
                                    Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/osd.sh vol-up"]);
                                } else if (wheel.angleDelta.y < 0) {
                                    Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/osd.sh vol-down"]);
                                }
                            }
                        }

                        Item {
                            id: mediaLayoutContainer
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: barWindow.s(12)
                            height: parent.height
                            width: infoLayout.implicitWidth
                            opacity: parent.activeNow ? 1.0 : 0.0

                                Row {
                                    id: infoLayout
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: barWindow.s(10)

                                    scale: mediaInfoMouse.containsMouse ? 1.02 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                                    Item {
                                         id: cavaVisualizer
                                         anchors.bottom: mediaInfoColumn.bottom
                                         anchors.bottomMargin: Math.round(timeText.implicitHeight - timeText.baselineOffset)
                                         readonly property int barCount: 8
                                         readonly property int segCount: 8
                                         readonly property real barW: barWindow.s(8)
                                         readonly property real barGap: barWindow.s(2)
                                         readonly property real segH: barWindow.s(2)
                                         readonly property real segGap: barWindow.s(1)
                                         readonly property real maxBarH: segCount * (segH + segGap) - segGap
                                         readonly property real fullWidth: barCount * barW + (barCount - 1) * barGap

                                         readonly property bool activeNow: barWindow.musicData.status === "Playing"
                                         width: activeNow ? fullWidth : 0
                                         height: maxBarH
                                         visible: width > 0
                                         opacity: activeNow ? 1.0 : 0.0
                                         Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                         Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                                         Repeater {
                                             model: cavaVisualizer.barCount
                                             delegate: Item {
                                                 id: barCol
                                                 required property int index
                                                 width: cavaVisualizer.barW
                                                 height: cavaVisualizer.maxBarH
                                                 x: index * (cavaVisualizer.barW + cavaVisualizer.barGap)
                                                 anchors.bottom: parent.bottom

                                                 property int rawVal: barWindow.cavaBars[index] || 0
                                                 property int activeSegs: Math.round((rawVal / 100) * cavaVisualizer.segCount)

                                                 Repeater {
                                                     model: cavaVisualizer.segCount
                                                     delegate: Rectangle {
                                                         id: segRect
                                                         required property int index
                                                         width: cavaVisualizer.barW
                                                         height: cavaVisualizer.segH
                                                         radius: barWindow.s(0.5)
                                                         anchors.bottom: parent.bottom
                                                         anchors.bottomMargin: index * (cavaVisualizer.segH + cavaVisualizer.segGap)

                                                         property bool isLit: index < barCol.activeSegs
                                                         visible: isLit
                                                         opacity: 1.0

                                                         color: barWindow.cavaBarColor(barCol.index, cavaVisualizer.barCount, index, cavaVisualizer.segCount)
                                                     }
                                                 }
                                             }
                                         }
                                    }
                                    Column {
                                        id: mediaInfoColumn
                                        spacing: barWindow.s(2)
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.max(timeMetrics.width + barWindow.s(2), barWindow.s(81))

                                        TextMetrics {
                                            id: titleMetrics
                                            font: titleText.font
                                            text: barWindow.displayTitle
                                        }
                                        TextMetrics {
                                            id: timeMetrics
                                            font: timeText.font
                                        }

                                        Item {
                                            id: titleClipRect
                                            width: parent.width
                                            height: titleText.implicitHeight
                                            clip: true

                                            property int marqueeSpacing: barWindow.s(30)
                                            property bool isOver: titleText.implicitWidth > width

                                            Item {
                                                id: marqueeContainer
                                                height: parent.height

                                                Row {
                                                    spacing: titleClipRect.marqueeSpacing
                                                    Text {
                                                        id: titleText
                                                        text: barWindow.displayTitle
                                                        font.family: "JetBrains Mono"
                                                        font.weight: Font.Black
                                                        font.pixelSize: barWindow.s(11)
                                                        color: mocha.text

                                                        onTextChanged: {
                                                            marqueeContainer.x = 0;
                                                            if (implicitWidth > titleClipRect.width) {
                                                                titleAnim.restart();
                                                            } else {
                                                                titleAnim.stop();
                                                            }
                                                        }
                                                    }
                                                    Text {
                                                        id: titleTextClone
                                                        text: barWindow.displayTitle
                                                        font.family: "JetBrains Mono"
                                                        font.weight: Font.Black
                                                        font.pixelSize: barWindow.s(11)
                                                        color: mocha.text
                                                        visible: titleClipRect.isOver
                                                    }
                                                }

                                                SequentialAnimation on x {
                                                    id: titleAnim
                                                    loops: Animation.Infinite
                                                    running: titleClipRect.isOver

                                                    PauseAnimation { duration: 2500 }

                                                    NumberAnimation {
                                                        from: 0
                                                        to: -(titleText.implicitWidth + titleClipRect.marqueeSpacing)
                                                        duration: (titleText.implicitWidth + titleClipRect.marqueeSpacing) * 30
                                                    }

                                                    PropertyAction { target: marqueeContainer; property: "x"; value: 0 }
                                                }
                                            }
                                        }

                                        Text {
                                            id: timeText
                                            text: barWindow.displayTime
                                            font.family: "JetBrains Mono"
                                            font.weight: Font.Bold
                                            font.pixelSize: barWindow.s(10.5)
                                            color: mocha.text
                                            width: parent.width
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                        }



                        Rectangle {
                            id: centerBox
                            property bool isHovered: centerMouse.containsMouse
                            property bool notifActive: NotifTicker.tickerVisible
                            color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, Config.effectivePopupOpacity)
                            radius: barWindow.s(14)
                            border.width: Math.max(1, Config.borderWidth)
                            border.color: Config.borderWidth > 0 ? (isHovered ? barWindow.pillBorderHover : barWindow.pillBorder) : Qt.rgba(255, 255, 255, Config.glassSpecular)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            // Anti-bleed base layer
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, Config.antiBleedOpacity)
                                z: -1
                            }

                        height: barWindow.barHeight
                        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutExpo } }
                        width: (centerBox.notifActive ? notifLayout.implicitWidth : centerLayout.implicitWidth) + barWindow.s(36)
                        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutExpo } }
                        clip: true

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
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            enabled: !centerBox.notifActive || NotifTicker.tickerNotif.actionsJson === "[]"
                            onClicked: (event) => {
                                if (centerBox.notifActive) {
                                    if (event.button === Qt.RightButton) {
                                        if (NotifTicker.tickerNotif) NotifTicker.dismiss(NotifTicker.tickerNotif.uid);
                                    } else {
                                        NotifTicker.invokeDefault();
                                    }
                                } else {
                                    Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh toggle calendar"])
                                }

                            }
                        }

                        RowLayout {
                            id: centerLayout
                            anchors.centerIn: parent
                            spacing: barWindow.s(12)
                            opacity: !centerBox.notifActive ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                            Text {
                                text: barWindow.timeStr
                                renderType: Text.NativeRendering
                                font.family: "JetBrains Mono"
                                font.pixelSize: barWindow.s(18)
                                font.weight: Font.Black
                                color: mocha[Config.clockColorSource] || barWindow.accentColor
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: barWindow.dateStr.split(',')[0] || ""
                                    renderType: Text.NativeRendering
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: barWindow.s(10)
                                    font.weight: Font.Black
                                    color: mocha[Config.textColorSource] || mocha.text
                                    horizontalAlignment: Text.AlignLeft
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: (barWindow.dateStr.split(',')[1] || "").trim()
                                    renderType: Text.NativeRendering
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: barWindow.s(10)
                                    font.weight: Font.Bold
                                    color: mocha.subtext0
                                    horizontalAlignment: Text.AlignLeft
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        RowLayout {
                            id: notifLayout
                            anchors.centerIn: parent
                            spacing: barWindow.s(10)
                            opacity: centerBox.notifActive ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                            transform: Translate {
                                x: centerBox.notifActive ? 0 : barWindow.s(-24)
                                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            }

                            property var n: NotifTicker.tickerNotif
                            property var actionArray: {
                                try { return n && n.actionsJson ? JSON.parse(n.actionsJson) : []; }
                                catch (e) { return []; }
                            }

                            property bool isOsd: n && n.appName === "System" && (n.summary === "Volume" || n.summary === "Brightness" || n.summary === "Microphone")

                            RowLayout {
                                visible: !notifLayout.isOsd
                                spacing: barWindow.s(10)

                                Image {
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: notifLayout.n && notifLayout.n.iconPath !== ""
                                    source: notifLayout.n && notifLayout.n.iconPath !== "" ? notifLayout.n.iconPath : ""
                                    sourceSize: Qt.size(barWindow.s(20), barWindow.s(20))
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }

                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: notifLayout.n ? notifLayout.n.appName : ""
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Medium
                                    font.pixelSize: barWindow.s(10)
                                    color: mocha.overlay1
                                }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "\u2022"
                                    font.pixelSize: barWindow.s(10)
                                    color: mocha.overlay0
                                }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: notifLayout.n ? notifLayout.n.summary : ""
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Bold
                                    font.pixelSize: barWindow.s(13)
                                    color: mocha.text
                                }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: text !== ""
                                    text: notifLayout.n ? notifLayout.n.body : ""
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Medium
                                    font.pixelSize: barWindow.s(13)
                                    color: mocha.subtext0
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: barWindow.s(6)
                                    visible: notifLayout.actionArray.length > 0

                                    Repeater {
                                        model: notifLayout.actionArray
                                        delegate: Rectangle {
                                            height: barWindow.s(24)
                                            width: actLabel.implicitWidth + barWindow.s(14)
                                            radius: barWindow.s(7)
                                            property bool isPrimary: index === 0
                                            color: isPrimary ? (actMa.containsMouse ? mocha.blue : Qt.darker(mocha.blue, 1.2)) : (actMa.containsMouse ? mocha.surface2 : mocha.surface1)
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            Text {
                                                id: actLabel
                                                anchors.centerIn: parent
                                                text: modelData.text || "Action"
                                                font.family: "JetBrains Mono"
                                                font.weight: Font.Bold
                                                font.pixelSize: barWindow.s(10)
                                                color: isPrimary ? mocha.crust : mocha.text
                                            }

                                            MouseArea {
                                                id: actMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: NotifTicker.invokeAction(modelData.id)
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    height: barWindow.s(22)
                                    width: barWindow.s(22)
                                    radius: barWindow.s(11)
                                    color: closeMa.containsMouse ? mocha.surface2 : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: barWindow.s(11)
                                        color: closeMa.containsMouse ? mocha.red : mocha.overlay1
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        id: closeMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (notifLayout.n) {
                                                NotifTicker.dismiss(notifLayout.n.uid);
                                            }
                                        }
                                    }
                                }
                            }

                                Item {
                                    id: osdContainer
                                    visible: notifLayout.isOsd
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: osdRowLayout.implicitWidth
                                    implicitHeight: osdRowLayout.implicitHeight

                                    RowLayout {
                                        id: osdRowLayout
                                        anchors.fill: parent
                                        spacing: barWindow.s(16)

                                        Text {
                                            Layout.alignment: Qt.AlignVCenter
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: barWindow.s(18)
                                            color: mocha.text
                                            text: {
                                                if (!notifLayout.n) return "";
                                                if (notifLayout.n.summary === "Volume") {
                                                    if (notifLayout.n.body.indexOf("Muted") !== -1 || notifLayout.n.body === "Muted") return "󰝟";
                                                    return "󰕾";
                                                }
                                                if (notifLayout.n.summary === "Brightness") return "󰃠";
                                                if (notifLayout.n.summary === "Microphone") {
                                                    if (notifLayout.n.body.indexOf("Muted") !== -1 || notifLayout.n.body === "Muted") return "󰍭";
                                                    return "󰍬";
                                                }
                                                return "";
                                            }
                                        }

                                    Item {
                                        id: sliderContainer
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.preferredWidth: barWindow.s(200)
                                        Layout.preferredHeight: barWindow.s(16)
                                        
                                        property bool isMuted: notifLayout.n && (notifLayout.n.body.indexOf("Muted") !== -1 || notifLayout.n.body === "Muted")

                                        property real pct: {
                                            if (!notifLayout.n) return 0;
                                            let v = parseInt(notifLayout.n.body);
                                            return isNaN(v) ? 0 : Math.max(0, Math.min(100, v)) / 100.0;
                                        }
                                        
                                        // Track background
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: height / 2
                                            color: mocha.surface1
                                        }
                                        
                                        // Fill and Thumb container (for shared animation)
                                        Item {
                                            anchors.fill: parent
                                            
                                            property real fillW: sliderContainer.pct > 0 ? Math.max(parent.height, sliderContainer.pct * parent.width) : 0
                                            Behavior on fillW { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                                            
                                            Rectangle {
                                                width: parent.fillW
                                                height: parent.height
                                                radius: height / 2
                                                color: sliderContainer.isMuted ? mocha.subtext1 : barWindow.accentColor
                                            }
                                            
                                            Rectangle {
                                                width: parent.height + barWindow.s(4)
                                                height: parent.height + barWindow.s(4)
                                                radius: width / 2
                                                color: sliderContainer.isMuted ? mocha.subtext1 : barWindow.accentColor
                                                border.color: mocha.surface2
                                                border.width: barWindow.s(1)
                                                
                                                x: Math.max(0, Math.min(sliderContainer.width - width, parent.fillW - width / 2))
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignVCenter
                                        text: notifLayout.n ? notifLayout.n.body : ""
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.Bold
                                        font.pixelSize: barWindow.s(14)
                                        color: mocha.text
                                    }
                                }

                                MouseArea {
                                    id: osdMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (notifLayout.n) {
                                            if (notifLayout.n.summary === "Brightness") {
                                                Quickshell.execDetached(["bash", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh toggle quickactions"])
                                            }
                                        }
                                    }
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

                        Rectangle {
                            height: barWindow.barHeight
                            radius: barWindow.s(14)
                            border.width: Math.max(1, Config.borderWidth)
                            border.color: Config.borderWidth > 0 ? barWindow.pillBorder : Qt.rgba(255, 255, 255, Config.glassSpecular)
                            color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, Config.effectivePopupOpacity)
                            clip: true
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            // Anti-bleed base layer
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, Config.antiBleedOpacity)
                                z: -1
                            }

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
                                        color: Qt.rgba(barWindow.accentColor.r, barWindow.accentColor.g, barWindow.accentColor.b, 0.78)
                                    }

                                    property real targetWidth: barWindow.isDesktop ? barWindow.s(34) : batLayoutRow.implicitWidth + barWindow.s(24)
                                    width: targetWidth
                                    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

                                    scale: isHovered ? 1.05 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    property bool initAnimTrigger: rightContent.showLayout
                                    opacity: initAnimTrigger ? 1 : 0
                                    transform: Translate { y: sysBatPill.initAnimTrigger ? 0 : barWindow.s(10); Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } } }
                                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                                    Row {
                                        id: batLayoutRow
                                        anchors.centerIn: parent
                                        spacing: barWindow.s(8)
                                        Text { anchors.verticalCenter: parent.verticalCenter; text: barWindow.isDesktop ? "" : barWindow.batIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.isDesktop ? barWindow.s(18) : barWindow.s(16); color: mocha.crust; Behavior on color { ColorAnimation { duration: 300 } } }
                                        Text { anchors.verticalCenter: parent.verticalCenter; visible: !barWindow.isDesktop; text: barWindow.batPercent; font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(13); font.weight: Font.Black; color: mocha.crust; Behavior on color { ColorAnimation { duration: 300 } } }
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

                            color: isHovered ? barWindow.pillBgHover : barWindow.pillBg
                            radius: barWindow.s(14)
                            border.width: Math.max(1, Config.borderWidth)
                            border.color: Config.borderWidth > 0 ? (isHovered ? barWindow.pillBorderHover : barWindow.pillBorder) : Qt.rgba(255, 255, 255, Config.glassSpecular)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            // Anti-bleed base layer
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, Config.antiBleedOpacity)
                                z: -1
                            }

                            property real targetWidth: barWindow.isRecording ? barWindow.barHeight : 0
                            width: targetWidth
                            height: barWindow.barHeight

                            visible: width > 0 || opacity > 0
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
                                color: barWindow.accentColor

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
