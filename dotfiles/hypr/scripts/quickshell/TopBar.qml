import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris

Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: barWindow
            property bool pendingReload: false
            
            Caching { id: paths }
        
            IpcHandler {
                target: "topbar"
                function forceReload() {
                    Quickshell.reload(true) 
                }
                function queueReload() {
                    if (!barWindow.isSettingsOpen) {
                        Quickshell.reload(true)
                    } else {
                        barWindow.pendingReload = true
                    }
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
            function s(val) { return scaler.s(val); }

            property int barHeight: s(40)

            height: barHeight
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
            property bool isSettingsOpen: activeWidget === "settings"

            property real settingsSlideProgress: isSettingsOpen ? 1.0 : 0.0
            Behavior on settingsSlideProgress { 
                enabled: barWindow.startupCascadeFinished
                NumberAnimation { duration: 600; easing.type: Easing.OutExpo } 
            }

            onIsSettingsOpenChanged: {
                if (!barWindow.isSettingsOpen && barWindow.pendingReload) {
                    barWindow.pendingReload = false;
                    Quickshell.reload(true);
                }
            }

            // --- NATIVE MPRIS TRACKING ENGINE (REPLACES MUSIC_INFO.SH FORKS) ---
            property var activePlayer: Mpris.players.length > 0 ? Mpris.players[0] : null
            property bool isMediaActive: activePlayer !== null && activePlayer.playbackState !== MprisPlaybackState.Stopped
            
            property string displayTitle: activePlayer ? activePlayer.trackTitle : "Not Playing"
            property string displayArtist: activePlayer ? activePlayer.trackArtist : ""
            property string displayArtUrl: (activePlayer && activePlayer.trackArtUrl) ? activePlayer.trackArtUrl : ""
            property string displayTime: {
                if (!activePlayer) return "00:00 / 00:00";
                return formatDuration(activePlayer.position) + " / " + formatDuration(activePlayer.length);
            }

            function formatDuration(seconds) {
                if (isNaN(seconds) || seconds < 0) return "00:00";
                let m = Math.floor(seconds / 60);
                let s = Math.floor(seconds % 60);
                return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
            }

            // High-Performance Frame Tick Animation to Smooth Out the Timeline
            FrameAnimation {
                running: barWindow.activePlayer && barWindow.activePlayer.playbackState === MprisPlaybackState.Playing
                onTriggered: barWindow.activePlayer.positionChanged()
            }

            // --- REPRODUCIBLE NATIVE USER-SPACE CAVA ENGINE ---
            Process {
                id: cavaDaemon
                command: ["bash", "-c", "mkfifo " + paths.getRunDir("music") + "/qml_cava.fifo 2>/dev/null; cava -p " + paths.homeDir + "/.config/cava/config"]
                running: barWindow.isMediaActive
            }

            Process {
                id: cavaStreamReader
                command: ["cat", paths.getRunDir("music") + "/qml_cava.fifo"]
                running: barWindow.isMediaActive
                property var barValues: [0,0,0,0,0,0,0,0,0,0]

                stdout: StdioCollector {
                    onStreamFinished: {
                        let rawLine = this.text.trim().split("\n").pop();
                        if (!rawLine) return;
                        let points = rawLine.split(/[; ]/);
                        let cleanPoints = [];
                        for (let i = 0; i < points.length; i++) {
                            if (points[i] !== "") cleanPoints.push(parseInt(points[i]) || 0);
                        }
                        if (cleanPoints.length >= 10) {
                            cavaStreamReader.barValues = cleanPoints.slice(0, 10);
                            uniqueCavaCanvas.requestPaint(); 
                        }
                    }
                }
            }

            Process {
                id: widgetPoller
                command: ["bash", "-c", "cat " + paths.runDir + "/current_widget 2>/dev/null || echo ''"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (barWindow.activeWidget !== txt) barWindow.activeWidget = txt;
                    }
                }
            }

            Process {
                id: widgetWatcher
                command: ["bash", "-c", "while [ ! -f " + paths.runDir + "/current_widget ]; do sleep 1; done; inotifywait -qq -e modify,close_write " + paths.runDir + "/current_widget"]
                running: true
                onExited: {
                    widgetPoller.running = false;
                    widgetPoller.running = true;
                    running = false;
                    running = true;
                }
            }
            
            Process {
                id: recPoller
                command: ["bash", "-c", "if [ -s " + paths.getCacheDir("recording") + "/rec_pid ] && kill -0 $(cat " + paths.getCacheDir("recording") + "/rec_pid) 2>/dev/null; then echo '1'; else echo '0'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.isRecording = (this.text.trim() === "1");
                    }
                }
            }

            Process {
                id: recWatcher
                running: true
                command: ["bash", "-c", "inotifywait -qq -e create,delete,modify,close_write " + paths.getCacheDir("recording") + "/ 2>/dev/null || sleep 2"]
                onExited: {
                    recPoller.running = false;
                    recPoller.running = true;
                    running = false;
                    running = true;
                }
            }     
            Process {
                id: updatePoller
                command: ["bash", "-c", "if [ -f " + paths.getCacheDir("updater") + "/update_pending ]; then echo '1'; else echo '0'; fi"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.updateAvailable = (this.text.trim() === "1");
                    }
                }
            }
            
            Process {
                id: updateWatcher
                running: true
                command: ["bash", "-c", "inotifywait -qq -e create,delete,close_write " + paths.getCacheDir("updater") + "/ 2>/dev/null || sleep 5"]
                onExited: {
                    updatePoller.running = false;
                    updatePoller.running = true;
                    running = false;
                    running = true;
                }
            }
                        
            Process {
                id: settingsReader
                command: ["bash", "-c", "cat ~/.config/hypr/settings.json 2>/dev/null || echo '{}'"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            if (this.text && this.text.trim().length > 0 && this.text.trim() !== "{}") {
                                let parsed = JSON.parse(this.text);
                                if (parsed.topbarHelpIcon !== undefined && barWindow.showHelpIcon !== parsed.topbarHelpIcon) {
                                    barWindow.showHelpIcon = parsed.topbarHelpIcon;
                                }
                                if (parsed.workspaceCount !== undefined && barWindow.workspaceCount !== parsed.workspaceCount) {
                                    barWindow.workspaceCount = parsed.workspaceCount;
                                    wsDaemon.running = false;
                                    wsDaemon.running = true;
                                }
                            }
                        } catch (e) {}
                    }
                }
            }

            Process {
                id: settingsWatcher
                command: ["bash", "-c", "while [ ! -f ~/.config/hypr/settings.json ]; do sleep 1; done; inotifywait -qq -e modify,close_write ~/.config/hypr/settings.json"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        settingsReader.running = false;
                        settingsReader.running = true;
                        settingsWatcher.running = false;
                        settingsWatcher.running = true;
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
            
            property bool fastPollerLoaded: false
            property bool isDataReady: fastPollerLoaded
            Timer { interval: 600; running: true; onTriggered: barWindow.isDataReady = true }
            
            property string timeStr: ""
            property string fullDateStr: ""
            property int typeInIndex: 0
            property string dateStr: fullDateStr.substring(0, typeInIndex)

            property string weatherIcon: ""
            property string weatherTemp: "--°"
            property string weatherHex: mocha.yellow
            
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
            
            property bool isWifiOn: barWindow.wifiStatus.toLowerCase() === "enabled" || barWindow.wifiStatus.toLowerCase() === "on"
            property bool isBtOn: barWindow.btStatus.toLowerCase() === "enabled" || barWindow.btStatus.toLowerCase() === "on"
            property bool showEthernet: barWindow.ethStatus === "Connected" || (barWindow.isDesktop && !barWindow.isWifiOn)
            
            property bool isSoundActive: !barWindow.isMuted && parseInt(barWindow.volPercent) > 0
            property int batCap: parseInt(barWindow.batPercent) || 0
            property bool isCharging: barWindow.batStatus === "Charging" || barWindow.batStatus === "Full"
            
            property color batDynamicColor: {
                if (isCharging) return mocha.green;
                if (batCap <= 20) return mocha.red;
                return mocha.text; 
            }

            Process {
                id: weatherPoller
                command: ["bash", "-c", `
                    echo "$(~/.config/hypr/scripts/quickshell/calendar/weather.sh --current-icon)"
                    echo "$(~/.config/hypr/scripts/quickshell/calendar/weather.sh --current-temp)"
                    echo "$(~/.config/hypr/scripts/quickshell/calendar/weather.sh --current-hex)"
                `]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let lines = this.text.trim().split("\n");
                        if (lines.length >= 3) {
                            barWindow.weatherIcon = lines[0];
                            barWindow.weatherTemp = lines[1];
                            barWindow.weatherHex = lines[2] || mocha.yellow;
                        }
                    }
                }
            }
            Timer { interval: 150000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { weatherPoller.running = false; weatherPoller.running = true; } }

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
                        // ACTIVE BINDING: Bypasses static JS wrapping to catch Matugen switches dynamically
                        color: mocha.base
                        opacity: workspacesModel.count > 0 ? 0.75 : 0.0
                        radius: barWindow.s(14)
                        border.width: 1
                        border.color: mocha.surface1
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
                            return ((tensDigit > 1) ? kanjiNums[tensDigit] : "") + ten + kanjiNums[onesDigit];
                        }

                        property bool limitActive: barWindow.isSettingsOpen && barWindow.isMediaActive
                        visible: width > 0

                        Rectangle {
                            id: activeHighlight
                            y: (workspacesBox.height - barWindow.s(32)) / 2
                            height: barWindow.s(32)
                            radius: barWindow.s(10)
                            color: mocha.mauve
                            z: 0

                            property var activePill: (workspacesModel.activeIndex >= 0 && workspacesModel.activeIndex < wsRepeater.count) ? wsRepeater.itemAt(workspacesModel.activeIndex) : null
                            property real targetLeft: activePill ? (wsLayout.x + activePill.x) : 0
                            property real targetWidth: activePill ? activePill.width : 0
                            property real actualLeft: targetLeft
                            property real actualWidth: targetWidth

                            Behavior on actualLeft { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            Behavior on actualWidth { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

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
                                    color: isHovered ? mocha.surface1 : (stateLabel === "occupied" ? mocha.surface0 : "transparent")

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

                                    Timer { id: animTimer; onTriggered: wsPill.initAnimTrigger = true }
                                    Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: wsPill.isItemVisible ? workspacesBox.toKanji(wsName) : ""
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: barWindow.s(14)
                                        font.weight: stateLabel === "active" ? Font.Black : (stateLabel === "occupied" ? Font.Bold : Font.Medium)
                                        color: index === workspacesModel.activeIndex ? mocha.crust : (isHovered ? mocha.text : (stateLabel === "occupied" ? mocha.text : mocha.overlay0))
                                    }
                                    
                                    MouseArea {
                                        id: wsPillMouse
                                        hoverEnabled: true
                                        anchors.fill: parent
                                        enabled: wsPill.isItemVisible
                                        onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh " + wsName])
                                    }
                                }
                            }
                        }
                    }

                    // --- HIGH-PERFORMANCE MATERIAL CAVA MODULE ---
                    Rectangle {
                        id: cavaWidgetBox
                        color: mocha.base
                        radius: barWindow.s(14)
                        border.width: 1
                        border.color: mocha.surface1
                        height: barWindow.barHeight
                        clip: true

                        property real targetWidth: barWindow.isMediaActive ? barWindow.s(110) : 0
                        width: targetWidth
                        visible: targetWidth > 0
                        opacity: barWindow.isMediaActive ? 0.75 : 0.0

                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        Canvas {
                            id: uniqueCavaCanvas
                            anchors.fill: parent
                            anchors.margins: barWindow.s(6)
                            antialiasing: true
                            renderTarget: Canvas.FramebufferObject

                            property var smoothHeights: [0,0,0,0,0,0,0,0,0,0]

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);

                                var rawData = cavaStreamReader.barValues;
                                var barCount = 10;
                                var spacing = barWindow.s(3);
                                var totalSpacing = spacing * (barCount - 1);
                                var barWidth = (width - totalSpacing) / barCount;

                                for (var i = 0; i < barCount; i++) {
                                    var rawTarget = (rawData[i] / 255.0) * height;
                                    smoothHeights[i] = smoothHeights[i] + (rawTarget - smoothHeights[i]) * 0.35;

                                    var xCoord = i * (barWidth + spacing);
                                    var finalBarHeight = Math.max(barWindow.s(3), smoothHeights[i]);
                                    var yCoord = height - finalBarHeight;

                                    var gradient = ctx.createLinearGradient(xCoord, yCoord, xCoord, height);
                                    gradient.addColorStop(0.0, mocha.mauve);
                                    gradient.addColorStop(0.5, mocha.blue);
                                    gradient.addColorStop(1.0, mocha.surface0);

                                    ctx.fillStyle = gradient;
                                    ctx.beginPath();
                                    ctx.roundRect(xCoord, yCoord, barWidth, finalBarHeight, barWindow.s(4));
                                    ctx.fill();
                                }
                            }
                        }
                    }

                    // --- NATIVE FLUID MEDIA BOX MODULE ---
                    Rectangle {
                        id: mediaBox
                        color: mocha.base
                        radius: barWindow.s(14)
                        border.width: 1
                        border.color: mocha.surface1
                        height: barWindow.barHeight
                        clip: true 
                        
                        width: barWindow.isMediaActive ? innerMediaLayout.implicitWidth + barWindow.s(24) : 0
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                        visible: width > 0
                        opacity: barWindow.isMediaActive ? 0.75 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 400 } }
                        
                        Item {
                            id: mediaLayoutContainer
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: barWindow.s(12)
                            height: parent.height
                            width: innerMediaLayout.implicitWidth
                            
                            opacity: barWindow.isMediaActive ? 1.0 : 0.0
                            transform: Translate { 
                                x: barWindow.isMediaActive ? 0 : barWindow.s(-20) 
                                Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.OutQuint } }
                            }

                            Row {
                                id: innerMediaLayout
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: barWindow.width < 1920 ? barWindow.s(8) : barWindow.s(16)
                                
                                MouseArea {
                                    id: mediaInfoMouse
                                    width: infoLayout.width
                                    height: innerMediaLayout.height
                                    hoverEnabled: true
                                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle music"])
                                    
                                    Row {
                                        id: infoLayout
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: barWindow.s(10)
                                        scale: mediaInfoMouse.containsMouse ? 1.02 : 1.0

                                        Rectangle {
                                            width: barWindow.s(32); height: barWindow.s(32); radius: barWindow.s(8); color: mocha.surface0
                                            border.width: (barWindow.activePlayer && barWindow.activePlayer.playbackState === MprisPlaybackState.Playing) ? 1 : 0
                                            border.color: mocha.mauve
                                            clip: true
                                            
                                            Image { 
                                                anchors.fill: parent
                                                source: barWindow.displayArtUrl
                                                fillMode: Image.PreserveAspectCrop 
                                            }
                                        }
                                        Column {
                                            spacing: -2
                                            anchors.verticalCenter: parent.verticalCenter
                                            property real maxColWidth: barWindow.width < 1920 ? barWindow.s(120) : barWindow.s(180)
                                            width: maxColWidth 
                                            
                                            Text { 
                                                text: barWindow.displayTitle
                                                font.family: "JetBrains Mono"
                                                font.weight: Font.Black
                                                font.pixelSize: barWindow.s(13)
                                                color: mocha.text
                                                width: parent.width
                                                elide: Text.ElideRight 
                                            }
                                            Text { 
                                                text: barWindow.displayTime
                                                font.family: "JetBrains Mono"
                                                font.weight: Font.Black
                                                font.pixelSize: barWindow.s(10)
                                                color: mocha.subtext0
                                                width: parent.width
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: barWindow.width < 1920 ? barWindow.s(4) : barWindow.s(8)
                                    Item { 
                                        width: barWindow.s(24); height: barWindow.s(24)
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { 
                                            anchors.centerIn: parent; text: "󰒮"; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(26)
                                            color: prevMouse.containsMouse ? mocha.text : mocha.overlay2
                                            scale: prevMouse.containsMouse ? 1.1 : 1.0
                                        }
                                        MouseArea { id: prevMouse; hoverEnabled: true; anchors.fill: parent; onClicked: if(barWindow.activePlayer) barWindow.activePlayer.previous() } 
                                    }
                                    Item { 
                                        width: barWindow.s(28); height: barWindow.s(28)
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { 
                                            anchors.centerIn: parent
                                            text: (barWindow.activePlayer && barWindow.activePlayer.playbackState === MprisPlaybackState.Playing) ? "󰏤" : "󰐊"
                                            font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(30)
                                            color: playMouse.containsMouse ? mocha.green : mocha.text
                                            scale: playMouse.containsMouse ? 1.15 : 1.0
                                        }
                                        MouseArea { id: playMouse; hoverEnabled: true; anchors.fill: parent; onClicked: if(barWindow.activePlayer) barWindow.activePlayer.togglePlaying() } 
                                    }
                                    Item { 
                                        width: barWindow.s(24); height: barWindow.s(24)
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { 
                                            anchors.centerIn: parent; text: "󰒭"; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(26)
                                            color: nextMouse.containsMouse ? mocha.text : mocha.overlay2
                                            scale: nextMouse.containsMouse ? 1.1 : 1.0
                                        }
                                        MouseArea { id: nextMouse; hoverEnabled: true; anchors.fill: parent; onClicked: if(barWindow.activePlayer) barWindow.activePlayer.next() } 
                                    }
                                }
                            }
                        }
                    }

                    // --- CENTER MODULE (CLOCK + DATE STACK) ---
                    Rectangle {
                        id: centerBox
                        property bool isHovered: centerMouse.containsMouse
                        color: mocha.base
                        opacity: showLayout ? 0.75 : 0.0
                        radius: barWindow.s(14)
                        border.width: 1
                        border.color: isHovered ? mocha.mauve : mocha.surface1
                        height: barWindow.barHeight
                        width: centerLayout.implicitWidth + barWindow.s(36)
                        
                        property bool showLayout: false
                        transform: Translate {
                            y: centerBox.showLayout ? 0 : barWindow.s(-30)
                            Behavior on y { NumberAnimation { duration: 800; easing.type: Easing.OutBack } }
                        }

                        Timer { running: barWindow.isStartupReady; interval: 150; onTriggered: centerBox.showLayout = true }
                        scale: isHovered ? 1.03 : 1.0
                        
                        MouseArea {
                            id: centerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle calendar"])
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
                                color: mocha.blue
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

                    // --- RIGHT CONTAINER ---
                    Row {
                        id: rightContent
                        spacing: barWindow.s(4)
                        property bool showLayout: false
                        opacity: showLayout ? 1 : 0
                        transform: Translate {
                            x: rightContent.showLayout ? 0 : barWindow.s(30)
                            Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutBack } }
                        }
                        
                        Timer { running: barWindow.isStartupReady && barWindow.isDataReady; interval: 250; onTriggered: rightContent.showLayout = true }

                        Rectangle {
                            height: barWindow.barHeight
                            radius: barWindow.s(14)
                            border.color: mocha.surface1
                            border.width: 1
                            color: mocha.base
                            opacity: targetWidth > 0 ? 0.75 : 0.0
                            
                            property real targetWidth: trayRepeater.count > 0 ? trayLayout.width + barWindow.s(24) : 0
                            width: targetWidth
                            visible: targetWidth > 0

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
                                        Timer { id: trayAnimTimer; onTriggered: trayIcon.initAnimTrigger = true }

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
                                            onClicked: mouse => {
                                                if (mouse.button === Qt.LeftButton) {
                                                    if (modelData.isMenuOnly || modelData.onlyMenu) menuAnchor.open();
                                                    else if (typeof modelData.activate === "function") modelData.activate(); 
                                                } else if (mouse.button === Qt.MiddleButton) {
                                                    if (typeof modelData.secondaryActivate === "function") modelData.secondaryActivate();
                                                } else if (mouse.button === Qt.RightButton) {
                                                    if (modelData.menu) menuAnchor.open();
                                                    else if (typeof modelData.contextMenu === "function") modelData.contextMenu(mouse.x, mouse.y);
                                                    else modelData.activate(); 
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // --- HARDWARE TELEMETRY CAPSULE ---
                        Rectangle {
                            height: barWindow.barHeight
                            radius: barWindow.s(14)
                            border.color: mocha.surface1
                            border.width: 1
                            color: mocha.base
                            opacity: 0.75
                            clip: true
                            width: sysLayout.implicitWidth + barWindow.s(20)

                            Row {
                                id: sysLayout
                                anchors.centerIn: parent
                                spacing: barWindow.s(8) 
                                property int pillHeight: barWindow.s(34)

                                Rectangle {
                                    property bool isHovered: batMouse.containsMouse
                                    radius: barWindow.s(10)
                                    height: sysLayout.pillHeight
                                    clip: true
                                    color: isHovered ? mocha.surface1 : mocha.surface0
                                    
                                    property real targetWidth: barWindow.isDesktop ? barWindow.s(34) : batLayoutRow.implicitWidth + barWindow.s(24)
                                    width: targetWidth
                                    
                                    scale: isHovered ? 1.05 : 1.0
                                    property bool initAnimTrigger: false
                                    Timer { running: rightContent.showLayout; interval: 200; onTriggered: parent.initAnimTrigger = true }
                                    opacity: initAnimTrigger ? 1.0 : 0.0
                                    transform: Translate { y: parent.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }

                                    Row { 
                                        id: batLayoutRow
                                        anchors.centerIn: parent
                                        spacing: barWindow.s(8)
                                        Text { anchors.verticalCenter: parent.verticalCenter; text: barWindow.isDesktop ? "" : barWindow.batIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.isDesktop ? barWindow.s(18) : barWindow.s(16); color: barWindow.batDynamicColor }
                                        Text { anchors.verticalCenter: parent.verticalCenter; visible: !barWindow.isDesktop; text: barWindow.batPercent; font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(13); font.weight: Font.Black; color: mocha.text }
                                    }
                                    MouseArea { id: batMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle battery"]) }
                                }                       
                            }
                        }
                    }

                    Rectangle {
                        id: recButton
                        property bool isHovered: recMouse.containsMouse
                        color: isHovered ? mocha.surface1 : mocha.base
                        opacity: barWindow.isRecording ? 0.75 : 0.0
                        radius: barWindow.s(14)
                        border.width: 1
                        border.color: isHovered ? mocha.mauve : mocha.surface1

                        property real targetWidth: barWindow.isRecording ? barWindow.barHeight : 0
                        width: targetWidth
                        height: barWindow.barHeight 
                        visible: targetWidth > 0
                        clip: true

                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                        scale: isHovered ? 1.05 : 1.0

                        Text {
                            id: recIcon
                            anchors.centerIn: parent
                            text: "" 
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: barWindow.s(20)
                            color: mocha.red
                            
                            SequentialAnimation on opacity {
                                running: barWindow.isRecording && !recButton.isHovered
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                            }
                        }
                        
                        MouseArea {
                            id: recMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                barWindow.isRecording = false; 
                                Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/screenshot.sh"]); 
                            }
                        }
                    }
                }
            }
        }
    }
}