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


    Theme { id: _theme }
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

    readonly property color primary: _theme.primary
    readonly property color mauve: _theme.mauve
    readonly property color red: _theme.red
    readonly property color peach: _theme.peach
    readonly property color blue: _theme.blue
    readonly property color green: _theme.green

    // Warm porcelain instead of pure white — stays readable without
    // blending into bright wallpaper regions.
    readonly property color lockText: "#F5EFE6"

    function safeFileText(fv) {
        if (!fv) return "";
        try {
            let t = typeof fv.text === "function" ? fv.text() : fv.text;
            return (t && typeof t === "string") ? t.trim() : "";
        } catch(e) {
            return "";
        }
    }

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

    property string queuedPassword: ""

    Timer {
        id: quitTimer
        interval: 100
        repeat: false
        onTriggered: Qt.quit()
    }

    Timer {
        id: testUnlockTimer
        interval: parseInt(Quickshell.env("QS_LOCK_TEST_UNLOCK_MS")) || 0
        running: interval > 0
        repeat: false
        onTriggered: {
            console.log("QS_LOCK_TEST: Test unlock timer fired, releasing session lock cleanly");
            rootLock.locked = false;
            quitTimer.start();
        }
    }

    PamContext {
        id: pam
        
        Component.onCompleted: pam.start()

        onCompleted: (result) => {
            lockUI.authenticating = false;
            if (result === PamResult.Success) {
                rootLock.locked = false;
                quitTimer.start();
            } else {
                lockUI.failed = true;
                lockUI.statusText = "Access Denied";
                if (typeof inputField !== "undefined" && inputField.text === "") {
                    passModel.clear();
                }
                pam.start();
            }
        }
    }

    Connections {
        target: pam
        function onResponseRequiredChanged() {
            if (pam.responseRequired && root.queuedPassword !== "") {
                pam.respond(root.queuedPassword);
                root.queuedPassword = "";
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
                property string currentWallpaperThumb: {
                    let envThumb = Quickshell.env("CURRENT_WALLPAPER_THUMB");
                    if (envThumb && envThumb.trim() !== "") {
                        let raw = envThumb.trim();
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
                    running: false
                    command: ["hyprctl", "splash"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let q = this.text.trim();
                            if (q.length > 0) screenRoot.splashQuote = q;
                        }
                    }
                }

                Timer {
                    id: splashDeferTimer
                    interval: 1000
                    running: true
                    repeat: false
                    onTriggered: splashPoller.running = true
                }
                property string mediaStatus: "Stopped"

                readonly property real cornerMargin: Math.max(24, Math.round(28 * screenRoot.sc))
                readonly property bool isCharging: screenRoot.batStatus === "Charging"
                readonly property string batIcon: {
                    let pct = parseInt(screenRoot.batPct) || 0;
                    if (screenRoot.isCharging) {
                        if (pct >= 90) return "󰂅";
                        if (pct >= 80) return "󰂋";
                        if (pct >= 60) return "󰂊";
                        if (pct >= 40) return "󰢞";
                        if (pct >= 20) return "󰂆";
                        return "󰢜";
                    }
                    if (pct >= 90) return "󰁹";
                    if (pct >= 80) return "󰂂";
                    if (pct >= 70) return "󰂁";
                    if (pct >= 60) return "󰂀";
                    if (pct >= 50) return "󰁿";
                    if (pct >= 40) return "󰁾";
                    if (pct >= 30) return "󰁽";
                    if (pct >= 20) return "󰁼";
                    if (pct >= 10) return "󰁻";
                    return "󰁺";
                }

                FileView {
                    id: lockMusicFileView
                    path: Caching.getRunDir("music") + "/music_info.json"
                    watchChanges: true
                    onLoadedChanged: screenRoot.updateMedia()
                    onTextChanged: screenRoot.updateMedia()
                    onFileChanged: {
                        lockMusicFileView.reload();
                        screenRoot.updateMedia();
                    }
                }

                function updateMedia() {
                    let txt = safeFileText(lockMusicFileView);
                    if (txt !== "") {
                        try {
                            let d = JSON.parse(txt);
                            if (d && typeof d === "object" && d.status && typeof d.status === "string") {
                                screenRoot.mediaStatus = d.status;
                            } else {
                                screenRoot.mediaStatus = "Stopped";
                            }
                        } catch(e) {
                            screenRoot.mediaStatus = "Stopped";
                        }
                    } else {
                        screenRoot.mediaStatus = "Stopped";
                    }
                }

                property real introState: 0.0
                property bool inputActive: false 
                property bool isPlayingIntro: true
                property bool hasBattery: false
                
                Component.onCompleted: {
                    techStatusText = getDynamicTechStatus();
                    let initCap = safeFileText(batCapView);
                    if (initCap.length > 0) {
                        let p = parseInt(initCap);
                        if (!isNaN(p)) {
                            screenRoot.batPct = "" + p;
                            screenRoot.hasBattery = true;
                        }
                    }
                    let initStat = safeFileText(batStatView);
                    if (initStat.length > 0) screenRoot.batStatus = initStat;
                    screenRoot.updateMedia();
                    introSequence.start();
                }

                Timer {
                    id: idleTimer
                    interval: 15000
                    running: screenRoot.inputActive && inputField.text.length === 0
                    repeat: false
                    onTriggered: screenRoot.inputActive = false
                }

                FileView {
                    id: batCapView
                    path: "/sys/class/power_supply/BAT0/capacity"
                    watchChanges: true
                    onTextChanged: {
                        let t = safeFileText(batCapView);
                        if (t.length > 0) {
                            let p = parseInt(t);
                            if (!isNaN(p)) {
                                screenRoot.batPct = "" + p;
                                screenRoot.hasBattery = true;
                            }
                        }
                    }
                    onFileChanged: {
                        batCapView.reload();
                    }
                }

                FileView {
                    id: batStatView
                    path: "/sys/class/power_supply/BAT0/status"
                    watchChanges: true
                    onTextChanged: {
                        let t = safeFileText(batStatView);
                        if (t.length > 0) screenRoot.batStatus = t;
                    }
                    onFileChanged: {
                        batStatView.reload();
                    }
                }

                FileView {
                    id: wallFileFallback
                    path: Quickshell.env("HOME") + "/.cache/current_wallpaper.txt"
                    onTextChanged: {
                        if (screenRoot.currentWallpaperPath === "") {
                            let raw = safeFileText(wallFileFallback);
                            if (raw !== "") {
                                let lower = raw.toLowerCase();
                                let dot = lower.lastIndexOf(".");
                                screenRoot.currentWallpaperExt = dot !== -1 ? lower.substring(dot + 1) : "";
                                screenRoot.currentWallpaperPath = raw.startsWith("file://") ? raw : "file://" + raw;
                            }
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

                Image {
                    id: bgVideoPoster
                    anchors.fill: parent
                    source: screenRoot.currentWallpaperThumb
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: false
                    cache: true
                    visible: screenRoot.isVideoWallpaper && screenRoot.currentWallpaperThumb !== ""
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

                    // Top Right: Floating Clock & Date (Frameless, direct text)
                    Item {
                        id: clockCornerPill
                        anchors.top: parent.top
                        anchors.topMargin: screenRoot.cornerMargin
                        anchors.right: parent.right
                        anchors.rightMargin: screenRoot.cornerMargin
                        height: clockInnerRow.implicitHeight
                        width: clockInnerRow.implicitWidth
                        opacity: screenRoot.introState

                        Row {
                            id: clockInnerRow
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: Math.round(20 * screenRoot.sc)

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Math.round(4 * screenRoot.sc)

                                Text {
                                    id: clockHours
                                    text: Qt.formatDateTime(new Date(), "hh")
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: Math.round(52 * screenRoot.sc)
                                    font.weight: Font.Black
                                    color: root.primary
                                }

                                Text {
                                    text: ":"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: Math.round(52 * screenRoot.sc)
                                    font.weight: Font.Black
                                    color: Qt.rgba(root.lockText.r, root.lockText.g, root.lockText.b, 0.5)
                                }

                                Text {
                                    id: clockMinutes
                                    text: Qt.formatDateTime(new Date(), "mm")
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: Math.round(52 * screenRoot.sc)
                                    font.weight: Font.Black
                                    color: root.lockText
                                }
                            }

                            // Subtle separator
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1
                                height: Math.round(36 * screenRoot.sc)
                                color: Qt.rgba(255, 255, 255, 0.18)
                            }

                            Text {
                                id: dateText
                                anchors.verticalCenter: parent.verticalCenter
                                text: Qt.formatDateTime(new Date(), "ddd, MMM d")
                                font.family: "JetBrains Mono"
                                font.pixelSize: Math.round(22 * screenRoot.sc)
                                font.weight: Font.DemiBold
                                color: Qt.rgba(root.lockText.r, root.lockText.g, root.lockText.b, 0.90)
                            }
                        }

                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            triggeredOnStart: true
                            onTriggered: {
                                let d = new Date();
                                clockHours.text = Qt.formatDateTime(d, "hh");
                                clockMinutes.text = Qt.formatDateTime(d, "mm");
                                dateText.text = Qt.formatDateTime(d, "ddd, MMM d");
                            }
                        }
                    }

                    // Bottom Left: Status / Quote Text (Prominent 18px text token)
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: screenRoot.cornerMargin
                        anchors.left: parent.left
                        anchors.leftMargin: screenRoot.cornerMargin
                        text: screenRoot.splashQuote !== "" ? screenRoot.splashQuote : "Have a nice day!"
                        font.family: "JetBrains Mono"
                        font.pixelSize: Math.round(18 * screenRoot.sc)
                        font.weight: Font.DemiBold
                        color: Qt.rgba(root.lockText.r, root.lockText.g, root.lockText.b, 0.90)
                        width: Math.min(implicitWidth, parent.width * 0.45)
                        elide: Text.ElideRight
                        opacity: screenRoot.introState
                    }

                    // Bottom Right Cluster: [Play/Pause] [Password Pill] [Battery Pill]
                    Row {
                        id: bottomRightCluster
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: screenRoot.cornerMargin
                        anchors.right: parent.right
                        anchors.rightMargin: screenRoot.cornerMargin
                        spacing: Math.round(10 * screenRoot.sc)
                        height: Math.round(38 * screenRoot.sc)
                        opacity: screenRoot.introState

                        // 1. Play/Pause Media Control Button (Leftmost in cluster)
                        Rectangle {
                            id: mediaBtn
                            visible: screenRoot.mediaStatus !== "Stopped"
                            width: parent.height
                            height: parent.height
                            radius: height / 2
                            clip: true

                            color: mediaMouse.pressed
                                ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35)
                                : (mediaMouse.containsMouse
                                    ? Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.35)
                                    : Qt.rgba(root.base.r, root.base.g, root.base.b, Config.effectivePopupOpacity))
                            border.width: Config.borderWidth
                            border.color: (Config.borderWidth > 0 && Config.borderOpacity > 0) ? Qt.rgba(255, 255, 255, Config.borderOpacity) : "transparent"

                            scale: mediaMouse.pressed ? 0.94 : (mediaMouse.containsMouse ? 1.05 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            // Anti-bleed base
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Qt.rgba(root.crust.r, root.crust.g, root.crust.b, Config.antiBleedOpacity)
                                z: -1
                            }

                            Text {
                                anchors.centerIn: parent
                                text: screenRoot.mediaStatus === "Playing" ? "󰏤" : "󰐊"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: Math.round(16 * screenRoot.sc)
                                color: (screenRoot.mediaStatus === "Playing" || mediaMouse.containsMouse) ? root.primary : Qt.rgba(root.lockText.r, root.lockText.g, root.lockText.b, 0.85)
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: mediaMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    let runDir = Caching.getRunDir("music");
                                    let cmd = "playerctl play-pause && sleep 0.05 && bash " + Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/music/music_info.sh > '" + runDir + "/music_info.json.tmp' && mv '" + runDir + "/music_info.json.tmp' '" + runDir + "/music_info.json'";
                                    Quickshell.execDetached(["bash", "-c", cmd]);
                                }
                            }
                        }

                        // 2. Password Input Pill (Center in cluster, compact fixed width)
                        Rectangle {
                            id: pinPill
                            width: Math.round(150 * screenRoot.sc)
                            height: parent.height
                            radius: height / 2
                            clip: true

                            color: lockUI.failed
                                ? Qt.rgba(root.red.r, root.red.g, root.red.b, 0.28)
                                : (lockUI.authenticating
                                    ? Qt.rgba(root.peach.r, root.peach.g, root.peach.b, 0.22)
                                    : (passModel.count > 0
                                        ? Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.32)
                                        : Qt.rgba(root.base.r, root.base.g, root.base.b, Config.effectivePopupOpacity)))
                            border.width: Config.borderWidth
                            border.color: (Config.borderWidth > 0 && Config.borderOpacity > 0) ? Qt.rgba(255, 255, 255, Config.borderOpacity) : "transparent"

                            scale: pinMouse.containsMouse ? 1.02 : (lockUI.authenticating ? 0.98 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            // Anti-bleed base
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Qt.rgba(root.crust.r, root.crust.g, root.crust.b, Config.antiBleedOpacity)
                                z: -1
                            }

                            transform: Translate { id: shakeTranslate; x: 0 }

                            SequentialAnimation {
                                id: shakeAnim
                                NumberAnimation { target: shakeTranslate; property: "x"; from: 0; to: -8 * screenRoot.sc; duration: 40; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: shakeTranslate; property: "x"; from: -8 * screenRoot.sc; to: 8 * screenRoot.sc; duration: 40; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: shakeTranslate; property: "x"; from: 8 * screenRoot.sc; to: -4 * screenRoot.sc; duration: 35; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: shakeTranslate; property: "x"; from: -4 * screenRoot.sc; to: 4 * screenRoot.sc; duration: 35; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: shakeTranslate; property: "x"; from: 4 * screenRoot.sc; to: 0; duration: 30; easing.type: Easing.InOutQuad }
                            }

                            Connections {
                                target: lockUI
                                function onFailedChanged() {
                                    if (lockUI.failed) shakeAnim.restart();
                                }
                            }

                            // Placeholder when idle
                            Text {
                                id: placeholderText
                                anchors.centerIn: parent
                                visible: opacity > 0.01
                                opacity: (passModel.count === 0 && !lockUI.authenticating && !lockUI.failed) ? 1.0 : 0.0
                                text: "Password..."
                                font.family: "JetBrains Mono"
                                font.italic: true
                                font.weight: Font.Medium
                                font.pixelSize: Math.round(12 * screenRoot.sc)
                                color: Qt.rgba(root.lockText.r, root.lockText.g, root.lockText.b, 0.50)
                                Behavior on opacity { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                            }

                            // Status when authenticating
                            Text {
                                id: authenticatingText
                                anchors.centerIn: parent
                                visible: lockUI.authenticating
                                text: "Verifying..."
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: Math.round(12 * screenRoot.sc)
                                color: root.peach

                                SequentialAnimation on opacity {
                                    running: lockUI.authenticating
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1.0; to: 0.5; duration: 250; easing.type: Easing.InOutSine }
                                    NumberAnimation { from: 0.5; to: 1.0; duration: 250; easing.type: Easing.InOutSine }
                                }
                            }

                            // Status when failed
                            Text {
                                id: failedText
                                anchors.centerIn: parent
                                visible: lockUI.failed && passModel.count === 0
                                text: "Access Denied"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: Math.round(12 * screenRoot.sc)
                                color: root.red
                            }

                            ListModel { id: passModel }

                            // Password dots with smooth horizontal layout (sized for 4-8 chars)
                            Item {
                                id: dotsContainer
                                anchors.centerIn: parent
                                readonly property real dotWidth: Math.round(8 * screenRoot.sc)
                                readonly property real dotGap: Math.max(2, Math.round(3 * screenRoot.sc))
                                width: Math.min(pinPill.width - 20 * screenRoot.sc,
                                                Math.max(0, passModel.count > 0 ? (passModel.count * dotWidth + (passModel.count - 1) * dotGap) : 0))
                                height: pinPill.height
                                visible: passModel.count > 0 && !lockUI.authenticating

                                Behavior on width {
                                    NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
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
                                            width: Math.round(5 * screenRoot.sc)
                                            height: width
                                            radius: width / 2
                                            color: lockUI.failed ? root.red : root.primary
                                            antialiasing: true
                                        }
                                    }

                                    add: Transition {
                                        ParallelAnimation {
                                            NumberAnimation { property: "scale"; from: 0.1; to: 1.0; duration: 60; easing.type: Easing.OutCubic }
                                            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 50; easing.type: Easing.OutQuad }
                                        }
                                    }

                                    displaced: Transition {
                                        NumberAnimation { property: "x"; duration: 60; easing.type: Easing.OutQuad }
                                    }

                                    remove: Transition {
                                        ParallelAnimation {
                                            NumberAnimation { property: "scale"; to: 0.0; duration: 50; easing.type: Easing.InQuad }
                                            NumberAnimation { property: "opacity"; to: 0.0; duration: 40 }
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
                                    if (text.length > 0 && !lockUI.authenticating) {
                                        let pwd = text;
                                        text = "";
                                        oldText = "";
                                        passModel.clear();
                                        lockUI.authenticating = true;
                                        lockUI.statusText = "Authenticating...";
                                        lockUI.failed = false;
                                        if (pam.responseRequired) {
                                            pam.respond(pwd);
                                        } else {
                                            root.queuedPassword = pwd;
                                        }
                                    }
                                }

                                onTextChanged: {
                                    if (text.length > 0) {
                                        lockUI.failed = false;
                                    }

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
                                }
                            }
                        }

                        // 3. Battery Pill (Rightmost in cluster, corner aligned)
                        Rectangle {
                            id: batteryPill
                            visible: screenRoot.hasBattery
                            height: parent.height
                            width: batInnerRow.implicitWidth + Math.round(24 * screenRoot.sc)
                            radius: height / 2
                            clip: true

                            color: Qt.rgba(root.base.r, root.base.g, root.base.b, Config.effectivePopupOpacity)
                            border.width: Config.borderWidth
                            border.color: (Config.borderWidth > 0 && Config.borderOpacity > 0) ? Qt.rgba(255, 255, 255, Config.borderOpacity) : "transparent"

                            // Anti-bleed base
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Qt.rgba(root.crust.r, root.crust.g, root.crust.b, Config.antiBleedOpacity)
                                z: -1
                            }

                            Row {
                                id: batInnerRow
                                anchors.centerIn: parent
                                spacing: Math.round(6 * screenRoot.sc)

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: Math.round(16 * screenRoot.sc)
                                    color: screenRoot.isCharging ? root.green : (parseInt(screenRoot.batPct) < 20 ? root.red : root.primary)
                                    text: screenRoot.batIcon
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: screenRoot.batPct + "%"
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Bold
                                    font.pixelSize: Math.round(13 * screenRoot.sc)
                                    color: root.lockText
                                }
                            }
                        }
                    }
                }

                SequentialAnimation {
                    id: introSequence
                    NumberAnimation { target: screenRoot; property: "introState"; from: 0.0; to: 1.0; duration: 60; easing.type: Easing.OutCubic }
                    PropertyAction { target: screenRoot; property: "isPlayingIntro"; value: false }
                    ScriptAction { script: { inputField.text = ""; inputField.forceActiveFocus(); } }
                }
            }
        }
    }


}
