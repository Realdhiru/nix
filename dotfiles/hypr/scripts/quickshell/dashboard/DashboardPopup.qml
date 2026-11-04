import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root
    focus: true

    property real layoutWidth: 740
    property real layoutHeight: 630
    width: s(layoutWidth)
    height: s(layoutHeight)

    Scaler {
        id: scaler
        currentWidth: Screen.width
    }
    function s(val) { return scaler.s(val); }

    Theme { id: mocha }

    // Dynamic hardware info (fetched once on start, portable across any machine)
    property string hostSpec: "Linux Workstation"

    Process {
        id: sysinfoProc
        command: ["bash", "-c", "echo \"$(uname -n) • $(sed -n 's/^model name[[:blank:]]*: //p' /proc/cpuinfo | head -n1 | sed -E 's/\\((R|TM)\\)//g; s/[[:space:]]+/ /g') • Linux $(uname -r | cut -d- -f1)\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim().length > 0) {
                    root.hostSpec = this.text.trim();
                }
            }
        }
    }

    // Modes state tracking
    property bool wpKillActive: false
    property bool gamingActive: false
    property bool powerSaverActive: false
    property bool coffeeActive: SysData.coffeeActive
    property bool broadcastActive: false

    function parseModesJson(txt) {
        if (!txt || txt === "") return;
        try {
            let data = JSON.parse(txt);
            if (data.active) {
                root.wpKillActive = !!data.active["wallpaper-kill"];
                root.gamingActive = !!data.active["gaming"];
                root.powerSaverActive = !!data.active["power-saver"];
                root.coffeeActive = !!data.active["coffee"];
            }
        } catch(e) {}
    }

    FileView {
        id: modesFileView
        path: Caching.modesJsonFile
        watchChanges: true
        onLoadedChanged: root.parseModesJson(modesFileView.text())
        onTextChanged: root.parseModesJson(modesFileView.text())
        onFileChanged: {
            modesFileView.reload();
            root.parseModesJson(modesFileView.text());
        }
    }

    // Top process monitor model
    ListModel { id: processModel }

    readonly property string procScriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/dashboard/proc_top.sh"

    Process {
        id: psPoller
        command: ["bash", root.procScriptPath]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                let trimmed = line.trim();
                if (!trimmed) return;
                if (trimmed === "__BC_ON__") {
                    root.broadcastActive = true;
                    return;
                }
                if (trimmed === "__BC_OFF__") {
                    root.broadcastActive = false;
                    return;
                }
                let parts = trimmed.split("\t");
                if (parts.length >= 4) {
                    processModel.append({
                        "pid": parts[0],
                        "name": parts[1],
                        "cpu": parts[2],
                        "mem": parts[3]
                    });
                }
            }
        }
    }

    Timer {
        id: pollTimer
        interval: 2000
        repeat: true
        running: false
        onTriggered: root.refreshProcesses()
    }

    function refreshProcesses() {
        processModel.clear();
        psPoller.running = false;
        psPoller.running = true;
    }

    // Cached widget lifecycle contract
    function showWidget() {
        SysData.subscribe();
        modesFileView.reload();
        root.parseModesJson(modesFileView.text());
        root.refreshProcesses();
        pollTimer.restart();
        root.forceActiveFocus();
    }

    onVisibleChanged: {
        if (visible) {
            root.showWidget();
        } else {
            SysData.unsubscribe();
            pollTimer.stop();
            psPoller.running = false;
        }
    }

    Component.onCompleted: {
        if (visible) root.showWidget();
    }

    Component.onDestruction: {
        SysData.unsubscribe();
        pollTimer.stop();
        psPoller.running = false;
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            closeWidget();
            event.accepted = true;
        }
    }

    function closeWidget() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    function formatRate(bytesPerSec) {
        if (!bytesPerSec || bytesPerSec <= 0) return "0.0 KB/s";
        if (bytesPerSec < 1024) return bytesPerSec.toFixed(1) + " B/s";
        let kb = bytesPerSec / 1024;
        if (kb < 1024) return kb.toFixed(1) + " KB/s";
        let mb = kb / 1024;
        return mb.toFixed(2) + " MB/s";
    }

    // =========================================================================
    // Visual Card Structure (Guaranteed Anti-Bleed & High-Contrast WCAG AA)
    // =========================================================================

    // Solid foundation layer: guarantees wallpaper artwork never bleeds through
    Rectangle {
        id: antiBleedBase
        anchors.fill: mainCard
        radius: mainCard.radius
        color: mocha.mantle
        opacity: Config.isSolidMode ? 1.0 : (mocha.isLightMode ? 0.98 : 0.92)
        z: -1
    }

    Rectangle {
        id: mainCard
        anchors.fill: parent
        radius: root.s(16)
        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.65)
        border.width: root.s(1)
        border.color: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.45)
        clip: true

        Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
        Behavior on border.color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }

        // Subtle ambient radial glow
        Rectangle {
            width: parent.width * 0.75
            height: width
            radius: width / 2
            anchors.centerIn: parent
            opacity: 0.04
            color: mocha.mauve
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(22)
            spacing: root.s(16)

            // =================================================================
            // Header Section
            // =================================================================
            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(12)

                Rectangle {
                    width: root.s(36)
                    height: root.s(36)
                    radius: root.s(10)
                    color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.16)
                    border.width: root.s(1)
                    border.color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.35)

                    Text {
                        anchors.centerIn: parent
                        text: "󰍛"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: root.s(20)
                        color: mocha.mauve
                    }
                }

                ColumnLayout {
                    spacing: root.s(2)
                    Layout.fillWidth: true

                    RowLayout {
                        spacing: root.s(8)
                        Text {
                            text: "System Monitor"
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: root.s(16)
                            color: mocha.text
                        }

                        // Live activity badge
                        Rectangle {
                            height: root.s(18)
                            width: liveRow.implicitWidth + root.s(12)
                            radius: root.s(9)
                            color: Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.15)
                            border.width: root.s(1)
                            border.color: Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.35)

                            RowLayout {
                                id: liveRow
                                anchors.centerIn: parent
                                spacing: root.s(4)

                                Rectangle {
                                    width: root.s(6)
                                    height: root.s(6)
                                    radius: width / 2
                                    color: mocha.green
                                }

                                Text {
                                    text: "LIVE"
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Bold
                                    font.pixelSize: root.s(9)
                                    color: mocha.green
                                }
                            }
                        }
                    }

                    Text {
                        text: root.hostSpec
                        font.family: "JetBrains Mono"
                        font.weight: Font.Medium
                        font.pixelSize: root.s(11)
                        color: mocha.subtext0
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Close Button
                Rectangle {
                    width: root.s(30)
                    height: root.s(30)
                    radius: root.s(8)
                    color: closeMa.containsMouse ? Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.18) : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.40)
                    border.width: root.s(1)
                    border.color: closeMa.containsMouse ? mocha.red : Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.40)
                    Behavior on color { ColorAnimation { duration: Motion.fadeMs } }
                    Behavior on border.color { ColorAnimation { duration: Motion.fadeMs } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: root.s(13)
                        color: closeMa.containsMouse ? mocha.red : mocha.subtext0
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeWidget()
                    }
                }
            }

            // =================================================================
            // Modes Quick Controls Strip
            // =================================================================
            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(8)

                // 1. Wallpaper Kill
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(34)
                    radius: root.s(8)
                    color: root.wpKillActive ? Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.18) : (wpMa.containsMouse ? mocha.surface1 : mocha.surface0)
                    border.width: root.s(1)
                    border.color: root.wpKillActive ? mocha.mauve : (wpMa.containsMouse ? mocha.surface2 : Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.35))
                    Behavior on color { ColorAnimation { duration: Motion.fadeMs } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: root.s(6)

                        Text {
                            text: "󰸉"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: root.s(13)
                            color: root.wpKillActive ? mocha.mauve : mocha.subtext1
                        }

                        Text {
                            text: "No Wallpaper"
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: root.s(10)
                            color: root.wpKillActive ? mocha.text : mocha.subtext0
                        }
                    }

                    MouseArea {
                        id: wpMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/mode_ctl.sh", "toggle", "wallpaper-kill"])
                    }
                }

                // 2. Gaming Mode
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(34)
                    radius: root.s(8)
                    color: root.gamingActive ? Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.18) : (gameMa.containsMouse ? mocha.surface1 : mocha.surface0)
                    border.width: root.s(1)
                    border.color: root.gamingActive ? mocha.red : (gameMa.containsMouse ? mocha.surface2 : Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.35))
                    Behavior on color { ColorAnimation { duration: Motion.fadeMs } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: root.s(6)

                        Text {
                            text: "󰊖"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: root.s(13)
                            color: root.gamingActive ? mocha.red : mocha.subtext1
                        }

                        Text {
                            text: "Gaming"
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: root.s(10)
                            color: root.gamingActive ? mocha.text : mocha.subtext0
                        }
                    }

                    MouseArea {
                        id: gameMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/mode_ctl.sh", "toggle", "gaming"])
                    }
                }

                // 3. Power Saver
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(34)
                    radius: root.s(8)
                    color: root.powerSaverActive ? Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.18) : (psMa.containsMouse ? mocha.surface1 : mocha.surface0)
                    border.width: root.s(1)
                    border.color: root.powerSaverActive ? mocha.green : (psMa.containsMouse ? mocha.surface2 : Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.35))
                    Behavior on color { ColorAnimation { duration: Motion.fadeMs } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: root.s(6)

                        Text {
                            text: "󰌪"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: root.s(13)
                            color: root.powerSaverActive ? mocha.green : mocha.subtext1
                        }

                        Text {
                            text: "Power Saver"
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: root.s(10)
                            color: root.powerSaverActive ? mocha.text : mocha.subtext0
                        }
                    }

                    MouseArea {
                        id: psMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/mode_ctl.sh", "toggle", "power-saver"])
                    }
                }

                // 4. Coffee
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(34)
                    radius: root.s(8)
                    color: root.coffeeActive ? Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.18) : (coffeeMa.containsMouse ? mocha.surface1 : mocha.surface0)
                    border.width: root.s(1)
                    border.color: root.coffeeActive ? mocha.yellow : (coffeeMa.containsMouse ? mocha.surface2 : Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.35))
                    Behavior on color { ColorAnimation { duration: Motion.fadeMs } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: root.s(6)

                        Text {
                            text: "󰅶"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: root.s(13)
                            color: root.coffeeActive ? mocha.yellow : mocha.subtext1
                        }

                        Text {
                            text: "Coffee"
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: root.s(10)
                            color: root.coffeeActive ? mocha.text : mocha.subtext0
                        }
                    }

                    MouseArea {
                        id: coffeeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SysData.setCoffee(!root.coffeeActive)
                    }
                }

                // 5. Broadcast
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(34)
                    radius: root.s(8)
                    color: root.broadcastActive ? Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.18) : (bcMa.containsMouse ? mocha.surface1 : mocha.surface0)
                    border.width: root.s(1)
                    border.color: root.broadcastActive ? mocha.blue : (bcMa.containsMouse ? mocha.surface2 : Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.35))
                    Behavior on color { ColorAnimation { duration: Motion.fadeMs } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: root.s(6)

                        Text {
                            text: "󰍫"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: root.s(13)
                            color: root.broadcastActive ? mocha.blue : mocha.subtext1
                        }

                        Text {
                            text: "Broadcast"
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: root.s(10)
                            color: root.broadcastActive ? mocha.text : mocha.subtext0
                        }
                    }

                    MouseArea {
                        id: bcMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/toggle_multi_sink.sh"])
                    }
                }
            }

            // =================================================================
            // Telemetry Cards Grid (2x2)
            // =================================================================
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: root.s(12)
                rowSpacing: root.s(12)

                // 1. CPU Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(70)
                    radius: root.s(10)
                    color: mocha.surface0
                    border.width: root.s(1)
                    border.color: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.35)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: root.s(12)
                        spacing: root.s(6)

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "󰍛 CPU Load"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(11)
                                color: mocha.text
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: SysData.cpu + "%  •  " + SysData.temp + "°C"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(11)
                                color: SysData.cpu > 80 ? mocha.red : (SysData.cpu > 50 ? mocha.yellow : mocha.blue)
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.s(6)
                            radius: height / 2
                            color: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.40)

                            Rectangle {
                                width: Math.max(0, Math.min(parent.width, parent.width * (SysData.cpu / 100.0)))
                                height: parent.height
                                radius: height / 2
                                color: SysData.cpu > 80 ? mocha.red : (SysData.cpu > 50 ? mocha.yellow : mocha.blue)
                                Behavior on width { NumberAnimation { duration: Motion.moveMs; easing.type: Motion.moveEasing } }
                            }
                        }
                    }
                }

                // 2. RAM Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(70)
                    radius: root.s(10)
                    color: mocha.surface0
                    border.width: root.s(1)
                    border.color: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.35)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: root.s(12)
                        spacing: root.s(6)

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "󰘚 Memory"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(11)
                                color: mocha.text
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: SysData.ramGb.toFixed(1) + " GB  (" + SysData.ramPercent + "%)"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(11)
                                color: SysData.ramPercent > 85 ? mocha.red : mocha.mauve
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.s(6)
                            radius: height / 2
                            color: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.40)

                            Rectangle {
                                width: Math.max(0, Math.min(parent.width, parent.width * (SysData.ramPercent / 100.0)))
                                height: parent.height
                                radius: height / 2
                                color: SysData.ramPercent > 85 ? mocha.red : mocha.mauve
                                Behavior on width { NumberAnimation { duration: Motion.moveMs; easing.type: Motion.moveEasing } }
                            }
                        }
                    }
                }

                // 3. Battery Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(70)
                    radius: root.s(10)
                    color: mocha.surface0
                    border.width: root.s(1)
                    border.color: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.35)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: root.s(12)
                        spacing: root.s(6)

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: (SysData.acOnline ? "󰂄 Battery (AC Connected)" : "󰁹 Battery (Discharging)")
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(11)
                                color: mocha.text
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: SysData.batCapacity + "%"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(11)
                                color: SysData.batCapacity <= 20 ? mocha.red : mocha.green
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.s(6)
                            radius: height / 2
                            color: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.40)

                            Rectangle {
                                width: Math.max(0, Math.min(parent.width, parent.width * (SysData.batCapacity / 100.0)))
                                height: parent.height
                                radius: height / 2
                                color: SysData.batCapacity <= 20 ? mocha.red : mocha.green
                                Behavior on width { NumberAnimation { duration: Motion.moveMs; easing.type: Motion.moveEasing } }
                            }
                        }
                    }
                }

                // 4. Network I/O Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(70)
                    radius: root.s(10)
                    color: mocha.surface0
                    border.width: root.s(1)
                    border.color: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.35)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: root.s(12)
                        spacing: root.s(6)

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "󰖩 Network I/O"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(11)
                                color: mocha.text
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: (SysData.onBattery ? "60Hz" : "120Hz") + " • Active"
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(10)
                                color: mocha.teal
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "↓ " + root.formatRate(SysData.netRx)
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(11)
                                color: mocha.peach
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "↑ " + root.formatRate(SysData.netTx)
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: root.s(11)
                                color: mocha.sapphire
                            }
                        }
                    }
                }
            }

            // =================================================================
            // Top Active Tasks Table
            // =================================================================
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.s(8)

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "TOP ACTIVE PROCESSES"
                        font.family: "JetBrains Mono"
                        font.weight: Font.Bold
                        font.pixelSize: root.s(10)
                        color: mocha.subtext1
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "Refresh: 2s • ESC to exit"
                        font.family: "JetBrains Mono"
                        font.pixelSize: root.s(10)
                        color: mocha.overlay1
                    }
                }

                // Table Header Container
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(28)
                    radius: root.s(6)
                    color: mocha.surface1
                    border.width: root.s(1)
                    border.color: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.35)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.s(14)
                        anchors.rightMargin: root.s(14)
                        spacing: root.s(8)

                        Text { Layout.preferredWidth: root.s(230); text: "NAME"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(10); color: mocha.subtext0 }
                        Text { Layout.preferredWidth: root.s(70); text: "PID"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(10); color: mocha.subtext0 }
                        Text { Layout.preferredWidth: root.s(80); text: "CPU %"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(10); color: mocha.subtext0; horizontalAlignment: Text.AlignRight }
                        Text { Layout.preferredWidth: root.s(80); text: "MEM %"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(10); color: mocha.subtext0; horizontalAlignment: Text.AlignRight }
                        Item { Layout.fillWidth: true }
                        Text { Layout.preferredWidth: root.s(70); text: "ACTION"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(10); color: mocha.subtext0; horizontalAlignment: Text.AlignCenter }
                    }
                }

                // Process Table Body
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: root.s(8)
                    color: mocha.surface0
                    border.width: root.s(1)
                    border.color: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.35)
                    clip: true

                    ListView {
                        id: procList
                        anchors.fill: parent
                        anchors.margins: root.s(4)
                        clip: true
                        spacing: root.s(2)
                        model: processModel

                        delegate: Rectangle {
                            width: procList.width
                            height: root.s(32)
                            radius: root.s(6)
                            color: rowMa.containsMouse ? mocha.surface1 : "transparent"
                            Behavior on color { ColorAnimation { duration: Motion.fadeMs } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: root.s(10)
                                anchors.rightMargin: root.s(10)
                                spacing: root.s(8)

                                Text {
                                    Layout.preferredWidth: root.s(230)
                                    text: model.name || ""
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Bold
                                    font.pixelSize: root.s(11)
                                    color: mocha.text
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.preferredWidth: root.s(70)
                                    text: model.pid || ""
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: root.s(11)
                                    color: mocha.subtext0
                                }

                                Text {
                                    Layout.preferredWidth: root.s(80)
                                    text: (model.cpu || "0.0") + "%"
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Bold
                                    font.pixelSize: root.s(11)
                                    color: parseFloat(model.cpu) > 40 ? mocha.red : (parseFloat(model.cpu) > 15 ? mocha.yellow : mocha.blue)
                                    horizontalAlignment: Text.AlignRight
                                }

                                Text {
                                    Layout.preferredWidth: root.s(80)
                                    text: (model.mem || "0.0") + "%"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: root.s(11)
                                    color: mocha.mauve
                                    horizontalAlignment: Text.AlignRight
                                }

                                Item { Layout.fillWidth: true }

                                // Kill Process Pill
                                Rectangle {
                                    Layout.preferredWidth: root.s(56)
                                    Layout.preferredHeight: root.s(22)
                                    radius: root.s(5)
                                    color: killMa.containsMouse ? Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.22) : Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.35)
                                    border.width: root.s(1)
                                    border.color: killMa.containsMouse ? mocha.red : "transparent"
                                    Behavior on color { ColorAnimation { duration: Motion.fadeMs } }
                                    Behavior on border.color { ColorAnimation { duration: Motion.fadeMs } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: root.s(3)

                                        Text {
                                            text: "󰅖"
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: root.s(10)
                                            color: killMa.containsMouse ? mocha.red : mocha.subtext0
                                        }

                                        Text {
                                            text: "End"
                                            font.family: "JetBrains Mono"
                                            font.weight: Font.Bold
                                            font.pixelSize: root.s(10)
                                            color: killMa.containsMouse ? mocha.red : mocha.subtext0
                                        }
                                    }

                                    MouseArea {
                                        id: killMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Quickshell.execDetached(["kill", "-15", model.pid]);
                                            root.refreshProcesses();
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: rowMa
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }
                        }
                    }
                }
            }
        }
    }
}
