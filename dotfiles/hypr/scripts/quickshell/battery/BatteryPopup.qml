import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import "../"

Item {
    id: window

    property real layoutWidth
    property real layoutHeight
    width: layoutWidth
    height: layoutHeight

    property var notifModel: NotifTicker.notifModel
    property var liveNotifs: NotifTicker.liveNotifs

    onNotifModelChanged: Qt.callLater(window.enforceNotificationSort)

    onVisibleChanged: {
        if (visible) {
            window.syncBrightness();
        }
    }
    
    Connections {
        target: window.notifModel
        function onCountChanged() {
            Qt.callLater(window.enforceNotificationSort);
        }
    }

    function enforceNotificationSort() {
        if (!notifModel || notifModel.count <= 1) return;
        let firstNonAction = -1;
        for (let i = 0; i < notifModel.count; i++) {
            let item = notifModel.get(i);
            let hasAction = false;
            try {
                let parsed = item.actionsJson ? JSON.parse(item.actionsJson) : [];
                hasAction = parsed.length > 0;
            } catch(e) {}

            if (hasAction) {
                if (firstNonAction !== -1 && i > firstNonAction) {
                    notifModel.move(i, firstNonAction, 1);
                    firstNonAction++;
                }
            } else {
                if (firstNonAction === -1) {
                    firstNonAction = i;
                }
            }
        }
    }

    Scaler {
        id: scaler
        currentWidth: Screen.width
    }
    
    function s(val) { 
        return scaler.s(val); 
    }

    Theme { id: _theme }
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay0: _theme.overlay0
    readonly property color overlay1: _theme.overlay1
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    
    readonly property color mauve: _theme.mauve
    readonly property color pink: _theme.pink
    readonly property color red: _theme.red
    readonly property color maroon: _theme.maroon
    readonly property color peach: _theme.peach
    readonly property color yellow: _theme.yellow
    readonly property color green: _theme.green
    readonly property color teal: _theme.teal
    readonly property color sapphire: _theme.sapphire
    readonly property color blue: _theme.blue
    readonly property color primary: _theme.primary

    // Single source of truth: SysData.qml (a persistent singleton that
    // keeps polling and running profile automation even while this popup
    // is closed). This popup no longer keeps its own copies, so it can't
    // disagree with the topbar or silently stop automating when closed.
    readonly property int batCapacity: SysData.batCapacity
    readonly property string batStatus: SysData.batStatus
    readonly property string powerProfile: SysData.powerProfile
    
    property int upHours: SysData.batHours
    property int upMins: SysData.batMins

    property real sysVolume: 0
    property bool sysMuted: false
    property real sysBrightness: 0
    
    property string currentUserName: Quickshell.env("USER") || ""
    property bool dndEnabled: false
    // Coffee state lives in SysData (single source); this popup only reads
    // SysData.coffeeActive and writes via SysData.setCoffee().


    property var collapsedGroups: ({})

    // Keyboard navigation for the action row only. `selectedActionIndex`
    // tracks which capsule (Lock / Suspend / Reboot / Shutdown) is active;
    // `keyboardActive` gates the visible highlight so mouse-only users see
    // zero visual change. Focus flow stays untouched: Main.qml already
    // forceActiveFocus()es this popup; no other focus changes here.
    property int selectedActionIndex: 0
    property bool keyboardActive: false

    // Keyboard navigation confined to the action row (Lock, Suspend,
    // Reboot, Shutdown capsules). Left/Right step between them, Enter
    // starts the same fill-and-execute activation the mouse uses, and
    // Up/Down are intentionally ignored. Focus is not touched here --
    // the popup already holds focus (see Main.qml's focusTimer).
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            window.keyboardActive = true;
            let dir = event.key === Qt.Key_Left ? -1 : 1;
            window.selectedActionIndex = (window.selectedActionIndex + dir + 4) % 4;
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            window.keyboardActive = true;
            window.activateSelectedAction();
            event.accepted = true;
        }
    }

    // Mirrors the mouse path: starts the selected capsule's fill animation
    // through the same single activation entry point the MouseArea uses.
    // Delegates' beginAction() handles drain-stop + fill-start; the fill's
    // onFinished then covers triggering, flash and the exit timer.
    function activateSelectedAction() {
        let del = actionRowRepeater.itemAt(window.selectedActionIndex);
        if (del) del.beginAction();
    }

    // Called by Main.qml whenever this cached popup is shown again.
    // Entry/exit motion is a single property-driven fade+scale on the card
    // root (shown), so only the action capsules need a state reset here.
    function showWidget() {
        for (var i = 0; i < actionRowRepeater.count; i++) {
            let cap = actionRowRepeater.itemAt(i);
            if (cap) {
                cap.triggered = false;
                cap.fillLevel = 0;
                cap.flashOpacity = 0;
            }
        }
    }

    function toggleGroup(groupName) {
        let temp = Object.assign({}, collapsedGroups);
        temp[groupName] = !temp[groupName];
        collapsedGroups = temp;
    }

    function isCollapsed(groupName) {
        return collapsedGroups[groupName] === true;
    }

    property bool isDraggingVol: false
    property bool isDraggingBri: false

    Timer { id: volSyncDelay; interval: 600; onTriggered: window.isDraggingVol = false; }
    Timer { id: briSyncDelay; interval: 600; onTriggered: window.isDraggingBri = false; }

    // Keyed off real AC-online state (SysData.acOnline), not the status
    // string -- a charge-threshold-capped battery reports "Not charging"
    // once it hits the cap even while plugged in.
    readonly property bool isCharging: SysData.acOnline

    readonly property color batColorStart: isCharging ? window.primary : (batCapacity >= 30 ? window.primary : window.red)
    readonly property color batColorEnd: Qt.lighter(batColorStart, 1.15)

    readonly property color profileStart: powerProfile === "performance" ? window.primary : (powerProfile === "balanced" ? window.primary : (powerProfile === "power-saver" ? window.subtext0 : window.surface2))
    readonly property color profileEnd: Qt.lighter(profileStart, 1.15)

    readonly property color ambientPrimary: window.batColorStart
    readonly property color ambientSecondary: isCharging ? window.primary : (batCapacity >= 70 ? window.mauve : (batCapacity >= 30 ? window.peach : window.maroon))

    property real animCapacity: SysData.batCapacity
    Behavior on animCapacity { NumberAnimation { duration: Motion.moveMs; easing.type: Motion.moveEasing } }
    
    onAnimCapacityChanged: batCanvas.requestPaint()
    onBatColorStartChanged: batCanvas.requestPaint()

    // Drive the capacity-ring animation off SysData's single source of
    // truth instead of a locally-polled copy.
    Connections {
        target: SysData
        function onBatCapacityChanged() { window.animCapacity = SysData.batCapacity; }
    }
    Component.onCompleted: {
        window.animCapacity = SysData.batCapacity;
        let curBri = parseInt((briView.text() || "").trim());
        let maxBri = parseInt((maxBriView.text() || "").trim()) || 400;
        if (!isNaN(curBri) && maxBri > 0) window.sysBrightness = Math.round((curBri / maxBri) * 100);
        let a = Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null;
        if (a) {
            window.sysVolume = Math.round(a.volume * 100);
            window.sysMuted = a.muted;
        }
        // Coffee state is owned by SysData (always live) — no per-open sync.
    }

    // =========================================================================
    // POWER PROFILE AUTOMATION (DYNAMIC ARCHITECTURE)
    // =========================================================================
    // Automation moved to SysData.qml (a persistent singleton), since it
    // must keep running whether or not this popup is open. This is now
    // just a thin pass-through so the profile-picker buttons below don't
    // need to change.
    function setPowerProfile(name, isManual) {
        SysData.setPowerProfile(name, isManual);
    }

    Process {
        id: dndInit
        running: true
        command: ["bash", "-c", "bash '" + Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/state_ctl.sh' get modes.dnd"]
        stdout: StdioCollector {
            onStreamFinished: {
                window.dndEnabled = (this.text.trim() === "true" || this.text.trim() === "1");
            }
        }
    }


    Process {
        id: sysPoller
        command: [
            "bash", "-c",
            `
            cap=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1 || echo '0')
            stat=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1 || echo 'Unknown')
            
            prof=$(cat /tmp/qs_power_profile 2>/dev/null)
            if [ -z "$prof" ]; then
                epp=$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null || echo 'balance_performance')
                case "$epp" in
                    performance) prof='performance' ;;
                    power) prof='power-saver' ;;
                    *) prof='balanced' ;;
                esac
            fi

            en=$(cat /sys/class/power_supply/BAT*/energy_now 2>/dev/null | head -n1 || cat /sys/class/power_supply/BAT*/charge_now 2>/dev/null | head -n1 || echo '0')
            ef=$(cat /sys/class/power_supply/BAT*/energy_full 2>/dev/null | head -n1 || cat /sys/class/power_supply/BAT*/charge_full 2>/dev/null | head -n1 || echo '1')
            pw=$(cat /sys/class/power_supply/BAT*/power_now 2>/dev/null | head -n1 || cat /sys/class/power_supply/BAT*/current_now 2>/dev/null | head -n1 || echo '0')

            if [ "$pw" -gt 500000 ] 2>/dev/null; then
                if [ "$stat" = 'Charging' ]; then
                    rem=$(( (ef - en) * 3600 / pw ))
                else
                    rem=$(( en * 3600 / pw ))
                fi
                if [ "$rem" -gt 356400 ]; then rem=356400; fi
            else
                rem=0
            fi

            vol="0 on"
            bri=$(brightnessctl -m 2>/dev/null | awk -F, '{print substr($4, 1, length($4)-1)}' || echo '0')

            echo "$cap"
            echo "$stat"
            echo "$prof"
            echo "$rem"
            echo "$vol"
            echo "$bri"
            `
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                if (lines.length >= 6) {
                    let remSeconds = parseInt(lines[3]) || 0;
                    window.upHours = Math.floor(remSeconds / 3600);
                    window.upMins = Math.floor((remSeconds % 3600) / 60);
                }
            }
        }
    }

    FileView {
        id: briView
        path: Config.backlightDevice + "/actual_brightness"
    }

    FileView {
        id: maxBriView
        path: Config.backlightDevice + "/max_brightness"
    }

    function syncBrightness() {
        if (!window.isDraggingBri) {
            briView.reload();
            maxBriView.reload();
            let cur = parseInt((briView.text() || "").trim());
            let max = parseInt((maxBriView.text() || "").trim()) || 400;
            if (!isNaN(cur) && max > 0) {
                window.sysBrightness = Math.round((cur / max) * 100);
            }
        }
    }

    Process {
        id: udevBriWatcher
        command: ["udevadm", "monitor", "--subsystem-match=backlight"]
        running: window.visible
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                window.syncBrightness();
            }
        }
    }

    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        function onVolumeChanged() {
            let a = Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null;
            if (a && !window.isDraggingVol) {
                window.sysVolume = Math.round(a.volume * 100);
            }
        }
        function onMutedChanged() {
            let a = Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null;
            if (a) {
                window.sysMuted = a.muted;
            }
        }
    }

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            let a = Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null;
            if (a) {
                if (!window.isDraggingVol) {
                    window.sysVolume = Math.round(a.volume * 100);
                }
                window.sysMuted = a.muted;
            }
        }
    }

    // Popup-local telemetry refresh (cap/profile/time-remaining/vol/bri).
    // Gated to visibility: this popup stays cached in Main.qml's
    // widgetCache after close, so a bare running:true kept spawning bash
    // every 1.5s forever while hidden.
    Timer {
        interval: 8000; running: window.visible; repeat: true; triggeredOnStart: true;
        onTriggered: {
            sysPoller.running = false;
            sysPoller.running = true;
        }
    }

    // Single card-level enter/exit: one fade + one scale on the card root.
    // shown mirrors the window visibility Main.qml tracks (visible:true on
    // executeSwitch, false at preload / when the widget leaves the stack).
    readonly property bool shown: visible

    function clearGroup(appName) {
        if (!notifModel) return;
        for (let i = notifModel.count - 1; i >= 0; i--) {
            if (notifModel.get(i).appName === appName) {
                let uid = notifModel.get(i).uid;
                if (window.liveNotifs && window.liveNotifs[uid]) {
                    delete window.liveNotifs[uid];
                }
                notifModel.remove(i);
            }
        }
    }

    Item {
        anchors.fill: parent
        scale: window.shown ? 1.0 : 0.96
        opacity: window.shown ? 1.0 : 0.0

        Behavior on opacity { NumberAnimation { duration: window.shown ? Motion.enterMs : Motion.exitMs; easing.type: window.shown ? Motion.enterEasing : Motion.exitEasing } }
        Behavior on scale { NumberAnimation { duration: window.shown ? Motion.enterMs : Motion.exitMs; easing.type: window.shown ? Motion.enterEasing : Motion.exitEasing } }

        Rectangle {
            id: mainCardRect
            anchors.fill: parent
            radius: window.s(20)
            color: Qt.rgba(window.base.r, window.base.g, window.base.b, Config.effectivePopupOpacity)
            border.color: "transparent"
            border.width: 0
            clip: true

            // Anti-bleed base
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Qt.rgba(window.crust.r, window.crust.g, window.crust.b, Config.antiBleedOpacity)
                z: -1
            }


            Rectangle {
                width: parent.width * 0.8; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + window.s(150)
                y: parent.height / 2 - height / 2
                opacity: 0.08
                color: window.ambientPrimary
                Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
            }

            Rectangle {
                width: parent.width * 0.9; height: width; radius: width / 2
                x: parent.width / 2 - width / 2
                y: (parent.height / 2 - height / 2) - window.s(100)
                opacity: 0.06
                color: window.ambientSecondary
                Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
            }

            Item {
                anchors.fill: parent

                Item {
                    anchors.fill: parent
                    
                    Repeater {
                        model: 3
                        Rectangle {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: window.s(-140)
                            width: window.s(320) + (index * window.s(170))
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.color: window.ambientSecondary
                            border.width: 1
                            Behavior on border.color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                            opacity: 0.06 - (index * 0.02)
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    z: 1

                    Rectangle {
                        anchors.centerIn: centralCore
                        width: centralCore.width + window.s(45)
                        height: width
                        radius: width / 2
                        color: centralCore.isDangerState ? window.red : window.ambientPrimary
                        opacity: centralCore.isDangerState ? 0.25 : 0.0
                        z: 0
                        Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                    }

                    Rectangle {
                        id: centralCore
                        width: window.s(260)
                        height: width
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: window.s(-140)
                        radius: width / 2
                        z: 1
                        
                        property bool isDangerState: !window.isCharging && window.batCapacity < 15

                        border.color: Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.40)
                        border.width: 1

                        color: "transparent"

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: window.maroon
                            opacity: centralCore.isDangerState ? 0.15 : 0.0
                            Behavior on opacity { NumberAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                        }

                        Item {
                            anchors.fill: parent

                            Canvas {
                                id: batCanvas
                                anchors.fill: parent
                                rotation: 180 
                                
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    
                                    var centerX = width / 2;
                                    var centerY = height / 2;
                                    var radius = (width / 2) - window.s(18); 
                                    var endAngle = (window.animCapacity / 100) * 2 * Math.PI;
                                    
                                    ctx.lineCap = "round";
                                    
                                    ctx.lineWidth = window.s(10);
                                    ctx.beginPath();
                                    ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
                                    ctx.strokeStyle = _theme.isLightMode ? Qt.rgba(window.crust.r, window.crust.g, window.crust.b, 0.40).toString() : Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.35).toString();
                                    ctx.stroke();
                                    
                                    var fillGrad = ctx.createLinearGradient(0, height, width, 0);
                                    fillGrad.addColorStop(0, window.batColorStart.toString());
                                    fillGrad.addColorStop(1, window.batColorEnd.toString());

                                    ctx.globalAlpha = 1.0;
                                    ctx.lineWidth = window.s(14);
                                    ctx.beginPath();
                                    ctx.arc(centerX, centerY, radius, 0, endAngle);
                                    ctx.strokeStyle = fillGrad;
                                    ctx.stroke();
                                }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: window.s(1)
                                
                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: window.s(8)
                                    
                                    Text {
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: window.s(28)
                                        color: window.batColorStart
                                        text: SysData.batIcon(window.batCapacity, window.isCharging)
                                        Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                    }
                                    
                                    Text {
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.Black
                                        font.pixelSize: window.s(52)
                                        color: window.text
                                        text: Math.round(window.animCapacity) + "%" 
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Bold
                                    font.pixelSize: window.s(13)
                                    
                                    color: window.isCharging
                                            ? window.primary
                                            : (centralCore.isDangerState ? window.red : window.subtext0)

                                    text: (window.batStatus === "Not charging" && window.isCharging) ? "CHARGED" : window.batStatus.toUpperCase()
                                    Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: window.s(4)
                                    spacing: window.s(6)
                                    visible: (window.upHours > 0 || window.upMins > 0)

                                    Rectangle {
                                        radius: window.s(6)
                                        color: Qt.rgba(window.text.r, window.text.g, window.text.b, 0.08)
                                        border.color: Qt.alpha(window.surface1, 0.3)
                                        border.width: Config.borderWidth
                                        implicitWidth: timeTextRow.implicitWidth + window.s(12)
                                        implicitHeight: window.s(20)

                                        Row {
                                            id: timeTextRow
                                            anchors.centerIn: parent
                                            spacing: window.s(4)

                                            Text {
                                                text: (window.upHours > 0 ? (window.upHours + "h " + window.upMins + "m") : (window.upMins + "m"))
                                                font.pixelSize: window.s(10)
                                                font.family: "JetBrains Mono"
                                                font.weight: Font.Black
                                                color: window.batColorStart
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: (window.batStatus === "Charging" || window.isCharging) ? "FULL" : "LEFT"
                                                font.pixelSize: window.s(9)
                                                font.family: "JetBrains Mono"
                                                font.weight: Font.Bold
                                                color: window.subtext0
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                        ColumnLayout {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: window.s(25)
                            spacing: window.s(15)

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: window.s(96)
                                radius: window.s(14)
                                color: Config.effectiveCardOpacity > 0 ? Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, Config.effectiveCardOpacity) : Qt.rgba(window.text.r, window.text.g, window.text.b, 0.06)
                                border.color: Qt.alpha(window.surface1, 0.3)
                                border.width: Config.borderWidth

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: window.s(14)
                                    spacing: window.s(12)

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: window.s(15)

                                        Item {
                                            Layout.preferredWidth: window.s(32)
                                            Layout.preferredHeight: window.s(32)
                                            Text {
                                                anchors.centerIn: parent
                                                text: window.sysBrightness > 66 ? "󰃠" : (window.sysBrightness > 33 ? "󰃟" : "󰃞")
                                                font.family: "Iosevka Nerd Font"
                                                font.pixelSize: window.s(22)
                                                color: window.ambientPrimary
                                                Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                            }
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            height: window.s(18)
                                            
                                            Timer {
                                                id: briCmdThrottle
                                                interval: 50
                                                property int targetPct: -1
                                                onTriggered: {
                                                    if (targetPct >= 0) {
                                                        Quickshell.execDetached(["brightnessctl", "set", targetPct + "%"]);
                                                        targetPct = -1;
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: window.s(9)
                                                color: Qt.rgba(window.text.r, window.text.g, window.text.b, 0.10)
                                                border.color: Qt.alpha(window.surface2, 0.3)
                                                border.width: Config.borderWidth
                                                clip: true

                                                Rectangle {
                                                    height: parent.height
                                                    width: parent.width * (window.sysBrightness / 100)
                                                    radius: window.s(9)
                                                    opacity: briMa.containsMouse ? 1.0 : 0.85
                                                    Behavior on opacity { NumberAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                                    Behavior on width { enabled: !window.isDraggingBri; NumberAnimation { duration: Motion.moveMs; easing.type: Motion.moveEasing } }

                                                    gradient: Gradient {
                                                        orientation: Gradient.Horizontal
                                                        GradientStop { position: 0.0; color: window.batColorStart; Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } } }
                                                        GradientStop { position: 1.0; color: window.batColorEnd; Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } } }
                                                    }
                                                }
                                            }
                                            MouseArea {
                                                id: briMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onPressed: (mouse) => { briSyncDelay.stop(); window.isDraggingBri = true; updateBri(mouse.x); }
                                                onPositionChanged: (mouse) => { if (pressed) updateBri(mouse.x); }
                                                onReleased: { briSyncDelay.restart(); }
                                                
                                                function updateBri(mx) {
                                                    let pct = Math.max(0, Math.min(100, Math.round((mx / width) * 100)));
                                                    window.sysBrightness = pct; 
                                                    briCmdThrottle.targetPct = pct;
                                                    if (!briCmdThrottle.running) briCmdThrottle.start();
                                                }
                                            }
                                        }

                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: window.s(15)

                                        Rectangle {
                                            Layout.preferredWidth: window.s(32)
                                            Layout.preferredHeight: window.s(32)
                                            radius: window.s(16)
                                            color: volIconMa.containsMouse ? window.surface1 : "transparent"
                                            border.color: volIconMa.containsMouse ? window.profileStart : "transparent"
                                            Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                            Behavior on border.color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: window.sysMuted || window.sysVolume === 0 ? "󰖁" : (window.sysVolume > 50 ? "󰕾" : "󰖀")
                                                font.family: "Iosevka Nerd Font"
                                                font.pixelSize: window.s(22)
                                                color: window.sysMuted ? window.overlay0 : window.profileStart
                                                Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                            }
                                            MouseArea {
                                                id: volIconMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    volSyncDelay.stop();
                                                    window.isDraggingVol = true; 
                                                    window.sysMuted = !window.sysMuted;
                                                    Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
                                                    volSyncDelay.restart();
                                                }
                                            }
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            height: window.s(18)
                                            
                                            Timer {
                                                id: volCmdThrottle
                                                interval: 50
                                                property int targetPct: -1
                                                onTriggered: {
                                                    if (targetPct >= 0) {
                                                        if (targetPct > 0 && window.sysMuted) {
                                                            window.sysMuted = false;
                                                            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"]);
                                                        }
                                                        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", targetPct + "%"]);
                                                        targetPct = -1;
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: window.s(9)
                                                color: Qt.rgba(window.text.r, window.text.g, window.text.b, 0.10)
                                                border.color: Qt.alpha(window.surface2, 0.3)
                                                border.width: Config.borderWidth
                                                clip: true

                                                Rectangle {
                                                    height: parent.height
                                                    width: parent.width * (window.sysVolume / 100)
                                                    radius: window.s(9)
                                                    opacity: window.sysMuted ? 0.5 : (volMa.containsMouse ? 1.0 : 0.85)
                                                    Behavior on opacity { NumberAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                                    Behavior on width { enabled: !window.isDraggingVol; NumberAnimation { duration: Motion.moveMs; easing.type: Motion.moveEasing } }

                                                    gradient: Gradient {
                                                        orientation: Gradient.Horizontal
                                                        GradientStop { position: 0.0; color: window.sysMuted ? window.surface2 : window.profileStart; Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } } }
                                                        GradientStop { position: 1.0; color: window.sysMuted ? Qt.lighter(window.surface2, 1.15) : window.profileEnd; Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } } }
                                                    }
                                                }
                                            }
                                            MouseArea {
                                                id: volMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onPressed: (mouse) => { volSyncDelay.stop(); window.isDraggingVol = true; updateVol(mouse.x); }
                                                onPositionChanged: (mouse) => { if (pressed) updateVol(mouse.x); }
                                                onReleased: { volSyncDelay.restart(); }
                                                
                                                function updateVol(mx) {
                                                    let pct = Math.max(0, Math.min(100, Math.round((mx / width) * 100)));
                                                    window.sysVolume = pct;
                                                    volCmdThrottle.targetPct = pct;
                                                    if (!volCmdThrottle.running) volCmdThrottle.start();
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: window.s(75)
                                spacing: window.s(12)
                                
                                Repeater {
                                    id: actionRowRepeater

                                    model: ListModel {
                                        ListElement { cmd: "bash $HOME/.config/hypr/scripts/exit.sh"; icon: "󰍃"; baseColor: "mauve"; weight: 1.0 }
                                        ListElement { cmd: "bash $HOME/.config/hypr/scripts/power.sh suspend"; icon: "ᶻ 𝗓 𝗓"; baseColor: "blue"; weight: 1.0 }
                                        ListElement { cmd: "systemctl poweroff -i"; icon: ""; baseColor: "red"; weight: 3.5 }
                                        ListElement { cmd: "systemctl reboot"; icon: "󰑓"; baseColor: "yellow"; weight: 2.5 }
                                    }
                                    
                                    delegate: Rectangle {
                                        id: actionCapsule
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: window.s(14)

                                        // Keyboard-selected state: same visual language as
                                        // mouse hover, but only while keyboard navigation
                                        // has actually been used in this popup instance.
                                        property bool isSelected: window.keyboardActive && window.selectedActionIndex === index

                                        property color c1: window[baseColor] || window.surface1
                                        property color c2: Qt.lighter(c1, 1.2)

                                        color: actionMa.containsMouse || actionCapsule.isSelected ? Qt.rgba(window.text.r, window.text.g, window.text.b, 0.18) : Qt.rgba(window.text.r, window.text.g, window.text.b, 0.08)
                                        border.color: actionMa.containsMouse || actionCapsule.isSelected ? c1 : "transparent"
                                        border.width: actionMa.containsMouse || actionCapsule.isSelected ? Math.max(1, Config.borderWidth) : Config.borderWidth
                                        Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                        Behavior on border.color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }

                                        scale: actionMa.pressed ? (0.98 - (0.01 * weight)) : (actionMa.containsMouse || actionCapsule.isSelected ? 1.08 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: Motion.enterMs; easing.type: Motion.enterEasing } }

                                        property real fillLevel: 0.0
                                        property bool triggered: false
                                        property real flashOpacity: 0.0

                                        // Single activation entry point shared by mouse
                                        // (`onPressed`) and keyboard (`window.activateSelectedAction`).
                                        // Pressing starts the fill animation; its onFinished
                                        // handles triggering, flash and the exit timer, exactly
                                        // as if the mouse were held down.
                                        function beginAction() {
                                            if (actionCapsule.triggered) return;
                                            drainAnim.stop();
                                            fillAnim.start();
                                        }
                                        
                                        Canvas {
                                            id: actionWaveCanvas
                                            anchors.fill: parent

                                            // Paints once per state: fill progress (data) is the
                                            // only repaint driver remaining.
                                            Connections { target: actionCapsule; function onFillLevelChanged() { actionWaveCanvas.requestPaint() } }

                                            onPaint: {
                                                var ctx = getContext("2d");
                                                ctx.clearRect(0, 0, width, height);
                                                if (actionCapsule.fillLevel <= 0.001) return;

                                                var r = window.s(14);
                                                var fillY = height * (1.0 - actionCapsule.fillLevel);
                                                ctx.save();
                                                ctx.beginPath();
                                                ctx.moveTo(r, 0);
                                                ctx.lineTo(width - r, 0);
                                                ctx.arcTo(width, 0, width, r, r);
                                                ctx.lineTo(width, height - r);
                                                ctx.arcTo(width, height, width - r, height, r);
                                                ctx.lineTo(r, height);
                                                ctx.arcTo(0, height, 0, height - r, r);
                                                ctx.lineTo(0, r);
                                                ctx.arcTo(0, 0, r, 0, r);
                                                ctx.closePath();
                                                ctx.clip();

                                                ctx.beginPath();
                                                ctx.moveTo(0, fillY);
                                                ctx.lineTo(width, fillY);
                                                ctx.lineTo(width, height);
                                                ctx.lineTo(0, height);
                                                ctx.closePath();
                                                
                                                var grad = ctx.createLinearGradient(0, 0, 0, height);
                                                grad.addColorStop(0, actionCapsule.c1.toString());
                                                grad.addColorStop(1, actionCapsule.c2.toString());
                                                ctx.fillStyle = grad;
                                                ctx.fill();
                                                ctx.restore();
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent; radius: window.s(14); color: "#ffffff"
                                            opacity: actionCapsule.flashOpacity
                                            PropertyAnimation on opacity { id: cardFlashAnim; to: 0; duration: Motion.moveMs; easing.type: Motion.moveEasing }
                                        }

                                        Text { 
                                            anchors.centerIn: parent
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: window.s(24)
                                            color: actionMa.containsMouse || actionCapsule.isSelected ? window.text : window.subtext0
                                            text: icon
                                            Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                        }

                                        Item {
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                            height: actionCapsule.height * actionCapsule.fillLevel
                                            clip: true
                                            
                                            Text { 
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                y: (actionCapsule.height / 2) - (height / 2) - (actionCapsule.height - parent.height)
                                                font.family: "Iosevka Nerd Font"
                                                font.pixelSize: window.s(24)
                                                color: window.crust
                                                text: icon 
                                            }
                                        }

                                        MouseArea {
                                            id: actionMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: actionCapsule.triggered ? Qt.ArrowCursor : Qt.PointingHandCursor
                                            
                                            onPressed: {
                                                actionCapsule.beginAction();
                                            }
                                            onReleased: {
                                                if (!actionCapsule.triggered && actionCapsule.fillLevel < 1.0) { 
                                                    fillAnim.stop(); 
                                                    drainAnim.start(); 
                                                }
                                            }
                                            onClicked: {
                                                if (index === 0) {
                                                    // Instant reliable logoff
                                                    Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/exit.sh"]);
                                                } else if (index === 1) {
                                                    // Instant sleep
                                                    Quickshell.execDetached(["systemctl", "suspend"]);
                                                    Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
                                                }
                                            }
                                        }

                                        NumberAnimation {
                                            id: fillAnim; target: actionCapsule; property: "fillLevel"; to: 1.0
                                            duration: Motion.holdMs; easing.type: Motion.holdEasing
                                            onFinished: {
                                                actionCapsule.triggered = true; actionCapsule.flashOpacity = 0.6; cardFlashAnim.start();
                                                exitTimer.start();
                                            }
                                        }

                                        NumberAnimation {
                                            id: drainAnim; target: actionCapsule; property: "fillLevel"; to: 0.0
                                            duration: Motion.exitMs; easing.type: Motion.exitEasing
                                        }

                                        Timer {
                                            id: exitTimer; interval: 500 
                                            onTriggered: { 
                                                if (index === 0) {
                                                    Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/exit.sh"]);
                                                } else {
                                                    Quickshell.execDetached(["bash", "-c", cmd]); 
                                                    Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: window.s(54)
                                radius: window.s(14)
                                color: Config.effectiveCardOpacity > 0 ? Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, Config.effectiveCardOpacity) : Qt.rgba(window.text.r, window.text.g, window.text.b, 0.06)
                                border.color: Qt.alpha(window.surface1, 0.3)
                                border.width: Config.borderWidth

                                Rectangle {
                                    id: sliderPill
                                    width: (parent.width - window.s(2)) / 3
                                    height: parent.height - window.s(2)
                                    y: window.s(1)
                                    radius: window.s(10)
                                    x: {
                                        if (window.powerProfile === "performance") return window.s(1);
                                        if (window.powerProfile === "balanced") return width + window.s(1);
                                        if (window.powerProfile === "power-saver") return (width * 2) + window.s(1);
                                        return width + window.s(1);
                                    }
                                    opacity: window.powerProfile === "transitioning" ? 0.4 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }

                                    Behavior on x { NumberAnimation { duration: Motion.moveMs; easing.type: Motion.moveEasing } }

                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: window.profileStart; Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } } }
                                        GradientStop { position: 1.0; color: window.profileEnd; Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } } }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0
                                    
                                    Repeater {
                                        model: ListModel {
                                            ListElement { name: "performance"; icon: "󰓅"; label: "Perform" } 
                                            ListElement { name: "balanced"; icon: "󰗑"; label: "Balance" }   
                                            ListElement { name: "power-saver"; icon: "󰌪"; label: "Saver" } 
                                        }
                                        
                                        delegate: Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            
                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: window.s(8)
                                                Text {
                                                    font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(18)
                                                    color: window.powerProfile === name ? window.crust : (profileMa.containsMouse ? window.text : window.subtext0)
                                                    text: icon
                                                    Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                                }
                                                Text {
                                                    font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: window.s(13)
                                                    color: window.powerProfile === name ? window.crust : (profileMa.containsMouse ? window.text : window.subtext0)
                                                    text: label
                                                    Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                                }
                                            }
                                            
                                            MouseArea {
                                                id: profileMa
                                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    window.setPowerProfile(name);
                                                    Qt.callLater(() => { sysPoller.running = false; sysPoller.running = true; });
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }