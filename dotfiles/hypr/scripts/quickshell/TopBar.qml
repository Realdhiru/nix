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
            
            Caching { id: paths }

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

            property int barHeight: s(48)
            property int pillHeight: s(34)

            height: barHeight
            margins { top: s(8); bottom: 0; left: s(4); right: s(4) }
            exclusiveZone: barHeight 
            color: "transparent"

            MatugenColors {
                id: mocha
            }

            property bool isDesktop: false
            Process {
                id: chassisDetector
                running: true
                command: ["bash", "-c", "if ls /sys/class/power_supply/BAT* 1> /dev/null 2>&1; then echo 'laptop'; else echo 'desktop'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: { barWindow.isDesktop = (this.text.trim() === "desktop"); }
                }
            }

            property bool isStartupReady: false
            Timer { interval: 10; running: true; onTriggered: barWindow.isStartupReady = true }

            // --- Time (with AM/PM) ---
            property string timeStr: ""
            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    let d = new Date();
                    barWindow.timeStr = Qt.formatDateTime(d, "h:mm AP");
                }
            }

            // --- Battery ---
            property string batPercent: "100%"
            property string batIcon: "󰁹"
            
            Process {
                id: batteryPoller; running: true
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/battery_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                barWindow.batPercent = data.percent.toString() + "%";
                                barWindow.batIcon = data.icon;
                            } catch(e) {}
                        }
                        batteryWaiter.running = false;
                        batteryWaiter.running = true;
                    }
                }
            }
            Process { id: batteryWaiter; command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/battery_wait.sh"]; onExited: { batteryPoller.running = false; batteryPoller.running = true; } }

            // --- Workspaces (Japanese Numeral Mapping) ---
            ListModel { 
                id: workspacesModel 
                property int activeIndex: 0
            }
            
            property var kanjiMap: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
            property string activeKanji: kanjiMap[workspacesModel.activeIndex] || (workspacesModel.activeIndex + 1).toString()

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
                                while (workspacesModel.count < newData.length) workspacesModel.append({ "wsId": "", "wsState": "" });
                                while (workspacesModel.count > newData.length) workspacesModel.remove(workspacesModel.count - 1);
                                
                                let newActive = -1;
                                for (let i = 0; i < newData.length; i++) {
                                    if (newData[i].state === "active") newActive = i;
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
                command: ["bash", "-c", "inotifywait -qq -e close_write,modify " + paths.getRunDir("workspaces") + "/workspaces.json"]
                onExited: { wsReader.running = false; wsReader.running = true; running = false; running = true; }
            }

            // --- Music (Fast, Inline) ---
            property var musicData: { "status": "Stopped", "title": "", "timeStr": "" }
            property string displayTitle: ""
            property bool isMediaActive: barWindow.musicData.status !== "Stopped" && barWindow.musicData.title !== ""

            onMusicDataChanged: {
                if (musicData && musicData.status !== "Stopped" && musicData.title !== "") {
                    displayTitle = musicData.title;
                }
            }

            Process {
                id: musicForceRefresh
                running: true
                command: ["bash", "-c", "bash ~/.config/hypr/scripts/quickshell/music/music_info.sh | tee " + paths.getRunDir("music") + "/music_info.json"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") try { barWindow.musicData = JSON.parse(txt); } catch(e) {}
                    }
                }
            }

            Process {
                id: mprisWatcher
                running: true
                command: ["bash", "-c", "dbus-monitor --session \"type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.mpris.MediaPlayer2.Player'\" \"type='signal',interface='org.mpris.MediaPlayer2.Player',member='Seeked'\" 2>/dev/null | grep -m 1 'member=' > /dev/null || sleep 2"]
                onExited: { musicForceRefresh.running = false; musicForceRefresh.running = true; running = false; running = true; }
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
                    barWindow.musicData = newData;
                }
            }

            // --- Layout: Centered Dynamic Row ---
            Item {
                anchors.fill: parent

                Row {
                    anchors.centerIn: parent
                    spacing: barWindow.s(12)

                    // 1. Workspace Pill (Japanese)
                    Rectangle {
                        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                        radius: barWindow.s(14)
                        border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                        height: barWindow.barHeight
                        width: wsContent.implicitWidth + barWindow.s(32)
                        
                        Text {
                            id: wsContent
                            anchors.centerIn: parent
                            text: barWindow.activeKanji
                            font.family: "JetBrains Mono"
                            font.pixelSize: barWindow.s(16)
                            font.weight: Font.Black
                            color: mocha.text
                        }
                    }

                    // 2. Music Inline Pill (Cava + Title + Timeline)
                    Rectangle {
                        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                        radius: barWindow.s(14)
                        border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                        height: barWindow.barHeight
                        width: barWindow.isMediaActive ? mediaRow.implicitWidth + barWindow.s(32) : 0
                        visible: barWindow.isMediaActive
                        clip: true
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle music"])
                        }

                        Row {
                            id: mediaRow
                            anchors.centerIn: parent
                            spacing: barWindow.s(10)

                            Text {
                                text: "󰽰"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: barWindow.s(18)
                                color: mocha.mauve
                                anchors.verticalCenter: parent.verticalCenter
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Quickshell.execDetached(["wezterm", "start", "--", "cava"])
                                }
                            }

                            Text {
                                text: barWindow.displayTitle
                                font.family: "JetBrains Mono"
                                font.pixelSize: barWindow.s(13)
                                font.weight: Font.Black
                                color: mocha.text
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, barWindow.s(200))
                                elide: Text.ElideRight
                            }

                            Text {
                                text: barWindow.musicData.timeStr || ""
                                font.family: "JetBrains Mono"
                                font.pixelSize: barWindow.s(12)
                                font.weight: Font.Medium
                                color: mocha.subtext0
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // 3. Clock Pill
                    Rectangle {
                        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                        radius: barWindow.s(14)
                        border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                        height: barWindow.barHeight
                        width: clockContent.implicitWidth + barWindow.s(32)

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle calendar"])
                        }

                        Text {
                            id: clockContent
                            anchors.centerIn: parent
                            text: barWindow.timeStr
                            font.family: "JetBrains Mono"
                            font.pixelSize: barWindow.s(15)
                            font.weight: Font.Black
                            color: mocha.blue
                        }
                    }

                    // 4. System Tray Pill
                    Rectangle {
                        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                        radius: barWindow.s(14)
                        border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                        height: barWindow.barHeight
                        width: trayRepeater.count > 0 ? trayLayout.implicitWidth + barWindow.s(24) : 0
                        visible: width > 0
                        clip: true

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
                                    width: barWindow.s(18); height: barWindow.s(18)
                                    anchors.verticalCenter: parent.verticalCenter

                                    QsMenuAnchor {
                                        id: menuAnchor
                                        anchor.window: barWindow
                                        anchor.item: trayIcon
                                        menu: modelData.menu
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.LeftButton) {
                                                if (modelData.isMenuOnly || modelData.onlyMenu) menuAnchor.open();
                                                else if (typeof modelData.activate === "function") modelData.activate();
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

                    // 5. Battery Pill
                    Rectangle {
                        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                        radius: barWindow.s(14)
                        border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                        height: barWindow.barHeight
                        width: barWindow.isDesktop ? barWindow.s(48) : batLayout.implicitWidth + barWindow.s(24)
                        visible: !barWindow.isDesktop

                        MouseArea { 
                            anchors.fill: parent; 
                            onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle battery"]) 
                        }

                        Row {
                            id: batLayout
                            anchors.centerIn: parent
                            spacing: barWindow.s(8)
                            Text { 
                                anchors.verticalCenter: parent.verticalCenter
                                text: barWindow.isDesktop ? "" : barWindow.batIcon; 
                                font.family: "Iosevka Nerd Font"; 
                                font.pixelSize: barWindow.s(16); 
                                color: mocha.text 
                            }
                            Text { 
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !barWindow.isDesktop
                                text: barWindow.batPercent; 
                                font.family: "JetBrains Mono"; 
                                font.pixelSize: barWindow.s(13); 
                                font.weight: Font.Black; 
                                color: mocha.text 
                            }
                        }
                    }
                }
            }
        }
    }
}