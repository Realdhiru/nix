import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root
    focus: true

    Caching { id: paths }

    // --- Responsive Scaling Logic ---
    Scaler {
        id: scaler
        currentWidth: Screen.width
    }
    
    function s(val) { 
        return scaler.s(val); 
    }

    // --- Helper Functions ---
    function formatBytes(bytes) {
        if (bytes === 0 || isNaN(bytes)) return '0 B';
        var k = 1024;
        var sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
        var i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
    }

    function compareVersions(local, remote) {
        if (local === remote || local === "Unknown" || local === "Loading..." || !local || !remote) return false;

        function parseVersion(v) {
            let parts = v.split('-');
            let base = parts[0].split('.').map(Number);
            let rev = parts.length > 1 ? parseInt(parts[1]) : 0;
            return { base: base, rev: rev };
        }

        let l = parseVersion(local);
        let r = parseVersion(remote);

        for (let i = 0; i < Math.max(l.base.length, r.base.length); i++) {
            let lVal = l.base[i] || 0;
            let rVal = r.base[i] || 0;
            if (lVal < rVal) return true;
            if (lVal > rVal) return false;
        }

        return l.rev < r.rev;
    }

    // -------------------------------------------------------------------------
    // KEYBOARD SHORTCUTS & NAVIGATION
    // -------------------------------------------------------------------------
    Keys.onEscapePressed: {
        closeSequence.start();
        event.accepted = true;
    }
    Keys.onTabPressed: {
        let next = (currentTab + 1) % tabNames.length;
        if (next === 0) next = 1; 
        currentTab = next;
        event.accepted = true;
    }
    Keys.onBacktabPressed: {
        let prev = (currentTab - 1 + tabNames.length) % tabNames.length;
        if (prev === 0) prev = tabNames.length - 1; 
        currentTab = prev;
        event.accepted = true;
    }
    Keys.onLeftPressed: {
        if (currentTab === 2) { 
            if (selectedModuleIndex > 0) {
                selectedModuleIndex--;
                modulesList.positionViewAtIndex(selectedModuleIndex, ListView.Contain);
            }
            event.accepted = true;
        }
    }
    Keys.onRightPressed: {
        if (currentTab === 2) { 
            if (selectedModuleIndex < modulesDataModel.count - 1) {
                selectedModuleIndex++;
                modulesList.positionViewAtIndex(selectedModuleIndex, ListView.Contain);
            }
            event.accepted = true;
        }
    }
    Keys.onReturnPressed: {
        if (currentTab === 2) { 
            let target = modulesDataModel.get(selectedModuleIndex).target;
            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "toggle", target]);
            event.accepted = true;
        }
    }
    Keys.onEnterPressed: { Keys.onReturnPressed(event); }

    MatugenColors { id: _theme }
    // -------------------------------------------------------------------------
    // COLORS
    // -------------------------------------------------------------------------
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color subtext1: _theme.subtext1
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color overlay0: _theme.overlay0
    readonly property color mauve: _theme.mauve
    readonly property color pink: _theme.pink
    readonly property color blue: _theme.blue
    readonly property color sapphire: _theme.sapphire
    readonly property color green: _theme.green
    readonly property color peach: _theme.peach
    readonly property color yellow: _theme.yellow
    readonly property color red: _theme.red

    property real colorBlend: 0.0
    SequentialAnimation on colorBlend {
        loops: Animation.Infinite
        running: true
        NumberAnimation { to: 1.0; duration: 15000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.0; duration: 15000; easing.type: Easing.InOutSine }
    }
    
    property color ambientPurple: Qt.tint(root.mauve, Qt.rgba(root.pink.r, root.pink.g, root.pink.b, colorBlend))
    property color ambientBlue: Qt.tint(root.blue, Qt.rgba(root.sapphire.r, root.sapphire.g, root.sapphire.b, colorBlend))

    // -------------------------------------------------------------------------
    // GLOBALS
    // -------------------------------------------------------------------------
    property string dotsVersion: "Loading..."
    property string remoteVersion: ""
    property bool updateAvailable: false

    onDotsVersionChanged: {
        if (remoteVersion !== "" && dotsVersion !== "Loading...") {
            updateAvailable = compareVersions(dotsVersion, remoteVersion);
        }
    }

    onRemoteVersionChanged: {
        if (remoteVersion !== "" && dotsVersion !== "Loading...") {
            updateAvailable = compareVersions(dotsVersion, remoteVersion);
        }
    }

    Process {
        id: versionReader
        command: ["bash", "-c", "source ~/.local/state/imperative-dots-version 2>/dev/null && echo $LOCAL_VERSION || echo 'Unknown'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text ? this.text.trim() : "";
                if (out !== "") root.dotsVersion = out;
            }
        }
    }

    // -------------------------------------------------------------------------
    // SYSTEM INFO PROPERTIES & FETCHER (CACHED)
    // -------------------------------------------------------------------------
    property string sysUser: "Loading..."
    property string sysHost: "Loading..."
    property string sysOS: "Loading..."
    property string sysKernel: "Loading..."
    property string sysCPU: "Loading..."
    property string sysGPU: "Loading..."
    property string faceIconPath: ""
    property string sysUptime: "Loading..."

    Process {
        id: sysInfoProc
        running: true
        command: [
            "bash", "-c",
            "CACHE=\"" + paths.getCacheDir("guide") + "/sysinfo.txt\"; " +
            "if [ ! -f \"$CACHE\" ]; then " +
            "  ICON=\"\"; if [ -f ~/.face.icon ]; then ICON=$(readlink -f ~/.face.icon); elif [ -f ~/.face ]; then ICON=$(readlink -f ~/.face); fi; " +
            "  echo \"$(whoami)|$(hostname)|$(uname -r)|$(cat /etc/os-release | grep '^PRETTY_NAME=' | cut -d'=' -f2 | tr -d '\\\"')|$(grep -m1 'model name' /proc/cpuinfo | cut -d':' -f2 | xargs)|$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | tail -n1 | cut -d':' -f3 | xargs)|$ICON\" > \"$CACHE\"; " +
            "fi; " +
            "cat \"$CACHE\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let line = this.text ? this.text.trim() : "";
                let parts = line.split("|");
                if (parts.length >= 6) {
                    root.sysUser = parts[0];
                    root.sysHost = parts[1];
                    root.sysKernel = parts[2];
                    root.sysOS = parts[3];
                    root.sysCPU = parts[4];
                    root.sysGPU = parts[5] ? parts[5] : "Integrated Graphics";
                    if (parts.length >= 7 && parts[6].trim() !== "") root.faceIconPath = parts[6].trim();
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // STATE MANAGEMENT & DATA
    // -------------------------------------------------------------------------
    property int currentTab: 1
    property int selectedModuleIndex: 0
    property var tabNames: ["Settings", "System", "Modules", "Matugen", "About"]
    property var tabIcons: ["", "", "󰣆", "󰏘", ""]

    property real introBase: 0.0
    property real introSidebar: 0.0
    property real introContent: 0.0

    ListModel {
        id: modulesDataModel
        ListElement { title: "Calendar & Weather"; target: "calendar"; icon: ""; desc: "Dual-sync calendar with live \nOpenWeatherMap integration."; preview: "previews/preview_calendar.png" }
        ListElement { title: "Media & Lyrics"; target: "music"; icon: "󰎆"; desc: "PlayerCtl integration, Cava \nvisualizer, and live lyrics."; preview: "previews/preview_music.png" }
        ListElement { title: "Battery & Power"; target: "battery"; icon: "󰁹"; desc: "Uptime tracking, power profiles, \nand battery health metrics."; preview: "previews/preview_battery.png" }
        ListElement { title: "Network Hub"; target: "network"; icon: "󰤨"; desc: "Wi-Fi and Bluetooth connection \nmanagement via nmcli/bluez."; preview: "previews/preview_network.png" }
        ListElement { title: "FocusTime"; target: "focustime"; icon: "󰄉"; desc: "Built-in Pomodoro timer daemon \nwith session tracking."; preview: "previews/preview_focustime.png" }
        ListElement { title: "Volume Mixer"; target: "volume"; icon: "󰕾"; desc: "Pipewire integration for I/O \nvolume and stream routing."; preview: "previews/preview_volume.png" }
        ListElement { title: "Wallpaper Picker"; target: "wallpaper"; icon: ""; desc: "Live awww backend rendering \nwith Matugen color generation."; preview: "previews/preview_wallpaper.png" }
        ListElement { title: "Monitors"; target: "monitors"; icon: "󰍹"; desc: "Quick display management."; preview: "previews/preview_monitors.png" }
        ListElement { title: "Stewart AI"; target: "stewart"; icon: "󰚩"; desc: "Voice assistant integration.\n(Reserved for future, currently disabled)"; preview: "previews/preview_stewart.png" }
    }

    Component.onCompleted: { 
        startupSequence.start(); 
    }

    ParallelAnimation {
        id: startupSequence
        NumberAnimation { 
            target: root
            property: "introBase"
            from: 0.0
            to: 1.0
            duration: 900
            easing.type: Easing.OutExpo 
        }
        SequentialAnimation { 
            PauseAnimation { duration: 150 }
            NumberAnimation { 
                target: root
                property: "introSidebar"
                from: 0.0
                to: 1.0
                duration: 1000
                easing.type: Easing.OutBack
                easing.overshoot: 1.05 
            } 
        }
        SequentialAnimation { 
            PauseAnimation { duration: 250 }
            NumberAnimation { 
                target: root
                property: "introContent"
                from: 0.0
                to: 1.0
                duration: 1100
                easing.type: Easing.OutBack
                easing.overshoot: 1.02 
            } 
        }
    }

    SequentialAnimation {
        id: closeSequence
        ParallelAnimation { 
            NumberAnimation { 
                target: root
                property: "introContent"
                to: 0.0
                duration: 150
                easing.type: Easing.InExpo 
            }
            NumberAnimation { 
                target: root
                property: "introSidebar"
                to: 0.0
                duration: 150
                easing.type: Easing.InExpo 
            } 
        }
        NumberAnimation { 
            target: root
            property: "introBase"
            to: 0.0
            duration: 200
            easing.type: Easing.InQuart 
        }
        ScriptAction { 
            script: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]) 
        }
    }

    // -------------------------------------------------------------------------
    // BACKGROUND AMBIENCE
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        opacity: introBase
        scale: 0.95 + (0.05 * introBase)
        
        Rectangle {
            anchors.fill: parent
            radius: root.s(16)
            color: root.base
            border.color: root.surface0
            border.width: 1
            clip: true
            
            property real time: 0
            NumberAnimation on time { 
                from: 0
                to: Math.PI * 2
                duration: 20000
                loops: Animation.Infinite
                running: true 
            }
            
            // Orb 1
            Rectangle {
                width: root.s(800)
                height: root.s(800)
                radius: root.s(400)
                x: parent.width * 0.5 + Math.cos(parent.time) * root.s(150)
                y: parent.height * 0.1 + Math.sin(parent.time * 1.5) * root.s(150)
                color: root.ambientPurple
                opacity: 0.06
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blurMax: 100; blur: 1.0 }
            }
            
            // Orb 2
            Rectangle {
                width: root.s(900)
                height: root.s(900)
                radius: root.s(450)
                x: parent.width * 0.1 + Math.sin(parent.time * 0.8) * root.s(200)
                y: parent.height * 0.4 + Math.cos(parent.time * 1.2) * root.s(150)
                color: root.ambientBlue
                opacity: 0.05
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blurMax: 110; blur: 1.0 }
            }

            // Orb 3
            Rectangle {
                width: root.s(700)
                height: root.s(700)
                radius: root.s(350)
                x: parent.width * 0.3 + Math.cos(parent.time * 1.1) * root.s(120)
                y: parent.height * 0.6 + Math.sin(parent.time * 0.9) * root.s(180)
                color: Qt.tint(root.peach, Qt.rgba(root.yellow.r, root.yellow.g, root.yellow.b, colorBlend))
                opacity: 0.04
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blurMax: 90; blur: 1.0 }
            }
        }
    }

    // -------------------------------------------------------------------------
    // MAIN LAYOUT
    // -------------------------------------------------------------------------
    RowLayout {
        anchors.fill: parent
        anchors.margins: root.s(20)
        spacing: root.s(20)

        // ==========================================
        // SIDEBAR
        // ==========================================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: root.s(220)
            radius: root.s(12)
            color: Qt.alpha(root.surface0, 0.4)
            border.color: root.surface1
            border.width: 1
            opacity: introSidebar
            transform: Translate { x: root.s(-30) * (1.0 - introSidebar) }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.s(15)
                spacing: root.s(10)
                
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(60)
                    
                    RowLayout {
                        anchors.fill: parent
                        spacing: root.s(12)
                        
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            width: root.s(36)
                            height: root.s(36)
                            radius: root.s(10)
                            color: root.ambientPurple
                            Text { 
                                anchors.centerIn: parent
                                text: "󰣇"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: root.s(20)
                                color: root.base 
                            }
                        }
                        
                        ColumnLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: root.s(2)
                            Text { 
                                text: "System View"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Black
                                font.pixelSize: root.s(15)
                                color: root.text
                                Layout.alignment: Qt.AlignLeft 
                            }
                        }
                    }
                }

                Rectangle { 
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.alpha(root.surface1, 0.5)
                    Layout.bottomMargin: root.s(10) 
                }

                // --- TAB CONFIGURATION ---
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(44)

                    Rectangle {
                        id: activeHighlight
                        width: parent.width
                        height: root.s(44)
                        radius: root.s(8)
                        color: root.mauve
                        z: 0
                        y: 0
                    }

                    Column {
                        anchors.fill: parent
                        spacing: 0
                        
                        Rectangle {
                            width: parent.width
                            height: root.s(44)
                            radius: root.s(8)
                            z: 1
                            color: "transparent"
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: root.s(15)
                                spacing: root.s(12)
                                
                                Item {
                                    Layout.preferredWidth: root.s(24)
                                    Layout.alignment: Qt.AlignVCenter
                                    Text { 
                                        anchors.centerIn: parent
                                        text: ""
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: root.s(18)
                                        color: root.crust
                                    }
                                }
                                
                                Text { 
                                    text: "System"
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Bold
                                    font.pixelSize: root.s(13)
                                    color: root.crust
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // --- CLOSE BUTTON ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(44)
                    radius: root.s(8)
                    color: closeHover.containsMouse ? Qt.alpha(root.red, 0.1) : "transparent"
                    border.color: closeHover.containsMouse ? root.red : root.surface1
                    border.width: 1
                    scale: closeHover.pressed ? 0.95 : (closeHover.containsMouse ? 1.02 : 1.0)
                    
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Item {
                        anchors.centerIn: parent
                        width: arrowText.implicitWidth
                        height: arrowText.implicitHeight
                        Text { 
                            id: arrowText
                            text: ""
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: root.s(16)
                            color: closeHover.containsMouse ? root.red : root.subtext0
                            Behavior on color { ColorAnimation { duration: 150 } } 
                        }
                    }
                    MouseArea { 
                        id: closeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: closeSequence.start() 
                    }
                }
            }
        }

        // ==========================================
        // CONTENT AREA
        // ==========================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            opacity: introContent
            scale: 0.95 + (0.05 * introContent)
            transform: Translate { y: root.s(20) * (1.0 - introContent) }

            // ------------------------------------------
            // TAB 1: SYSTEM OVERVIEW
            // ------------------------------------------
            Item {
                anchors.fill: parent
                visible: true
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: root.s(15)
                    anchors.leftMargin: root.s(20)
                    anchors.rightMargin: root.s(20)
                    anchors.bottomMargin: root.s(20)
                    spacing: root.s(20)

                    // DEVICE INFO BLOCK
                    Rectangle {
                        id: sysBox
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: root.s(16)
                        color: sysBoxMa.containsMouse ? Qt.alpha(root.surface0, 0.7) : Qt.alpha(root.surface0, 0.4)
                        border.color: sysBoxMa.containsMouse ? root.ambientBlue : root.surface1
                        border.width: 1
                        clip: true
                        
                        Behavior on color { ColorAnimation { duration: 300 } }
                        Behavior on border.color { ColorAnimation { duration: 300 } }

                        Rectangle {
                            width: root.s(250)
                            height: root.s(250)
                            radius: root.s(125)
                            color: root.ambientBlue
                            opacity: 0.15
                            x: sysBoxMa.containsMouse ? parent.width * 0.7 : parent.width * 0.8
                            y: -root.s(50)
                            layer.enabled: true
                            layer.effect: MultiEffect { blurEnabled: true; blurMax: 80; blur: 1.0 }
                            Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutExpo } }
                        }
                        
                        Rectangle {
                            width: root.s(200)
                            height: root.s(200)
                            radius: root.s(100)
                            color: root.ambientPurple
                            opacity: 0.15
                            x: sysBoxMa.containsMouse ? root.s(50) : -root.s(50)
                            y: root.s(20)
                            layer.enabled: true
                            layer.effect: MultiEffect { blurEnabled: true; blurMax: 80; blur: 1.0 }
                            Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutExpo } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: root.s(20)
                            spacing: root.s(30)

                            Item {
                                Layout.preferredWidth: root.s(100)
                                Layout.preferredHeight: root.s(100)
                                
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: root.s(100)
                                    height: root.s(100)
                                    radius: root.s(50)
                                    color: "transparent"
                                    border.color: Qt.alpha(root.ambientPurple, sysBoxMa.containsMouse ? 0.8 : 0.3)
                                    border.width: root.s(3)
                                    scale: sysBoxMa.containsMouse ? 1.05 : 1.0
                                    
                                    Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
                                    Behavior on border.color { ColorAnimation { duration: 300 } }
                                    
                                    RotationAnimation on rotation { 
                                        from: 0
                                        to: 360
                                        duration: 15000
                                        loops: Animation.Infinite
                                        running: true 
                                    }
                                }
                                
                                Item {
                                    anchors.centerIn: parent
                                    width: root.s(84)
                                    height: root.s(84)
                                    
                                    Rectangle { 
                                        id: avatarMaskTab0
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: "black"
                                        visible: false
                                        layer.enabled: true 
                                    }
                                    
                                    Image {
                                        id: userAvatarImg
                                        anchors.fill: parent
                                        source: root.faceIconPath !== "" ? "file://" + root.faceIconPath.replace("file://", "") : ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: false
                                        asynchronous: true
                                        smooth: true
                                        mipmap: true
                                    }
                                    
                                    MultiEffect { 
                                        source: userAvatarImg
                                        anchors.fill: userAvatarImg
                                        maskEnabled: true
                                        maskSource: avatarMaskTab0
                                        visible: root.faceIconPath !== "" 
                                    }
                                    
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: root.faceIconPath === "" ? root.surface0 : "transparent"
                                        border.color: root.surface2
                                        border.width: 1
                                        Text { 
                                            anchors.centerIn: parent
                                            text: ""
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: root.s(42)
                                            color: root.text
                                            visible: root.faceIconPath === ""
                                            scale: sysBoxMa.containsMouse ? 1.1 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: root.s(8)
                                
                                Text { 
                                    text: root.sysUser
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Black
                                    font.pixelSize: root.s(24)
                                    color: root.text 
                                }
                                
                                Text { 
                                    text: "@" + root.sysHost
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: root.s(14)
                                    color: root.subtext0 
                                }
                                
                                Rectangle { 
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Qt.alpha(root.surface1, 0.5)
                                    Layout.topMargin: root.s(5)
                                    Layout.bottomMargin: root.s(5) 
                                }

                                RowLayout {
                                    spacing: root.s(15)
                                    RowLayout { 
                                        spacing: root.s(6)
                                        Text { text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(16); color: root.blue } 
                                        Text { text: root.sysOS; font.family: "JetBrains Mono"; font.weight: Font.Medium; font.pixelSize: root.s(12); color: root.subtext0 } 
                                    }
                                    RowLayout { 
                                        spacing: root.s(6)
                                        Text { text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(16); color: root.peach } 
                                        Text { text: root.sysKernel; font.family: "JetBrains Mono"; font.weight: Font.Medium; font.pixelSize: root.s(12); color: root.subtext0 } 
                                    }
                                }
                                
                                RowLayout {
                                    spacing: root.s(15)
                                    RowLayout { 
                                        spacing: root.s(6)
                                        Text { text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(16); color: root.green } 
                                        Text { 
                                            text: root.sysCPU
                                            font.family: "JetBrains Mono"
                                            font.weight: Font.Medium
                                            font.pixelSize: root.s(12)
                                            color: root.subtext0
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: root.s(220) 
                                        } 
                                    }
                                    RowLayout { 
                                        spacing: root.s(6)
                                        Text { text: "󰢮"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(16); color: root.yellow } 
                                        Text { 
                                            text: root.sysGPU
                                            font.family: "JetBrains Mono"
                                            font.weight: Font.Medium
                                            font.pixelSize: root.s(12)
                                            color: root.subtext0
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: root.s(220) 
                                        } 
                                    }
                                }
                            }
                        }
                        MouseArea { id: sysBoxMa; anchors.fill: parent; hoverEnabled: true }
                    }
                }
            }
        }
    }
}