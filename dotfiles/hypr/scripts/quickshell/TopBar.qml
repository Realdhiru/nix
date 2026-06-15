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

            height: barHeight
            margins { top: s(8); bottom: 0; left: s(4); right: s(4) }
            exclusiveZone: barHeight
            color: "transparent"

            property bool isRecording: false
            property int workspaceCount: 8
            property bool isDesktop: false

            // --- Time & Date ---
            property string timeStr: ""
            property string dateStr: ""

            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    let d = new Date();
                    barWindow.timeStr = Qt.formatDateTime(d, "HH:mm");
                    barWindow.dateStr = Qt.formatDateTime(d, "dddd, MMMM dd");
                }
            }

            // --- Battery ---
            property string batPercent: "100%"
            property string batIcon: "󰁹"
            property string batStatus: "Unknown"
            
            Process {
                id: chassisDetector
                running: true
                command: ["bash", "-c", "if ls /sys/class/power_supply/BAT* 1> /dev/null 2>&1; then echo 'laptop'; else echo 'desktop'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: { barWindow.isDesktop = (this.text.trim() === "desktop"); }
                }
            }

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
                                barWindow.batStatus = data.status;
                            } catch(e) {}
                        }
                        batteryWaiter.running = false;
                        batteryWaiter.running = true;
                    }
                }
            }
            Process { id: batteryWaiter; command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/battery_wait.sh"]; onExited: { batteryPoller.running = false; batteryPoller.running = true; } }

            // --- Workspaces ---
            ListModel {
                id: workspacesModel
                property int activeIndex: 0
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
                                while (workspacesModel.count < newData.length) workspacesModel.append({ "wsId": "", "wsState": "" });
                                while (workspacesModel.count > newData.length) workspacesModel.remove(workspacesModel.count - 1);
                                
                                let newActive = -1;
                                for (let i = 0; i < newData.length; i++) {
                                    if (newData[i].state === "active") newActive = i;
                                    if (workspacesModel.get(i).wsState !== newData[i].state) workspacesModel.setProperty(i, "wsState", newData[i].state);
                                    if (workspacesModel.get(i).wsId !== newData[i].id.toString()) workspacesModel.setProperty(i, "wsId", newData[i].id.toString());
                                }
                                if (newActive !== -1 && workspacesModel.activeIndex !== newActive) workspacesModel.activeIndex = newActive;
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

            // --- Music ---
            property var musicData: { "status": "Stopped", "title": "", "artUrl": "" }
            property string displayTitle: ""
            property string displayArtUrl: ""
            property bool isMediaActive: barWindow.musicData.status !== "Stopped" && barWindow.musicData.title !== ""

            onMusicDataChanged: {
                if (musicData && musicData.status !== "Stopped" && musicData.title !== "") {
                    displayTitle = musicData.title;
                    displayArtUrl = musicData.artUrl;
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

            // --- UI Structure (Centered, Frosted Glass) ---
            Item {
                anchors.fill: parent

                Row {
                    anchors.centerIn: parent
                    spacing: barWindow.s(12)

                    // 1. Workspaces
                    Rectangle {
                        height: barWindow.barHeight
                        width: wsLayout.implicitWidth + barWindow.s(24)
                        color: "rgba(0, 0, 0, 0.4)"
                        border.color: "rgba(255, 255, 255, 0.1)"
                        border.width: 1
                        radius: barWindow.s(100)
                        clip: true
                        visible: workspacesModel.count > 0

                        Row {
                            id: wsLayout
                            anchors.centerIn: parent
                            spacing: barWindow.s(8)

                            Repeater {
                                model: workspacesModel
                                delegate: Rectangle {
                                    property bool isActive: model.wsState === "active"
                                    property bool isOccupied: model.wsState === "occupied"
                                    property bool isVisibleWs: isActive || isOccupied || index === 0
                                    
                                    visible: isVisibleWs
                                    width: isVisibleWs ? (isActive ? barWindow.s(24) : barWindow.s(12)) : 0
                                    height: barWindow.s(12)
                                    radius: barWindow.s(100)
                                    color: isActive ? "rgba(255, 255, 255, 0.9)" : "rgba(255, 255, 255, 0.3)"
                                    
                                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                    Behavior on color { ColorAnimation { duration: 250 } }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh " + model.wsId])
                                    }
                                }
                            }
                        }
                    }

                    // 2. Media Player & Cava
                    Rectangle {
                        height: barWindow.barHeight
                        width: mediaLayout.implicitWidth + barWindow.s(24)
                        color: "rgba(0, 0, 0, 0.4)"
                        border.color: "rgba(255, 255, 255, 0.1)"
                        border.width: 1
                        radius: barWindow.s(100)
                        visible: barWindow.isMediaActive

                        RowLayout {
                            id: mediaLayout
                            anchors.centerIn: parent
                            spacing: barWindow.s(12)

                            Rectangle {
                                width: barWindow.s(32); height: barWindow.s(32); radius: barWindow.s(100)
                                color: "rgba(255, 255, 255, 0.1)"
                                clip: true
                                Image {
                                    id: artImage
                                    anchors.fill: parent
                                    source: barWindow.displayArtUrl || ""
                                    fillMode: Image.PreserveAspectCrop
                                }
                                Text {
                                    visible: artImage.status === Image.Error || artImage.source == ""
                                    anchors.centerIn: parent
                                    text: "󰎆"
                                    font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(18)
                                    color: "rgba(255, 255, 255, 0.7)"
                                }
                            }

                            Text {
                                text: barWindow.displayTitle
                                font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: barWindow.s(13)
                                color: "rgba(255, 255, 255, 0.9)"
                                Layout.maximumWidth: barWindow.s(150)
                                elide: Text.ElideRight
                            }

                            // Cava Trigger Icon
                            Text {
                                text: "󰽰"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(20)
                                color: "rgba(255, 255, 255, 0.7)"
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Quickshell.execDetached(["wezterm", "start", "--", "cava"])
                                }
                            }

                            Row {
                                spacing: barWindow.s(8)
                                Text { text: "󰒮"; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(20); color: "rgba(255, 255, 255, 0.9)"; MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["playerctl", "previous"]) } }
                                Text { text: barWindow.musicData.status === "Playing" ? "󰏤" : "󰐊"; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(24); color: "rgba(255, 255, 255, 0.9)"; MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["playerctl", "play-pause"]) } }
                                Text { text: "󰒭"; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(20); color: "rgba(255, 255, 255, 0.9)"; MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["playerctl", "next"]) } }
                            }
                        }
                    }

                    // 3. Clock
                    Rectangle {
                        height: barWindow.barHeight
                        width: clockLayout.implicitWidth + barWindow.s(32)
                        color: "rgba(0, 0, 0, 0.4)"
                        border.color: "rgba(255, 255, 255, 0.1)"
                        border.width: 1
                        radius: barWindow.s(100)

                        ColumnLayout {
                            id: clockLayout
                            anchors.centerIn: parent
                            spacing: -2
                            Text { text: barWindow.timeStr; Layout.alignment: Qt.AlignHCenter; font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(15); font.weight: Font.Black; color: "rgba(255, 255, 255, 0.95)" }
                            Text { text: barWindow.dateStr; Layout.alignment: Qt.AlignHCenter; font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(10); font.weight: Font.Bold; color: "rgba(255, 255, 255, 0.6)" }
                        }
                    }

                    // 4. Battery
                    Rectangle {
                        height: barWindow.barHeight
                        width: batLayout.implicitWidth + barWindow.s(24)
                        color: "rgba(0, 0, 0, 0.4)"
                        border.color: "rgba(255, 255, 255, 0.1)"
                        border.width: 1
                        radius: barWindow.s(100)
                        visible: !barWindow.isDesktop

                        Row {
                            id: batLayout
                            anchors.centerIn: parent
                            spacing: barWindow.s(8)
                            Text { text: barWindow.batIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(18); color: "rgba(255, 255, 255, 0.9)" }
                            Text { text: barWindow.batPercent; font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(13); font.weight: Font.Bold; color: "rgba(255, 255, 255, 0.9)" }
                        }
                    }

                    // 5. System Tray
                    Rectangle {
                        height: barWindow.barHeight
                        width: trayRepeater.count > 0 ? trayLayout.width + barWindow.s(24) : 0
                        color: "rgba(0, 0, 0, 0.4)"
                        border.color: "rgba(255, 255, 255, 0.1)"
                        border.width: 1
                        radius: barWindow.s(100)
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
                                    source: modelData.icon || ""
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize: Qt.size(barWindow.s(20), barWindow.s(20))
                                    width: barWindow.s(20); height: barWindow.s(20)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}