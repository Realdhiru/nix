import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Io
import QtQuick.Window
import "../"

Item {
    id: window

    property real layoutWidth
    property real layoutHeight
    width: layoutWidth
    height: layoutHeight

    // --- Responsive Scaling Logic ---
    Scaler {
        id: scaler
        currentWidth: Screen.width
    }
    
    readonly property real sf: scaler.baseScale

    function s(val) { 
        return Math.round(val * window.sf); 
    }

    // -------------------------------------------------------------------------
    // DYNAMIC MASTER WINDOW SCALING (Dimensions defined via WindowRegistry)
    // -------------------------------------------------------------------------
    property real targetMasterHeight: Math.min(Math.floor(Screen.height * 0.92), Math.round(510 * window.sf))
    property real targetMasterWidth: Math.min(Math.floor(Screen.width * 0.94), Math.round(1450 * window.sf))


    // -------------------------------------------------------------------------
    // KEYBOARD SHORTCUTS
    // -------------------------------------------------------------------------
    Shortcut { 
        sequence: "Left"
        enabled: window.visible
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset - 1);
            } else {
                window.setWeatherView(window.targetWeatherView - 1);
            }
        }
    }

    Shortcut { 
        sequence: "Right"
        enabled: window.visible
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset + 1);
            } else {
                window.setWeatherView(window.targetWeatherView + 1);
            }
        }
    }

    // -------------------------------------------------------------------------
    // COLORS (Dynamic Wallust Palette)
    // -------------------------------------------------------------------------
    Theme { id: _theme }
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext1: _theme.subtext1
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay2: _theme.overlay2
    readonly property color overlay1: _theme.overlay1
    readonly property color overlay0: _theme.overlay0
    readonly property color surface2: _theme.surface2
    readonly property color surface1: _theme.surface1
    readonly property color surface0: _theme.surface0
    
    readonly property color mauve: _theme.mauve
    readonly property color pink: _theme.pink
    readonly property color blue: _theme.blue
    readonly property color sapphire: _theme.sapphire
    readonly property color peach: _theme.peach
    readonly property color yellow: _theme.yellow
    readonly property color teal: _theme.teal
    readonly property color green: _theme.green
    readonly property color red: _theme.red

    readonly property color primary: _theme.primary

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/calendar"

    // -------------------------------------------------------------------------
    // DYNAMIC THEME HARMONIZED COLORS
    // -------------------------------------------------------------------------
    readonly property color timeColor: {
        let src = Config.clockColorSource;
        if (src && src !== "auto" && window[src]) return window[src];
        return window.text;
    }

    readonly property color activeAccent: {
        let src = Config.accentColorSource;
        if (src && src !== "auto" && window[src]) return window[src];
        return window.primary;
    }

    readonly property color timeAccent: activeAccent

    readonly property color textAccent: Qt.tint(window.activeAccent, Qt.alpha(window.text, 0.35))

    // -------------------------------------------------------------------------
    // CARD MOTION STATE
    // -------------------------------------------------------------------------
    property bool startupComplete: true

    // -------------------------------------------------------------------------
    // STATE & TIME (WITH SECOND PULSE)
    // -------------------------------------------------------------------------
    property real remoteTimezoneSec: window.weatherData && window.weatherData.timezone ? parseInt(window.weatherData.timezone) : -(new Date().getTimezoneOffset() * 60)

    property var currentTime: {
        let now = new Date();
        let localOffsetSec = -(now.getTimezoneOffset() * 60);
        let diffSec = remoteTimezoneSec - localOffsetSec;
        return new Date(now.getTime() + (diffSec * 1000));
    }
    property real currentEpoch: currentTime.getTime() / 1000

    Timer {
        interval: 1000; running: window.visible; repeat: true
        onTriggered: {
            let now = new Date();
            let localOffsetSec = -(now.getTimezoneOffset() * 60);
            let diffSec = remoteTimezoneSec - localOffsetSec;
            window.currentTime = new Date(now.getTime() + (diffSec * 1000));

            if (window.currentTime.getHours() === 0 && window.currentTime.getMinutes() === 0 && window.currentTime.getSeconds() === 0) {
                updateCalendarGrid();
            }
        }
    }

    // -------------------------------------------------------------------------
    // WEATHER DATA & ELEGANT TRANSITIONS (3D ORBIT SPIN)
    // -------------------------------------------------------------------------
    property var weatherData: null
    property int weatherView: 0
    property color activeWeatherHex: {
        if (!window.weatherData) return window.activeAccent;
        if (window.weatherView === 0 && window.weatherData.current_hex) return window.weatherData.current_hex;
        if (window.weatherData.forecast && window.weatherData.forecast[window.weatherView]) return window.weatherData.forecast[window.weatherView].hex;
        return window.activeAccent;
    }

    property int targetWeatherView: 0
    property real weatherContentOpacity: 1.0

    // -------------------------------------------------------------------------
    // TEMPERATURE LOGIC 
    // -------------------------------------------------------------------------
    property real targetTemp: {
        if (!window.weatherData) return 0;
        if (window.targetWeatherView === 0 && window.weatherData.current_temp !== undefined) {
            return Number(window.weatherData.current_temp);
        }
        if (window.weatherData.forecast && window.weatherData.forecast[window.targetWeatherView]) {
            return Number(window.weatherData.forecast[window.targetWeatherView].max);
        }
        return 0;
    }
    
    property real displayedTemp: targetTemp

    Behavior on displayedTemp {
        NumberAnimation {
            id: tempAnim
            duration: Motion.moveMs
            easing.type: Motion.moveEasing
        }
    }

    property bool isTempAnimating: tempAnim.running
    property color tempGlowColor: {
        if (!isTempAnimating || !window.startupComplete) return window.text;
        if (window.targetTemp > window.displayedTemp) return window.red;
        if (window.targetTemp < window.displayedTemp) return window.blue;
        return window.text; 
    }

    SequentialAnimation {
        id: weatherTransitionAnim
        NumberAnimation { target: window; property: "weatherContentOpacity"; to: 0.0; duration: Motion.exitMs; easing.type: Motion.exitEasing }
        ScriptAction { script: window.weatherView = window.targetWeatherView }
        NumberAnimation { target: window; property: "weatherContentOpacity"; to: 1.0; duration: Motion.enterMs; easing.type: Motion.enterEasing }
    }

    function setWeatherView(idx) {
        if (idx < 0 || idx > 4 || !window.weatherData) return;
        if (idx === window.targetWeatherView) return;

        if (weatherTransitionAnim.running) {
            weatherTransitionAnim.stop();
            window.weatherView = window.targetWeatherView;
        }

        window.targetWeatherView = idx;
        weatherTransitionAnim.start();
    }

    property int activeHourIndex: {
        if (window.weatherView !== 0 || !window.weatherData || !window.weatherData.forecast || !window.weatherData.forecast[0] || !window.weatherData.forecast[0].hourly) return -1;
        
        let ch = window.currentTime.getHours();
        let hrArr = window.weatherData.forecast[0].hourly.slice(0, 8);
        let bestIdx = -1;
        let minDiff = 999;
        
        for (let i = 0; i < hrArr.length; i++) {
            let timeStr = hrArr[i].time || "00:00";
            let h = parseInt(timeStr.split(":")[0]);
            let diff = Math.abs(h - ch);
            if (diff < minDiff) {
                minDiff = diff;
                bestIdx = i;
            }
        }
        return bestIdx !== -1 ? bestIdx : 0;
    }

    Process {
        id: weatherPoller
        command: ["bash", window.scriptsDir + "/weather.sh", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try { window.weatherData = JSON.parse(txt); } catch(e) {}
                }
            }
        }
    }

    Timer {
        interval: 150000
        running: window.visible; repeat: true
        onTriggered: weatherPoller.running = true
    }

    // -------------------------------------------------------------------------
    // CALENDAR GRID LOGIC & TRANSITIONS
    // -------------------------------------------------------------------------
    property int monthOffset: 0
    property int targetMonthOffset: 0
    property string targetMonthName: ""
    ListModel { id: calendarModel }

    property real calendarContentOpacity: 1.0

    SequentialAnimation {
        id: calendarTransitionAnim
        NumberAnimation { target: window; property: "calendarContentOpacity"; to: 0.0; duration: Motion.exitMs; easing.type: Motion.exitEasing }
        ScriptAction { script: window.monthOffset = window.targetMonthOffset }
        NumberAnimation { target: window; property: "calendarContentOpacity"; to: 1.0; duration: Motion.enterMs; easing.type: Motion.enterEasing }
    }

    function setMonthOffset(newOffset) {
        if (newOffset === window.targetMonthOffset) return;

        if (calendarTransitionAnim.running) {
            calendarTransitionAnim.stop();
            window.monthOffset = window.targetMonthOffset;
        }

        window.targetMonthOffset = newOffset;
        calendarTransitionAnim.start();
    }

    function updateCalendarGrid() {
        let d = new Date(window.currentTime.getTime());
        d.setDate(1);
        d.setMonth(d.getMonth() + window.monthOffset);

        let targetMonth = d.getMonth();
        let targetYear = d.getFullYear();

        let actualToday = new Date();
        let isRealCurrentMonth = (actualToday.getMonth() === targetMonth && actualToday.getFullYear() === targetYear);
        let todayDate = actualToday.getDate();

        window.targetMonthName = Qt.formatDateTime(d, "MMMM yyyy");

        let firstDay = new Date(targetYear, targetMonth, 1).getDay();
        firstDay = (firstDay === 0) ? 6 : firstDay - 1;

        let daysInMonth = new Date(targetYear, targetMonth + 1, 0).getDate();
        let daysInPrevMonth = new Date(targetYear, targetMonth, 0).getDate();

        calendarModel.clear();

        let batch = [];

        for (let i = firstDay - 1; i >= 0; i--) {
            batch.push({ dayNum: (daysInPrevMonth - i).toString(), isCurrentMonth: false, isToday: false });
        }
        for (let i = 1; i <= daysInMonth; i++) {
            batch.push({ dayNum: i.toString(), isCurrentMonth: true, isToday: (isRealCurrentMonth && i === todayDate) });
        }
        let remaining = 42 - batch.length;
        for (let i = 1; i <= remaining; i++) {
            batch.push({ dayNum: i.toString(), isCurrentMonth: false, isToday: false });
        }

        calendarModel.append(batch);
    }

    onMonthOffsetChanged: updateCalendarGrid()

    Component.onCompleted: {
        updateCalendarGrid();
    }

    // -------------------------------------------------------------------------
    // UI LAYOUT
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        transformOrigin: Item.Center
        opacity: window.visible ? 1.0 : 0.0
        scale: window.visible ? 1.0 : 0.96

        Behavior on opacity {
            NumberAnimation { duration: window.visible ? Motion.enterMs : Motion.exitMs; easing.type: window.visible ? Motion.enterEasing : Motion.exitEasing }
        }
        Behavior on scale {
            NumberAnimation { duration: window.visible ? Motion.enterMs : Motion.exitMs; easing.type: window.visible ? Motion.enterEasing : Motion.exitEasing }
        }

        Rectangle {
            id: mainCardRect
            anchors.fill: parent
            radius: Math.round(20 * window.sf)
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


            // =======================================================
            // AMBIENT WIDGET COLOR BLOBS
            // =======================================================
            Rectangle {
                width: parent.width * 0.5; height: width; radius: width / 2
                x: parent.width * 0.75 - width / 2
                y: parent.height * 0.3 - height / 2
                opacity: 0.025
                color: window.activeWeatherHex
                Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
            }

            Rectangle {
                width: parent.width * 0.6; height: width; radius: width / 2
                x: parent.width * 0.25 - width / 2
                y: parent.height * 0.7 - height / 2
                opacity: 0.02
                color: window.timeColor
                Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
            }

            Rectangle {
                width: parent.width * 0.45; height: width; radius: width / 2
                x: parent.width * 0.5 - width / 2
                y: parent.height * 0.5 - height / 2
                opacity: 0.015
                color: window.timeAccent
                Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
            }

            // Big Parallax Weather Icon
            Text {
                id: heroIcon
                anchors.centerIn: parent
                text: {
                    if (!window.weatherData) return "";
                    if (window.weatherView === 0 && window.weatherData.current_icon) return window.weatherData.current_icon;
                    if (window.weatherData.forecast && window.weatherData.forecast[window.weatherView]) return window.weatherData.forecast[window.weatherView].icon;
                    return "";
                }
                font.family: "Iosevka Nerd Font"
                font.pixelSize: Math.round(800 * window.sf)
                color: window.activeWeatherHex
                opacity: 0.03 * window.weatherContentOpacity
                z: 0
                Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
            }

            // =======================================================
            // CENTRAL HERO: THE TIME HUB & HOURLY ORBIT
            // =======================================================
            Item {
                id: centralHub
                anchors.centerIn: parent
                width: Math.round(1 * window.sf); height: Math.round(1 * window.sf) 
                z: 5

                Canvas {
                    id: orbitCanvas
                    z: -10
                    x: Math.round(-400 * window.sf)   
                    y: Math.round(-200 * window.sf)   
                    width: Math.round(800 * window.sf)
                    height: Math.round(400 * window.sf)
                    opacity: 0.25

                    onWidthChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.beginPath();
                        var currentRx = Math.min(Math.round(290 * window.sf), Math.max(Math.round(180 * window.sf), (window.width - Math.round(680 * window.sf)) / 2));
                        var currentRy = Math.min(Math.round(135 * window.sf), Math.max(Math.round(90 * window.sf), (window.height - Math.round(160 * window.sf)) / 2));
                        for (var i = 0; i <= Math.PI * 2; i += 0.05) {
                            var xx = width/2 + Math.cos(i) * currentRx;
                            var yy = height/2 + Math.sin(i) * currentRy;
                            if (i === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy);
                        }
                        ctx.strokeStyle = window.textAccent;
                        ctx.lineWidth = Math.max(1, Math.round(1.5 * window.sf));
                        ctx.setLineDash([Math.round(4 * window.sf), Math.round(10 * window.sf)]);
                        ctx.stroke();
                    }
                }

                // Core Clock
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    z: 0 
                    
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Math.round(2 * window.sf)
                        Text {
                            text: Qt.formatTime(window.currentTime, "HH:mm")
                            font.family: "JetBrains Mono"
                            font.weight: Font.Black
                            font.pixelSize: Math.round(84 * window.sf)
                            color: window[Config.clockColorSource] || window.text
                            style: Text.Outline; styleColor: Qt.alpha(window.crust, 0.4)
                        }
                        Text {
                            text: Qt.formatTime(window.currentTime, ":ss")
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: Math.round(32 * window.sf)
                            color: window.textAccent
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: Math.round(15 * window.sf)
                            opacity: 0.6
                            style: Text.Outline; styleColor: Qt.alpha(window.crust, 0.4)
                            Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDateTime(window.currentTime, "dddd, MMMM dd")
                        font.family: "JetBrains Mono"
                        font.weight: Font.Bold
                        font.pixelSize: Math.round(16 * window.sf)
                        color: window.subtext0
                        opacity: 0.9
                    }
                }

                // TRUE 3D ORBITAL HOURLY FORECAST 
                Item {
                    anchors.fill: parent
                    opacity: window.weatherContentOpacity

                    Repeater {
                        id: hourRepeater
                        model: window.weatherData && window.weatherData.forecast[window.weatherView] && window.weatherData.forecast[window.weatherView].hourly ? window.weatherData.forecast[window.weatherView].hourly.slice(0, 8) : []
                        
                        delegate: Item {
                            property int mCount: hourRepeater.count
                            property bool isToday: window.weatherView === 0
                            property bool isHighlighted: isToday && index === window.activeHourIndex
                            
                            property real rx: Math.min(Math.round(290 * window.sf), Math.max(Math.round(180 * window.sf), (window.width - Math.round(680 * window.sf)) / 2))
                            property real ry: Math.min(Math.round(135 * window.sf), Math.max(Math.round(90 * window.sf), (window.height - Math.round(160 * window.sf)) / 2))
                            
                            property int relIdx: isToday ? (index - window.activeHourIndex) : index
                            
                            property real targetAngleDeg: {
                                let count = Math.max(1, mCount);
                                let step = 360 / count;
                                return isToday ? (90 + (relIdx * step)) : (index * step);
                            }
                            
                            property real rad: targetAngleDeg * (Math.PI / 180)

                            x: Math.cos(rad) * rx - width/2
                            y: Math.sin(rad) * ry - height/2
                            z: Math.sin(rad) * Math.round(100 * window.sf) 
                            
                            scale: isHighlighted ? 1.15 : (isToday ? (0.92 + 0.12 * Math.sin(rad)) : (0.88 + 0.14 * Math.sin(rad)))
                            opacity: isHighlighted ? 1.0 : (isToday ? (0.7 + 0.3 * ((Math.sin(rad) + 1) / 2)) : (0.65 + 0.35 * ((Math.sin(rad) + 1) / 2)))

                            width: Math.round(48 * window.sf); height: Math.round(78 * window.sf)
                            
                            Rectangle {
                                anchors.fill: parent
                                radius: Math.round(24 * window.sf)
                                color: isHighlighted ? window.textAccent : (hrMa.containsMouse ? Qt.rgba(window.text.r, window.text.g, window.text.b, 0.18) : Qt.rgba(window.text.r, window.text.g, window.text.b, 0.08))
                                border.color: isHighlighted ? "transparent" : (hrMa.containsMouse ? window.textAccent : Qt.alpha(window.surface1, 0.3))
                                border.width: Config.borderWidth
                                
                                Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                
                                ColumnLayout {
                                    anchors.centerIn: parent 
                                    spacing: Math.round(2 * window.sf)
                                    
                                    Text { 
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.time
                                        font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: Math.round(10 * window.sf)
                                        color: isHighlighted ? window.base : (hrMa.containsMouse ? window.text : window.overlay1)
                                    }
                                    
                                    Text { 
                                        id: weatherIconText
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.icon || (window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].icon : "")
                                        font.family: "Iosevka Nerd Font"; font.pixelSize: Math.round(15 * window.sf)
                                        color: isHighlighted ? window.base : (modelData.hex || window.text)
                                        
                                        property real hoverLift: hrMa.containsMouse ? Math.round(-3 * window.sf) : 0
                                        Behavior on hoverLift { NumberAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                        transform: Translate { y: weatherIconText.hoverLift }
                                    }
                                    
                                    Text { 
                                        Layout.alignment: Qt.AlignHCenter; text: modelData.temp + "°"
                                        font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: Math.round(12 * window.sf)
                                        color: isHighlighted ? window.base : window.text 
                                    }
                                }
                            }
                            MouseArea { id: hrMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }

            // =======================================================
            // LEFT WING: FLOATING GLASS CALENDAR
            // ==========================================
            Rectangle {
                id: calendarRect
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Math.round(40 * window.sf)
                width: Math.round(320 * window.sf)
                height: Math.round(420 * window.sf)
                color: "transparent"
                radius: Math.round(14 * window.sf)
                border.color: "transparent"
                border.width: 0
                z: 10 

                HoverHandler { id: calHover }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(25 * window.sf)
                    spacing: Math.round(15 * window.sf)

                    // Year Percentage Bar
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: Math.round(10 * window.sf)
                        spacing: Math.round(10 * window.sf)
                        
                        property int currentYear: window.currentTime.getFullYear()
                        property bool isLeapYear: (currentYear % 4 === 0 && currentYear % 100 !== 0) || (currentYear % 400 === 0)
                        property int daysInYear: isLeapYear ? 366 : 365
                        property int dayOfYear: Math.floor((window.currentTime - new Date(currentYear, 0, 0)) / (1000 * 60 * 60 * 24))
                        property real yearPct: dayOfYear / daysInYear
                        
                        Text {
                            text: parent.currentYear.toString()
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: Math.round(11 * window.sf)
                            color: window.subtext0
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.round(4 * window.sf)
                            radius: Math.round(2 * window.sf)
                            color: Qt.rgba(window.text.r, window.text.g, window.text.b, 0.08)
                            
                                Rectangle {
                                    width: parent.width * parent.parent.yearPct
                                    height: parent.height
                                    radius: parent.radius
                                    color: window.textAccent
                                    Behavior on width { enabled: window.visible; NumberAnimation { duration: Motion.moveMs; easing.type: Motion.moveEasing } }
                                }
                        }
                        
                        Text {
                            text: Math.round(parent.yearPct * 100).toString() + "%"
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: Math.round(11 * window.sf)
                            color: window.subtext0
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        
                        Rectangle {
                            Layout.preferredWidth: Math.round(32 * window.sf); Layout.preferredHeight: Math.round(32 * window.sf); radius: Math.round(16 * window.sf)
                            color: homeMa.containsMouse ? window.surface1 : "transparent"
                            opacity: window.targetMonthOffset !== 0 ? 1.0 : 0.0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                            Text { anchors.centerIn: parent; text: "󰃭"; font.family: "Iosevka Nerd Font"; color: window.text; font.pixelSize: Math.round(16 * window.sf) }
                            MouseArea { 
                                id: homeMa; anchors.fill: parent; hoverEnabled: window.targetMonthOffset !== 0; 
                                onClicked: if (window.targetMonthOffset !== 0) window.setMonthOffset(0) 
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: Math.round(32 * window.sf); Layout.preferredHeight: Math.round(32 * window.sf); radius: Math.round(16 * window.sf)
                            color: prevMa.containsMouse ? window.surface1 : "transparent"
                            Text { anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; color: window.text; font.pixelSize: Math.round(16 * window.sf) }
                            MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true; onClicked: window.setMonthOffset(window.targetMonthOffset - 1) }
                        }
                        
                        Text {
                            Layout.fillWidth: true
                            text: window.targetMonthName.toUpperCase()
                            font.family: "JetBrains Mono"
                            font.weight: Font.Black
                            font.pixelSize: Math.round(16 * window.sf)
                            fontSizeMode: Text.Fit
                            minimumPixelSize: Math.round(8 * window.sf)
                            color: window.text
                            horizontalAlignment: Text.AlignHCenter
                            
                            opacity: window.calendarContentOpacity
                        }

                        Rectangle {
                            Layout.preferredWidth: Math.round(32 * window.sf); Layout.preferredHeight: Math.round(32 * window.sf); radius: Math.round(16 * window.sf)
                            color: nextMa.containsMouse ? window.surface1 : "transparent"
                            Text { anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; color: window.text; font.pixelSize: Math.round(16 * window.sf) }
                            MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true; onClicked: window.setMonthOffset(window.targetMonthOffset + 1) }
                        }

                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Repeater {
                            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                font.family: "JetBrains Mono"
                                font.weight: Font.Black
                                font.pixelSize: Math.round(14 * window.sf)
                                color: window.overlay0
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        rowSpacing: Math.round(6 * window.sf)
                        columnSpacing: Math.round(6 * window.sf)

                        opacity: window.calendarContentOpacity

                        Repeater {
                            model: calendarModel
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                
                                color: isToday ? window.textAccent : (dayMa.containsMouse ? Qt.alpha(window.surface2, 0.4) : "transparent")
                                radius: Math.round(10 * window.sf)
                                scale: dayMa.containsMouse ? 1.2 : 1.0
                                border.color: isToday ? window.textAccent : (dayMa.containsMouse ? window.overlay0 : "transparent")
                                border.width: dayMa.containsMouse ? Config.borderWidth : 0
                                
                                Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                Behavior on scale { NumberAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }

                                Text {
                                    anchors.centerIn: parent
                                    text: dayNum
                                    font.family: "JetBrains Mono"
                                    font.weight: isToday ? Font.Black : Font.Bold
                                    font.pixelSize: Math.round(14 * window.sf)
                                    color: isToday ? window.base : (isCurrentMonth ? window.text : Qt.alpha(window.text, 0.25))
                                    Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                }

                                MouseArea { id: dayMa; anchors.fill: parent; hoverEnabled: true }
                            }
                        }
                    }
                }
            }

            // =======================================================
            // RIGHT WING: ORGANIC FLOATING WEATHER STATS
            // =======================================================
            Item {
                id: weatherStats
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Math.round(40 * window.sf)
                width: Math.round(320 * window.sf)
                height: Math.round(420 * window.sf)
                z: 10 

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Math.round(20 * window.sf)
                    
                    Process {
                        id: searchCityProc
                        property string query: ""
                        command: ["bash", "-c", window.scriptsDir + "/search_city.sh '" + query + "'"]
                        running: false
                        stdout: StdioCollector {
                            onStreamFinished: {
                                searchResultsModel.clear();
                                try {
                                    let json = JSON.parse(this.text);
                                    for (let i = 0; i < json.length; i++) {
                                        searchResultsModel.append(json[i]);
                                    }
                                    searchResultsList.visible = true;
                                } catch(e) {}
                            }
                        }
                    }

                    Process {
                        id: setCityProc
                        property string cityId: ""
                        command: ["bash", "-c", window.scriptsDir + "/set_city.sh " + cityId]
                        running: false
                        onExited: {
                            weatherPoller.running = false;
                            weatherPoller.running = true;
                        }
                    }

                    // CITY SEARCH UI
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(10 * window.sf)
                        
                        TextField {
                            id: citySearchInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.round(36 * window.sf)
                            placeholderText: "Search city..."
                            font.family: "JetBrains Mono"
                            font.pixelSize: Math.round(12 * window.sf)
                            color: window.text
                            placeholderTextColor: window.overlay0
                            background: Rectangle {
                                color: Qt.rgba(window.text.r, window.text.g, window.text.b, 0.08)
                                radius: Math.round(18 * window.sf)
                                border.color: citySearchInput.activeFocus ? window.textAccent : "transparent"
                                border.width: Config.borderWidth
                            }
                            leftPadding: Math.round(15 * window.sf)
                            rightPadding: Math.round(15 * window.sf)
                            
                            Timer {
                                id: searchDebouncer
                                interval: 400
                                onTriggered: {
                                    if (citySearchInput.text.length > 2) {
                                        searchCityProc.query = citySearchInput.text;
                                        searchCityProc.running = false;
                                        searchCityProc.running = true;
                                    }
                                }
                            }

                            onTextEdited: {
                                if (text.length > 2) {
                                    searchDebouncer.restart();
                                } else {
                                    searchDebouncer.stop();
                                    searchResultsList.visible = false;
                                    searchResultsModel.clear();
                                }
                            }
                            
                            onAccepted: {
                                if (text.length > 2) {
                                    searchDebouncer.stop();
                                    searchCityProc.query = text;
                                    searchCityProc.running = false;
                                    searchCityProc.running = true;
                                }
                            }
                        }
                        
                        ListModel { id: searchResultsModel }
                        
                        ListView {
                            id: searchResultsList
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(count * Math.round(40 * window.sf), Math.round(160 * window.sf))
                            model: searchResultsModel
                            visible: false
                            clip: true
                            spacing: Math.round(4 * window.sf)
                            
                            delegate: Rectangle {
                                width: searchResultsList.width
                                height: Math.round(36 * window.sf)
                                radius: Math.round(8 * window.sf)
                                color: itemMa.containsMouse ? Qt.rgba(window.text.r, window.text.g, window.text.b, 0.18) : Qt.rgba(window.text.r, window.text.g, window.text.b, 0.08)
                                
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: Math.round(15 * window.sf)
                                    text: model.name + ", " + model.country
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: Math.round(12 * window.sf)
                                    color: window.text
                                }
                                
                                MouseArea {
                                    id: itemMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchResultsList.visible = false;
                                        citySearchInput.text = "";
                                        setCityProc.cityId = model.id;
                                        setCityProc.running = true;
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight | Qt.AlignTop
                        spacing: Math.round(20 * window.sf)
                        
                        MouseArea { 
                            id: wPrevMa; Layout.preferredWidth: Math.round(30 * window.sf); Layout.preferredHeight: Math.round(30 * window.sf); hoverEnabled: true
                            onClicked: window.setWeatherView(window.targetWeatherView - 1) 
                            
                            Text { 
                                id: prevArrowIcon
                                anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: Math.round(18 * window.sf)
                                color: wPrevMa.containsMouse ? window.textAccent : window.overlay1
                                property real hoverShift: wPrevMa.containsMouse ? Math.round(-5 * window.sf) : 0
                                Behavior on hoverShift { NumberAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                transform: Translate { x: prevArrowIcon.hoverShift }
                            }
                        }
                        
                        Text {
                            Layout.fillWidth: true 
                            horizontalAlignment: Text.AlignHCenter 
                            text: window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].day_full.toUpperCase() : "LOADING..."
                            font.family: "JetBrains Mono"
                            font.weight: Font.Black
                            font.pixelSize: Math.round(16 * window.sf)
                            fontSizeMode: Text.Fit
                            minimumPixelSize: Math.round(8 * window.sf)
                            color: window.text
                        }
                        
                        MouseArea { 
                            id: wNextMa; Layout.preferredWidth: Math.round(30 * window.sf); Layout.preferredHeight: Math.round(30 * window.sf); hoverEnabled: true
                            onClicked: window.setWeatherView(window.targetWeatherView + 1)
                            
                            Text { 
                                id: nextArrowIcon
                                anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: Math.round(18 * window.sf)
                                color: wNextMa.containsMouse ? window.textAccent : window.overlay1
                                property real hoverShift: wNextMa.containsMouse ? Math.round(5 * window.sf) : 0
                                Behavior on hoverShift { NumberAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                transform: Translate { x: nextArrowIcon.hoverShift }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignRight 
                        spacing: Math.round(-5 * window.sf)
                        
                        Text {
                            Layout.alignment: Qt.AlignRight 
                            text: Math.round(window.displayedTemp) + "°"
                            font.family: "JetBrains Mono"
                            font.weight: Font.Black
                            font.pixelSize: Math.round(84 * window.sf)
                            color: window.tempGlowColor
                            style: Text.Outline; 
                            styleColor: window.isTempAnimating ? Qt.alpha(window.tempGlowColor, 0.5) : Qt.alpha(window.crust, 0.4)
                            
                            Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                            Behavior on styleColor { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                        }
                        
                        Text {
                            Layout.alignment: Qt.AlignRight
                            Layout.maximumWidth: Math.round(320 * window.sf)
                            horizontalAlignment: Text.AlignRight
                            text: window.weatherData && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView].desc : ""
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: Math.round(16 * window.sf)
                            wrapMode: Text.WordWrap
                            color: window.textAccent
                            Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                            
                            opacity: window.weatherContentOpacity
                        }
                    }

                    Item { Layout.fillHeight: true } 

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter 
                        spacing: Math.round(8 * window.sf)

                        Repeater {
                            model: 4

                            Item {
                                id: gaugeWrapper
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.round(100 * window.sf) 
                                
                                scale: gaugeMa.containsMouse ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }

                                property var forecast: window.weatherData && window.weatherData.forecast[window.targetWeatherView] ? window.weatherData.forecast[window.targetWeatherView] : null

                                property string gaugeIcon: index === 0 ? "" : index === 1 ? "" : index === 2 ? "" : ""
                                property string gaugeLbl: index === 0 ? "WIND" : index === 1 ? "HUMID" : index === 2 ? "RAIN" : "FEELS"

                                property string gaugeVal: forecast ? (
                                    index === 0 ? forecast.wind + "m/s" :
                                    index === 1 ? forecast.humidity + "%" :
                                    index === 2 ? forecast.pop + "%" :
                                    forecast.feels_like + "°"
                                ) : ""

                                property real gaugeFill: forecast ? (
                                    index === 0 ? Math.min(1.0, forecast.wind / 25.0) :
                                    index === 1 ? forecast.humidity / 100.0 :
                                    index === 2 ? forecast.pop / 100.0 :
                                    Math.max(0.0, Math.min(1.0, (forecast.feels_like + 15) / 55.0))
                                ) : 0.0
                                
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: Math.round(6 * window.sf)
                                    
                                    Item {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: Math.round(60 * window.sf)
                                        Layout.preferredHeight: Math.round(60 * window.sf)
                                        
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: width / 2
                                            color: window.textAccent
                                            opacity: gaugeMa.containsMouse ? 0.3 : 0.0
                                            Behavior on opacity { NumberAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                        }

                                        Canvas {
                                            id: gaugeCanvas
                                            anchors.fill: parent
                                            rotation: -90 
                                            
                                            property real animProgress: gaugeWrapper.gaugeFill
                                            
                                            Behavior on animProgress {
                                                NumberAnimation { duration: Motion.moveMs; easing.type: Motion.moveEasing }
                                            }
                                            
                                            onAnimProgressChanged: requestPaint()
                                            onWidthChanged: requestPaint()
                                            Component.onCompleted: requestPaint()
                                            
                                            onPaint: {
                                                var ctx = getContext("2d");
                                                ctx.clearRect(0, 0, width, height);
                                                var r = width / 2;
                                                
                                                ctx.beginPath();
                                                ctx.arc(r, r, r - Math.round(4 * window.sf), 0, 2 * Math.PI);
                                                ctx.strokeStyle = Qt.alpha(window.text, 0.1);
                                                ctx.lineWidth = Math.round(3 * window.sf);
                                                ctx.stroke();
                                                
                                                if (animProgress > 0) {
                                                    ctx.beginPath();
                                                    ctx.arc(r, r, r - Math.round(4 * window.sf), 0, animProgress * 2 * Math.PI);
                                                    var grad = ctx.createLinearGradient(0, 0, width, height);
                                                    grad.addColorStop(0, window.timeAccent);
                                                    grad.addColorStop(1, window.sapphire);
                                                    ctx.strokeStyle = grad;
                                                    ctx.lineWidth = Math.round(4 * window.sf);
                                                    ctx.lineCap = "round";
                                                    ctx.stroke();
                                                }
                                            }
                                        }
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: gaugeWrapper.gaugeVal
                                            font.family: "JetBrains Mono"
                                            font.weight: Font.Black
                                            font.pixelSize: Math.round(12 * window.sf) 
                                            color: window.text
                                        }
                                    }
                                    
                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.fillWidth: true
                                        spacing: Math.round(4 * window.sf)
                                        
                                        Text { 
                                            text: gaugeWrapper.gaugeIcon
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: Math.round(12 * window.sf)
                                            color: gaugeMa.containsMouse ? window.textAccent : window.overlay0
                                            Behavior on color { ColorAnimation { duration: Motion.fadeMs; easing.type: Motion.fadeEasing } }
                                        }
                                        Text { 
                                            text: gaugeWrapper.gaugeLbl
                                            Layout.fillWidth: true
                                            font.family: "JetBrains Mono"
                                            font.weight: Font.Bold
                                            font.pixelSize: Math.round(11 * window.sf)
                                            fontSizeMode: Text.Fit
                                            minimumPixelSize: Math.round(6 * window.sf)
                                            color: window.overlay0 
                                        }
                                    }
                                }
                                
                                MouseArea { id: gaugeMa; anchors.fill: parent; hoverEnabled: true }
                            }
                        }
                    }
                }
            }
        }
    }
}