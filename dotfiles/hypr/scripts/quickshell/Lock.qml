import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtMultimedia
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../"

ShellRoot {
    id: root


    MatugenColors { id: _theme }
    readonly property color base: _theme.base
    readonly property color crust: _theme.crust
    readonly property color mantle: _theme.mantle
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay0: _theme.overlay0
    readonly property color overlay2: _theme.overlay2
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2

    readonly property color mauve: _theme.mauve
    readonly property color red: _theme.red
    readonly property color peach: _theme.peach
    readonly property color blue: _theme.blue
    readonly property color green: _theme.green

    // Warm porcelain instead of pure white — stays readable without
    // blending into bright wallpaper regions.
    readonly property color lockText: "#F5EFE6"

    QtObject {
        id: lockSettings
        property bool hidePassword: false
        property int revealDuration: 300
    }

    QtObject {
        id: lockUI
        property bool failed: false
        property bool authenticating: false
        property string statusText: "Locked"
    }

    Timer {
        id: pamActionTimer
        interval: 50
        onTriggered: pam.start()
    }

    PamContext {
        id: pam
        
        Component.onCompleted: pamActionTimer.start()

        onCompleted: (result) => {
            lockUI.authenticating = false;
            if (result === PamResult.Success) {
                exitSequence.start();
            } else {
                lockUI.failed = true;
                lockUI.statusText = "Access Denied";
                if (typeof inputField !== "undefined") {
                    inputField.text = "";
                    inputField.oldText = "";
                }
                if (typeof passModel !== "undefined") {
                    passModel.clear();
                }
                pamActionTimer.start();
            }
        }
    }

    WlSessionLock {
        id: rootLock
        locked: true

        WlSessionLockSurface {
            id: surface

            Item {
                id: screenRoot
                anchors.fill: parent
                focus: true
                Keys.forwardTo: [inputField]

                Scaler {
                    id: scaler
                    currentWidth: screenRoot.width > 0 ? screenRoot.width : Screen.width
                }
                readonly property real sc: scaler.baseScale

                property string currentWallpaperPath: {
                    let envWp = Quickshell.env("CURRENT_WALLPAPER");
                    if (envWp && envWp.trim() !== "") {
                        let raw = envWp.trim();
                        return raw.startsWith("file://") ? raw : "file://" + raw;
                    }
                    return "";
                }
                property string currentWallpaperExt: {
                    let p = currentWallpaperPath.toLowerCase();
                    let dot = p.lastIndexOf(".");
                    return dot !== -1 ? p.substring(dot + 1) : "";
                }
                readonly property bool isGifWallpaper: screenRoot.currentWallpaperExt === "gif"
                readonly property bool isVideoWallpaper: screenRoot.currentWallpaperExt === "mp4" ||
                                                         screenRoot.currentWallpaperExt === "mkv" ||
                                                         screenRoot.currentWallpaperExt === "mov" ||
                                                         screenRoot.currentWallpaperExt === "webm"
                readonly property bool isStaticWallpaper: !screenRoot.isGifWallpaper && !screenRoot.isVideoWallpaper && screenRoot.currentWallpaperPath !== ""

                property string batPct: "100"
                property string batStatus: "AC"
                property string currentUser: {
                    let u = Quickshell.env("USER");
                    return (u && u.trim() !== "") ? u.trim() : "User";
                }
                property string techStatusText: ""

                function getDynamicTechStatus() {
                    let kernel = Quickshell.env("SYS_KERNEL") || "Linux";
                    let load = Quickshell.env("SYS_LOAD") || "0.00 0.00 0.00";
                    let uptime = Quickshell.env("SYS_UPTIME") || "0h 00m";

                    let pool = [
                        "[SYS_KERNEL] Linux " + kernel + " // Load: " + load + " // Up: " + uptime,
                        "[SEC_GATEWAY] Hyprland [ext-session-lock-v1] // Load: " + load,
                        "[SYSTEM_UPTIME] Uptime: " + uptime + " // Host status: ISOLATED",
                        "[NIXOS_STABLE] Kernel " + kernel + " // Functional generation sealed",
                        "[SEC_GATEWAY] Awaiting passphrase verification to unmask buffer",
                        "[PAM_AUTH] Dynamic token required for session elevation",
                        "[WAYLAND] Framebuffer masked. Compositor in secure mode.",
                        "[CRYPT_CORE] Asymmetric challenge ready. Awaiting input.",
                        "[NIXOS] Pure functional system state preserved in immutable store",
                        "[HYPRLAND_IPC] Workspaces unmapped. Compositing suspended.",
                        "[SYS_DAEMON] Zero privilege escalation detected. Session intact.",
                        "[IO_PIPELINE] Input events restricted to authentication pipe",
                        "[MEMORY_MAP] Virtual memory boundaries sealed. Swap clean.",
                        "[SEC_CORE] Protocol v1 handshake active. Enter credentials.",
                        "[SECURITY] Workstation locked. Physical presence required.",
                        "[HYPR_DISPATCH] Display pipeline paused. Awaiting unlock signal.",
                        "[AUTH_BROKER] Privilege drop verified. Host in restricted state.",
                        "[KERNEL] Workstation idle. Security subsystem standing by.",
                        "[SYS_CONTROL] Session isolated. Cryptographic response required.",
                        "chmod 000 /dev/display -- Authenticate to restore permissions",
                        "sudo !! -- Enter passphrase to continue",
                        "git commit -m 'Workstation locked: WIP'",
                        "echo $PASSWORD > /dev/null -- Enter authentication token",
                        "SIGSTOP sent to all desktop foreground threads",
                        "401 Unauthorized: Session credentials required",
                        "cat /dev/urandom > /dev/lockscreen -- Entropy pool primed",
                        "ssh-keygen -t ed25519: Host identity verified",
                        "nix-store --verify: All system hashes match",
                        "kill -CONT when credentials match",
                        "Hyprland running on Wayland ext-session-lock-v1",
                        "Warning: Unauthorized access attempts will be logged to journald",
                        "Process tree frozen. Awaiting user resumption.",
                        "Hardware RNG seeded. Crypto context initialized.",
                        "Zero packet drops. Local interface in stealth mode.",
                        "systemd[1]: Reached target Session-Lock.target",
                        "Mount namespace isolated. Display buffer shielded.",
                        "Display server: Wayland // Compositor: Hyprland",
                        "State: RESTRICTED // Clearance: ROOT_REQUIRED",
                        "Kernel ring buffer clean. No anomalies detected.",
                        "Terminal sessions persistent in background tmux",
                        "Deterministic builds, immutable system, locked workstation",
                        "Hash verification passed. Awaiting cryptographic unlock.",
                        "Direct Rendering Manager (DRM) locked to session buffer",
                        "IPC socket listening: /run/user/1000/hypr/lock.sock",
                        "Pipeline encrypted via libpam_unix authentication",
                        "Workstation secured. Verify identity to resume execution."
                    ];

                    let idx = Math.floor(Math.random() * pool.length);
                    return pool[idx];
                }

                property string splashQuote: ""

                Process {
                    id: splashPoller
                    running: true
                    command: ["hyprctl", "splash"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let q = this.text.trim();
                            if (q.length > 0) screenRoot.splashQuote = q;
                        }
                    }
                }
                property string faceIconPath: ""
                property string mediaStatus: "Stopped"

                property real introState: 0.0
                property bool inputActive: false 
                property bool isPlayingIntro: true
                property bool isDesktop: false
                
                Component.onCompleted: {
                    techStatusText = getDynamicTechStatus();
                    introSequence.start();
                }


                Timer {
                    id: idleTimer
                    interval: 15000
                    running: screenRoot.inputActive && inputField.text.length === 0
                    repeat: false
                    onTriggered: screenRoot.inputActive = false
                }

                Process {
                    id: chassisDetector
                    running: true
                    command: ["bash", "-c", "if ls /sys/class/power_supply/BAT* 1> /dev/null 2>&1; then echo 'laptop'; else echo 'desktop'; fi"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            screenRoot.isDesktop = (this.text.trim() === "desktop");
                        }
                    }
                }

                Process {
                    id: userPoller
                    running: true
                    command: [
                        "bash", 
                        "-c", 
                        "USER_VAR=$(whoami); ICON_PATH=\"\"; if [ -f \"$HOME/.face.icon\" ]; then ICON_PATH=$(readlink -f \"$HOME/.face.icon\"); elif [ -f \"$HOME/.face\" ]; then ICON_PATH=$(readlink -f \"$HOME/.face\"); fi; echo -n \"$USER_VAR|$ICON_PATH\""
                    ]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let parts = this.text.trim().split("|");
                            if (parts.length > 0 && parts[0] !== "") {
                                screenRoot.currentUser = parts[0];
                            }
                            if (parts.length > 1 && parts[1].trim() !== "") {
                                let path = parts[1].trim();
                                screenRoot.faceIconPath = path.startsWith("file://") ? path : "file://" + path;
                            }
                        }
                    }
                }

                Process {
                    id: mediaPoller
                    command: ["bash", "-c", "playerctl status 2>/dev/null || echo 'Stopped'"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            screenRoot.mediaStatus = this.text.trim();
                        }
                    }
                }
                Timer { 
                    interval: 1000; running: true; repeat: true; triggeredOnStart: true; 
                    onTriggered: { mediaPoller.running = false; mediaPoller.running = true; } 
                }

                Process {
                    id: batPoller
                    command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1 || echo '100'; cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1 || echo 'AC'"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let lines = this.text.trim().split("\n");
                            if (lines.length >= 2) {
                                screenRoot.batPct = lines[0] || "100";
                                screenRoot.batStatus = lines[1] || "Unknown";
                            }
                        }
                    }
                }
                Timer { 
                    interval: 5000; running: !screenRoot.isDesktop; repeat: true; triggeredOnStart: true; 
                    onTriggered: { batPoller.running = false; batPoller.running = true; } 
                }

                Process {
                    id: wallpaperProbe
                    running: screenRoot.currentWallpaperPath === ""
                    command: ["bash", "-c", "cat \"$HOME/.cache/current_wallpaper.txt\" 2>/dev/null | head -n1"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let raw = this.text.trim();
                            if (raw === "") {
                                screenRoot.currentWallpaperExt = "";
                                screenRoot.currentWallpaperPath = "";
                                return;
                            }
                            let lower = raw.toLowerCase();
                            let dot = lower.lastIndexOf(".");
                            screenRoot.currentWallpaperExt = dot !== -1 ? lower.substring(dot + 1) : "";
                            screenRoot.currentWallpaperPath = raw.startsWith("file://") ? raw : "file://" + raw;
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: root.base
                    visible: screenRoot.currentWallpaperPath === ""
                }

                Image {
                    id: bgImage
                    anchors.fill: parent
                    source: screenRoot.isStaticWallpaper ? screenRoot.currentWallpaperPath : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: false
                    cache: true
                    visible: screenRoot.isStaticWallpaper
                }

                AnimatedImage {
                    id: bgGif
                    anchors.fill: parent
                    source: screenRoot.isGifWallpaper ? screenRoot.currentWallpaperPath : ""
                    fillMode: Image.PreserveAspectCrop
                    playing: screenRoot.isGifWallpaper
                    cache: false
                    visible: screenRoot.isGifWallpaper
                }

                VideoOutput {
                    id: bgVideo
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectCrop
                    visible: screenRoot.isVideoWallpaper
                }

                MediaPlayer {
                    id: bgVideoPlayer
                    source: screenRoot.isVideoWallpaper ? screenRoot.currentWallpaperPath : ""
                    loops: MediaPlayer.Infinite
                    videoOutput: bgVideo
                    audioOutput: AudioOutput { muted: true }
                    onSourceChanged: {
                        if (source !== "") {
                            play();
                        }
                    }
                }

                MultiEffect {
                    source: screenRoot.isGifWallpaper ? bgGif : bgImage
                    anchors.fill: parent
                    visible: !screenRoot.isVideoWallpaper
                    blurEnabled: true
                    blurMax: 40 * screenRoot.sc
                    blur: 0.65 * screenRoot.introState
                }

                Rectangle {
                    id: dimmer
                    anchors.fill: parent
                    color: "black"
                    opacity: 0.18 * screenRoot.introState
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !screenRoot.isPlayingIntro
                    onClicked: (event) => {
                        inputField.forceActiveFocus();
                    }
                }

                Item {
                    anchors.fill: parent

                    // Top Dynamic Tech Telemetry / Hacker Status
                    Text {
                        anchors.top: parent.top
                        anchors.topMargin: Math.max(36, Math.round(44 * screenRoot.sc))
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: screenRoot.techStatusText
                        font.family: "JetBrains Mono"
                        font.pixelSize: Math.max(14, Math.round(screenRoot.height * 0.020))
                        font.weight: Font.SemiBold
                        color: Qt.rgba(root.lockText.r, root.lockText.g, root.lockText.b, 0.80)
                        horizontalAlignment: Text.AlignHCenter
                        width: Math.min(implicitWidth, parent.width * 0.90)
                        elide: Text.ElideRight

                        opacity: screenRoot.introState
                        transform: Translate { y: (-16 * screenRoot.sc) * (1.0 - screenRoot.introState) }
                    }

                    // Central Floating Capsule Card (~24% screen width, ~62% screen height)
                    Rectangle {
                        id: centerCard
                        anchors.centerIn: parent
                        width: Math.round(Math.min(screenRoot.width * 0.24, 460 * screenRoot.sc))
                        height: Math.round(Math.min(screenRoot.height * 0.62, 640 * screenRoot.sc))
                        radius: Math.round(centerCard.width * 0.12)
                        color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.22)
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.18)

                        scale: 0.94 + 0.06 * screenRoot.introState
                        opacity: screenRoot.introState
                        transform: Translate { y: (28 * screenRoot.sc) * (1.0 - screenRoot.introState) }

                        // Outer subtle ambient glow / depth border
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -1
                            radius: centerCard.radius + 1
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.06)
                        }

                        // Top frosted specular reflection highlight
                        Rectangle {
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.max(0, parent.width - centerCard.radius * 2)
                            anchors.topMargin: 1
                            height: 1
                            color: Qt.rgba(255, 255, 255, 0.24)
                            radius: 1
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 0

                            // Stacked Clock: Hours
                            Text {
                                id: clockHours
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatDateTime(new Date(), "hh")
                                font.family: "JetBrains Mono"
                                font.pixelSize: Math.round(centerCard.height * 0.22)
                                font.weight: Font.Black
                                font.letterSpacing: 2 * screenRoot.sc
                                color: root.blue
                            }

                            // Stacked Clock: Minutes
                            Text {
                                id: clockMinutes
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatDateTime(new Date(), "mm")
                                font.family: "JetBrains Mono"
                                font.pixelSize: Math.round(centerCard.height * 0.22)
                                font.weight: Font.Black
                                font.letterSpacing: 2 * screenRoot.sc
                                color: root.lockText
                            }

                            Item { width: 1; height: Math.round(centerCard.height * 0.035) }

                            // Date
                            Text {
                                id: dateText
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatDateTime(new Date(), "dd MMM dddd")
                                font.family: "JetBrains Mono"
                                font.pixelSize: Math.round(centerCard.height * 0.034)
                                font.weight: Font.Bold
                                color: Qt.rgba(root.lockText.r, root.lockText.g, root.lockText.b, 0.68)
                            }

                            Item { width: 1; height: Math.round(centerCard.height * 0.045) }

                            // Interactive Unlock Pill
                            Rectangle {
                                id: pinPill
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.round(centerCard.width * 0.62)
                                height: Math.round(centerCard.height * 0.082)
                                radius: height / 2
                                clip: true

                                color: lockUI.failed
                                    ? Qt.rgba(root.red.r, root.red.g, root.red.b, 0.25)
                                    : (lockUI.authenticating
                                        ? Qt.rgba(root.peach.r, root.peach.g, root.peach.b, 0.20)
                                        : (passModel.count > 0
                                            ? Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.35)
                                            : Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.22)))
                                border.width: 1
                                border.color: lockUI.failed
                                    ? root.red
                                    : (lockUI.authenticating
                                        ? root.peach
                                        : (passModel.count > 0
                                            ? Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.80)
                                            : (pinMouse.containsMouse
                                                ? Qt.rgba(255, 255, 255, 0.32)
                                                : Qt.rgba(255, 255, 255, 0.18))))

                                scale: pinMouse.containsMouse ? 1.02 : (lockUI.authenticating ? 0.98 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 180 } }
                                Behavior on border.color { ColorAnimation { duration: 180 } }

                                // Top frosted specular highlight for pill
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Math.max(0, parent.width - pinPill.radius * 2)
                                    anchors.topMargin: 1
                                    height: 1
                                    color: Qt.rgba(255, 255, 255, 0.20)
                                    radius: 1
                                }

                                transform: Translate { id: shakeTranslate; x: 0 }

                                SequentialAnimation {
                                    id: shakeAnim
                                    NumberAnimation { target: shakeTranslate; property: "x"; from: 0; to: -12 * screenRoot.sc; duration: 70; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: shakeTranslate; property: "x"; from: -12 * screenRoot.sc; to: 12 * screenRoot.sc; duration: 70; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: shakeTranslate; property: "x"; from: 12 * screenRoot.sc; to: -6 * screenRoot.sc; duration: 60; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: shakeTranslate; property: "x"; from: -6 * screenRoot.sc; to: 6 * screenRoot.sc; duration: 60; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: shakeTranslate; property: "x"; from: 6 * screenRoot.sc; to: 0; duration: 60; easing.type: Easing.InOutQuad }
                                }

                                Connections {
                                    target: lockUI
                                    function onFailedChanged() {
                                        if (lockUI.failed) shakeAnim.restart();
                                    }
                                }

                                // Placeholder when idle
                                Text {
                                    anchors.centerIn: parent
                                    visible: opacity > 0.01
                                    opacity: (passModel.count === 0 && !lockUI.authenticating && !lockUI.failed) ? 1.0 : 0.0
                                    text: "Use Me ;)"
                                    font.family: "JetBrains Mono"
                                    font.italic: true
                                    font.weight: Font.Medium
                                    font.pixelSize: Math.round(pinPill.height * 0.34)
                                    color: Qt.rgba(root.lockText.r, root.lockText.g, root.lockText.b, 0.45)
                                    Behavior on opacity { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                                }

                                // Status when authenticating
                                Text {
                                    anchors.centerIn: parent
                                    visible: lockUI.authenticating
                                    text: "Verifying..."
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Bold
                                    font.pixelSize: Math.round(pinPill.height * 0.32)
                                    color: root.peach

                                    SequentialAnimation on opacity {
                                        running: lockUI.authenticating
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 1.0; to: 0.5; duration: 350; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 0.5; to: 1.0; duration: 350; easing.type: Easing.InOutSine }
                                    }
                                }

                                // Status when failed
                                Text {
                                    anchors.centerIn: parent
                                    visible: lockUI.failed && passModel.count === 0
                                    text: "Access Denied"
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Bold
                                    font.pixelSize: Math.round(pinPill.height * 0.32)
                                    color: root.red
                                }

                                ListModel { id: passModel }

                                // Password dots with fluid horizontal interpolation & soft blossoming
                                Item {
                                    id: dotsContainer
                                    anchors.centerIn: parent
                                    readonly property real dotWidth: Math.round(14 * screenRoot.sc)
                                    readonly property real dotGap: Math.max(3, Math.round(4 * screenRoot.sc))
                                    width: Math.min(pinPill.width - 24 * screenRoot.sc,
                                                    Math.max(0, passModel.count > 0 ? (passModel.count * dotWidth + (passModel.count - 1) * dotGap) : 0))
                                    height: pinPill.height
                                    visible: passModel.count > 0 && !lockUI.authenticating

                                    Behavior on width {
                                        NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                                    }

                                    ListView {
                                        id: dotsList
                                        anchors.fill: parent
                                        orientation: ListView.Horizontal
                                        interactive: false
                                        model: passModel
                                        spacing: dotsContainer.dotGap

                                        delegate: Item {
                                            width: dotsContainer.dotWidth
                                            height: pinPill.height

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: Math.round(8 * screenRoot.sc)
                                                height: width
                                                radius: width / 2
                                                color: lockUI.failed ? root.red : root.lockText
                                                antialiasing: true
                                            }
                                        }

                                        add: Transition {
                                            ParallelAnimation {
                                                NumberAnimation { property: "scale"; from: 0.1; to: 1.0; duration: 85; easing.type: Easing.OutCubic }
                                                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 65; easing.type: Easing.OutQuad }
                                            }
                                        }

                                        displaced: Transition {
                                            NumberAnimation { property: "x"; duration: 80; easing.type: Easing.OutQuad }
                                        }

                                        remove: Transition {
                                            ParallelAnimation {
                                                NumberAnimation { property: "scale"; to: 0.0; duration: 70; easing.type: Easing.InQuad }
                                                NumberAnimation { property: "opacity"; to: 0.0; duration: 50 }
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: pinMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !screenRoot.isPlayingIntro
                                    onClicked: {
                                        inputField.forceActiveFocus();
                                    }
                                }

                                TextInput {
                                    id: inputField
                                    anchors.fill: parent
                                    opacity: 0
                                    echoMode: TextInput.Normal
                                    enabled: !screenRoot.isPlayingIntro

                                    property string oldText: ""

                                    Component.onCompleted: forceActiveFocus()

                                    onActiveFocusChanged: {
                                        if (!activeFocus && !screenRoot.isPlayingIntro) {
                                            forceActiveFocus();
                                        }
                                    }

                                    Keys.onPressed: (event) => {
                                        if (event.key === Qt.Key_Escape) {
                                            text = "";
                                            oldText = "";
                                            passModel.clear();
                                            lockUI.failed = false;
                                            event.accepted = true;
                                        }
                                    }

                                    onAccepted: {
                                        if (text.length > 0 && pam.responseRequired && !lockUI.authenticating) {
                                            lockUI.authenticating = true;
                                            lockUI.statusText = "Authenticating...";
                                            lockUI.failed = false;
                                            pam.respond(text);
                                            text = "";
                                            oldText = "";
                                            passModel.clear();
                                        }
                                    }

                                    onTextChanged: {
                                        if (lockUI.authenticating) return;

                                        if (text !== oldText) {
                                            if (text.length > oldText.length) {
                                                let addBatch = [];
                                                for (let i = oldText.length; i < text.length; i++) {
                                                    addBatch.push({ "isDot": true });
                                                }
                                                if (addBatch.length > 0) passModel.append(addBatch);
                                            } else if (text.length < oldText.length) {
                                                let diff = oldText.length - text.length;
                                                for (let i = 0; i < diff; i++) {
                                                    passModel.remove(passModel.count - 1);
                                                }
                                            } else {
                                                passModel.clear();
                                                let rebuildBatch = [];
                                                for (let i = 0; i < text.length; i++) {
                                                    rebuildBatch.push({ "isDot": true });
                                                }
                                                if (rebuildBatch.length > 0) passModel.append(rebuildBatch);
                                            }
                                            oldText = text;
                                        }

                                        if (text.length > 0) {
                                            lockUI.failed = false;
                                        }
                                    }
                                }
                            }
                        }

                        Timer {
                            interval: 1000; running: true; repeat: true; triggeredOnStart: true
                            onTriggered: {
                                let d = new Date();
                                clockHours.text = Qt.formatDateTime(d, "hh");
                                clockMinutes.text = Qt.formatDateTime(d, "mm");
                                dateText.text = Qt.formatDateTime(d, "dd MMM dddd");
                            }
                        }
                    }

                    // Bottom Hyprland Daily Quote (Splash)
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Math.max(32, Math.round(44 * screenRoot.sc))
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: screenRoot.splashQuote !== "" ? screenRoot.splashQuote : "Have a nice day!"
                        font.family: "JetBrains Mono"
                        font.pixelSize: Math.max(15, Math.round(screenRoot.height * 0.022))
                        font.weight: Font.Bold
                        color: Qt.rgba(root.lockText.r, root.lockText.g, root.lockText.b, 0.72)
                        horizontalAlignment: Text.AlignHCenter
                        width: Math.min(implicitWidth, parent.width * 0.85)
                        elide: Text.ElideRight

                        opacity: screenRoot.introState
                        transform: Translate { y: (16 * screenRoot.sc) * (1.0 - screenRoot.introState) }
                    }
                }

                SequentialAnimation {
                    id: introSequence
                    NumberAnimation { target: screenRoot; property: "introState"; from: 0.0; to: 1.0; duration: 240; easing.type: Easing.OutCubic }
                    PropertyAction { target: screenRoot; property: "isPlayingIntro"; value: false }
                    ScriptAction { script: { inputField.text = ""; inputField.forceActiveFocus(); } }
                }
            }
        }
    }

    SequentialAnimation {
        id: exitSequence
        ParallelAnimation {
            NumberAnimation { target: screenRoot; property: "introState"; to: 0.0; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: centerCard; property: "scale"; to: 0.94; duration: 180; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                rootLock.locked = false;
                Qt.quit();
            }
        }
    }

}
