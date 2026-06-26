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
            
            Caching { id: paths }
        
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

            property bool isDesktop: false
            property string ethStatus: "Ethernet"

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
                command: ["bash", "-c", "while [ ! -f " + paths.runDir + "/current_widget ]; do sleep 1; done; inotifywait -qq -e modify,close_write " + paths.runDir + "/current_widget || sleep 2; sleep 0.2"]
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
            
            ListModel { 
                id: workspacesModel 
                property int activeIndex: 0
            }
            
            property var musicData: { "status": "Stopped", "title": "", "artUrl": "", "timeStr": "" }

            property string displayTitle: ""
            property string displayTime: ""
            property string displayArtUrl: ""
            
            property string artCacheBuster: ""

            onMusicDataChanged: {
                if (musicData && musicData.status !== "Stopped" && musicData.title !== "") {
                    displayTitle = musicData.title;
                    displayTime = musicData.timeStr;
                    displayArtUrl = musicData.artUrl;
                    artCacheBuster = "?t=" + Date.now();
                }
            }

            property bool isMediaActive: barWindow.musicData.status !== "Stopped" && barWindow.musicData.title !== ""
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
                command: ["bash", "-c", "~/.config/hypr/scripts/workspaces.sh"]
                running: true
            }

            Process {
                id: wsReader
                running: true
                command: ["cat", paths.getRunDir("workspaces") + "/workspaces.json"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try { 
                                let newData = JSON.parse(txt);
                                
                                while (workspacesModel.count < newData.length) {
                                    workspacesModel.append({ "wsId": "", "wsState": "" });
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
                command: ["bash", "-c", "while [ ! -f " + paths.getRunDir("workspaces") + "/workspaces.json ]; do sleep 1; done; inotifywait -qq -e modify,close_write,move_self " + paths.getRunDir("workspaces") + "/workspaces.json; sleep 0.05"]
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
                command: ["bash", "-c", "bash ~/.config/hypr/scripts/quickshell/music/music_info.sh | tee " + paths.getRunDir("music") + "/music_info.json"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try { barWindow.musicData = JSON.parse(txt); } catch(e) {}
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

            Timer {
                id: artRetryTimer
                interval: 500
                repeat: true
                running: barWindow.displayArtUrl && barWindow.displayArtUrl.indexOf("placeholder_blank.png") !== -1
                onTriggered: {
                    musicForceRefresh.running = false;
                    musicForceRefresh.running = true;
                }
            }

            Process {
                id: kbReader
                command: ["bash", "-c", "bash ~/.config/hypr/scripts/quickshell/watchers/kb_fetch.sh"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        let out = this.text ? this.text.trim() : "";
                        if (out !== "") barWindow.kbLayout = out;
                        barWindow.fastPollerLoaded = true;
                    }
                }
            }

            Item {
                anchors.fill: parent

                RowLayout {
                    id: mainLayout
                    anchors.fill: parent
                    spacing: 0

                    // Left Side: Workspaces Block
                    Rectangle {
                        height: barWindow.barHeight
                        radius: s(14)
                        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                        border.width: 1
                        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                        
                        Row {
                            id: wsRow
                            anchors.centerIn: parent
                            spacing: s(6)
                            padding: s(6)

                            Repeater {
                                model: workspacesModel
                                delegate: Rectangle {
                                    width: wsState === "active" ? s(24) : s(12)
                                    height: s(12)
                                    radius: s(6)
                                    color: wsState === "active" ? mocha.mauve : (wsState === "occupied" ? mocha.text : mocha.surface1)
                                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Center: Time & Date Block
                    Rectangle {
                        id: centerBox
                        color: centerMouse.containsMouse ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.95) : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                        radius: s(14)
                        border.width: 1
                        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, centerMouse.containsMouse ? 0.15 : 0.05)
                        height: barWindow.barHeight
                        width: centerLayout.implicitWidth + s(36)

                        MouseArea {
                            id: centerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle calendar"])
                        }

                        RowLayout {
                            id: centerLayout
                            anchors.centerIn: parent
                            spacing: s(12)

                            Text {
                                text: barWindow.timeStr
                                font.family: "JetBrains Mono"
                                font.pixelSize: s(18)
                                font.weight: Font.Black
                                color: mocha.mauve
                            }

                            ColumnLayout {
                                spacing: 0
                                Text {
                                    text: barWindow.dateStr.split(',')[0] || ""
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: s(10)
                                    font.weight: Font.Black
                                    color: mocha.text
                                }
                                Text {
                                    text: (barWindow.dateStr.split(',')[1] || "").trim()
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: s(10)
                                    font.weight: Font.Bold
                                    color: mocha.subtext0
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Right Side: Quick System Items & Media Metrics
                    Row {
                        id: rightContent
                        spacing: s(4)

                        // Media Playback Indicators
                        Rectangle {
                            id: mediaBox
                            color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                            radius: s(14)
                            border.width: 1
                            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                            height: barWindow.barHeight
                            width: barWindow.isMediaActive ? innerMediaLayout.implicitWidth + s(24) : 0
                            visible: width > 0
                            clip: true

                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                            Row {
                                id: innerMediaLayout
                                anchors.centerIn: parent
                                spacing: s(12)
                                padding: s(6)

                                Image {
                                    width: s(32)
                                    height: s(32)
                                    source: barWindow.displayArtUrl ? (barWindow.displayArtUrl + barWindow.artCacheBuster) : ""
                                    fillMode: Image.PreserveAspectCrop
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        text: barWindow.displayTitle
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.Black
                                        font.pixelSize: s(13)
                                        color: mocha.text
                                    }
                                    Text {
                                        text: barWindow.displayTime
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: s(10)
                                        color: mocha.subtext0
                                    }
                                }
                            }
                        }

                        // Hardware Battery Status Layer
                        Rectangle {
                            id: sysBox
                            height: barWindow.barHeight
                            radius: s(14)
                            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                            border.width: 1
                            color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                            width: sysLayout.implicitWidth + s(20)

                            Row {
                                id: sysLayout
                                anchors.centerIn: parent
                                spacing: s(8)

                                Rectangle {
                                    id: sysBatPill
                                    color: batMouse.containsMouse ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                                    radius: s(10)
                                    height: s(34)
                                    width: barWindow.isDesktop ? s(34) : batLayoutRow.implicitWidth + s(24)

                                    Row {
                                        id: batLayoutRow
                                        anchors.centerIn: parent
                                        spacing: s(8)
                                        Text { text: barWindow.isDesktop ? "" : barWindow.batIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: s(16); color: barWindow.batDynamicColor }
                                        Text { text: barWindow.batPercent; font.family: "JetBrains Mono"; font.pixelSize: s(13); font.weight: Font.Black; color: mocha.text; visible: !barWindow.isDesktop }
                                    }

                                    MouseArea {
                                        id: batMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle battery"])
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