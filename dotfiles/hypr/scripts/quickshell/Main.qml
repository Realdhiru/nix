import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "WindowRegistry.js" as Registry

PanelWindow {
    id: masterWindow
    color: "transparent"


    Keys.onEscapePressed: (event) => {
        switchWidget("hidden", "");
        event.accepted = true;
    }

    IpcHandler {
        target: "main"

        function forceReload(): void {
            Quickshell.reload(true)
        }

        function handleCommand(cmd: string, targetWidget: string, arg: string): void {
            cmd = cmd || "";
            targetWidget = targetWidget || "";
            arg = arg || "";

            let isClosing = (masterWindow.currentActive !== "hidden" && !masterWindow.isVisible);
            let effectivelyActive = isClosing ? "hidden" : masterWindow.currentActive;
            console.log("IPC", cmd, targetWidget, effectivelyActive);

            if (cmd === "close") {
                switchWidget("hidden", "");
            } else if (cmd === "toggle" || cmd === "open") {
                delayedClear.stop();

                if (targetWidget === effectivelyActive) {
                    let currentItem = widgetStack.currentItem;

                    if (arg !== "" && currentItem && currentItem.activeMode !== undefined && currentItem.activeMode !== arg) {
                        currentItem.activeMode = arg;
                    } else if (cmd === "toggle") {
                        switchWidget("hidden", "");
                    }
                } else if (getLayout(targetWidget)) {
                    switchWidget(targetWidget, arg);
                }
            } else if (getLayout(cmd)) {
                let legacyArg = targetWidget;
                delayedClear.stop();

                if (cmd === effectivelyActive) {
                    let currentItem = widgetStack.currentItem;
                    if (legacyArg !== "" && currentItem && currentItem.activeMode !== undefined && currentItem.activeMode !== legacyArg) {
                        currentItem.activeMode = legacyArg;
                    } else {
                        switchWidget("hidden", "");
                    }
                } else {
                    switchWidget(cmd, legacyArg);
                }
            }
        }
    }

    WlrLayershell.namespace: "qs-master"
    WlrLayershell.layer: WlrLayer.Overlay

    exclusionMode: ExclusionMode.Ignore
    focusable: true

    implicitWidth: masterWindow.screen.width
    implicitHeight: masterWindow.screen.height

    // Previously gated on isVisible alone (true only while a widget popup
    // is open), which meant this whole window -- and therefore anything
    // rendered in it -- vanished the instant no widget was open. The
    // topbar ticker below needs to render (and receive clicks) whether or
    // not a widget is open, so the window itself now also stays mapped
    // whenever the ticker has something to show.
    visible: isVisible || tickerVisible

    // Scaler used only for the ticker, so its geometry matches TopBar.qml's
    // real bar height/margins exactly (barHeight = s(48), top margin =
    // s(2), right margin = s(4)) and it reads as part of the same strip.
    Scaler {
        id: tickerScaler
        currentWidth: masterWindow.screen.width
    }
    function ts(val) { return tickerScaler.s(val); }

    mask: Region { item: topBarHole; intersection: Intersection.Xor }

    Item {
        id: topBarHole
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 48

        anchors.leftMargin: (masterWindow.currentActive !== "hidden" && masterWindow.animX < 10 && masterWindow.animY < height) ? masterWindow.animW : 0

        // Extended (additively, via Math.max so the existing widget-corner
        // behavior is completely unchanged) to also exclude the ticker's
        // own corner from click-passthrough while it's showing. Without
        // this, clicks on the ticker (e.g. a pairing-confirmation button)
        // would pass straight through to whatever's behind the topbar at
        // that spot instead of reaching the ticker itself.
        anchors.rightMargin: Math.max(
            (masterWindow.currentActive !== "hidden" && (masterWindow.animX + masterWindow.animW) > (parent.width - 10) && masterWindow.animY < height) ? masterWindow.animW : 0,
            masterWindow.tickerVisible ? masterWindow.tickerPillWidth : 0
        )

        Behavior on anchors.leftMargin {
            enabled: masterWindow.currentActive !== "hidden"
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on anchors.rightMargin {
            enabled: masterWindow.currentActive !== "hidden"
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: masterWindow.isVisible
        onClicked: switchWidget("hidden", "")
    }

    property var widgetCache: ({})

    property var componentCache: ({})

    function resolveComponent(path) {
        if (!path) return null;
        if (componentCache[path]) return componentCache[path];

        let comp = Qt.createComponent(path);

        if (comp.status === Component.Ready) {
            componentCache[path] = comp;
            return comp;
        } else if (comp.status === Component.Error) {
            console.log("QML Component compilation error for path:", path, comp.errorString());
            return null;
        } else {
            comp.statusChanged.connect(function() {
                if (comp.status === Component.Ready) {
                    componentCache[path] = comp;
                    masterWindow._layoutCacheKey = "";
                } else if (comp.status === Component.Error) {
                    console.log("QML Component compilation error for path:", path, comp.errorString());
                }
            });
            return null;
        }
    }

    function preloadWidget(name) {
        if (widgetCache[name]) return;
        let t = getLayout(name);
        if (!t || !t.comp) return;

        let obj = t.comp.createObject(masterWindow, {
            "notifModel": masterWindow.notifModel,
            "liveNotifs": masterWindow.liveNotifs,
            "visible": false
        });
        if (obj) widgetCache[name] = obj;
    }

    Component.onCompleted: {
        preloadStaggerTimer.start();
    }

    Timer {
        id: preloadStaggerTimer
        interval: 900
        repeat: false
        onTriggered: {
            preloadWidget("battery");
            preloadWidget("network");
            preloadWidget("volume");
            preloadWidget("music");
            preloadWidget("clipboard");
            preloadWidget("monitors");
            preloadWidget("focustime");
            preloadWidget("calendar");
            preloadWidget("wallpaper");
        }
    }

    property string currentActive: "hidden"

    onCurrentActiveChanged: {
        Quickshell.execDetached(["bash", "-c", "echo '" + currentActive + "' > " + Caching.runDir + "/current_widget"]);
    }

    property bool isVisible: false
    property string activeArg: ""
    property bool disableMorph: false

    property int morphDuration: 160
    property int morphDurationShift: 210
    property int exitDuration: 160

    property real animW: 1
    property real animH: 1
    property real animX: 0
    property real animY: 0

    property real targetW: 1
    property real targetH: 1

    property real globalUiScale: 1.0

    ListModel { id: globalNotificationHistory }

    property var liveNotifs: ({})
    property int _popupCounter: 0

    property bool isStartup: true
    Timer {
        id: startupTimer
        interval: 500
        running: true
        onTriggered: masterWindow.isStartup = false
    }

    // =========================================================================
    // TOPBAR TICKER (single-slot, in-window notification display)
    //
    // Lives inside this window instead of a separate PanelWindow, because
    // two separate WlrLayer.Overlay surfaces race for stacking order with
    // no guaranteed winner -- which is exactly why the old NotificationPopups
    // window sometimes rendered *behind* an open widget and was unclickable.
    // Same window as the widgets = deterministic z-order via plain QML
    // z-ordering, not a compositor coin flip.
    // =========================================================================

    property var tickerNotif: null
    readonly property bool tickerVisible: tickerNotif !== null
    property int tickerPillWidth: 0
    property bool tickerIsSticky: false

    function _notifKey(appName, summary) { return appName + "\u0000" + summary; }

    function _dismissTicker(uid) {
        if (masterWindow.tickerNotif && masterWindow.tickerNotif.uid === uid) {
            masterWindow.tickerNotif = null;
        }
    }

    Timer {
        id: tickerTimeoutTimer
        onTriggered: {
            if (masterWindow.tickerNotif) masterWindow.tickerNotif = null;
        }
    }

    function _showTicker(notifData, timeoutMs) {
        masterWindow.tickerNotif = notifData;
        masterWindow.tickerIsSticky = (timeoutMs === 0);
        tickerTimeoutTimer.stop();
        if (timeoutMs > 0) {
            tickerTimeoutTimer.interval = timeoutMs;
            tickerTimeoutTimer.start();
        }
    }

    function removePopup(uid) {
        masterWindow._dismissTicker(uid);
    }

    NotificationServer {
        id: globalNotificationServer
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: (n) => {
            n.tracked = true;

            let extractedActions = [];
            if (n.actions) {
                for (let i = 0; i < n.actions.length; i++) {
                    extractedActions.push({
                        "id": n.actions[i].identifier || "",
                        "text": n.actions[i].text || n.actions[i].name || "Action"
                    });
                }
            }

            let notifAppName = n.appName !== "" ? n.appName : "System";
            let notifSummary  = n.summary !== "" ? n.summary : "No Title";
            let key = masterWindow._notifKey(notifAppName, notifSummary);

            let isTransientOsd = (notifAppName === "System" &&
                (notifSummary === "Volume" || notifSummary === "Brightness" || notifSummary === "Microphone"));

            // Persistent history (read by BatteryPopup's Notifications
            // panel) never gets OSD noise, and dedups repeats of anything
            // else the same way it always did.
            if (!isTransientOsd) {
                let existingHistIdx = -1;
                for (let i = 0; i < globalNotificationHistory.count; i++) {
                    let e = globalNotificationHistory.get(i);
                    if (e.appName === notifAppName && e.summary === notifSummary) {
                        existingHistIdx = i;
                        break;
                    }
                }
                if (existingHistIdx !== -1) {
                    globalNotificationHistory.remove(existingHistIdx);
                }
            }

            let currentUid;
            let isSameAsShowing = masterWindow.tickerNotif && masterWindow._notifKey(masterWindow.tickerNotif.appName, masterWindow.tickerNotif.summary) === key;

            if (isSameAsShowing) {
                // Same "type" (e.g. repeated Volume presses) already
                // showing -- update the value in place, don't replay the
                // reveal animation or touch liveNotifs' uid bookkeeping.
                currentUid = masterWindow.tickerNotif.uid;
            } else {
                masterWindow._popupCounter++;
                currentUid = masterWindow._popupCounter;
            }

            masterWindow.liveNotifs[currentUid] = n;

            let notifData = {
                "appName":     notifAppName,
                "summary":     notifSummary,
                "body":        n.body     !== "" ? n.body     : "",
                "iconPath":    n.appIcon  !== "" ? n.appIcon  : "",
                "actionsJson": JSON.stringify(extractedActions),
                "uid":         currentUid,
                "notif":       n
            };

            if (!isTransientOsd) {
                globalNotificationHistory.insert(0, notifData);
            }

            if (!masterWindow.isStartup) {
                let hasActions = extractedActions.length > 0;
                let timeoutMs;
                if (n.timeout === 0 || hasActions) timeoutMs = 0;
                else if (n.timeout > 0) timeoutMs = n.timeout;
                else timeoutMs = 3500;

                // A sticky notification (has actions, e.g. a pairing
                // confirmation) waiting on you to respond must not get
                // silently bumped by an unrelated routine notification
                // (e.g. a disconnect blip) -- only let it through if this
                // new one is itself sticky, or it's the same one updating.
                let incomingIsSticky = (timeoutMs === 0);
                if (masterWindow.tickerIsSticky && !isSameAsShowing && !incomingIsSticky) {
                    // dropped from the ticker, but it's still in history above
                } else {
                    masterWindow._showTicker(notifData, timeoutMs);
                }
            }
        }
    }

    property var notifModel: globalNotificationHistory

    onGlobalUiScaleChanged: { handleNativeScreenChange(); }

    Process {
        id: settingsReader
        command: ["bash", "-c", "cat ~/.config/hypr/settings.json 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0 && this.text.trim() !== "{}") {
                        let parsed = JSON.parse(this.text);
                        if (parsed.uiScale !== undefined && masterWindow.globalUiScale !== parsed.uiScale) {
                            masterWindow.globalUiScale = parsed.uiScale;
                        }
                    }
                } catch (e) {
                    console.log("Error parsing settings.json in main.qml:", e);
                }
            }
        }
    }

    Timer {
        id: settingsPollTimer
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            settingsReader.running = false;
            settingsReader.running = true;
        }
    }

    property var    _layoutCache:    ({})
    property string _layoutCacheKey: ""

    function getLayout(name) {
        let key = name + "|" + masterWindow.width + "|" + masterWindow.height + "|" + masterWindow.globalUiScale;
        if (_layoutCacheKey === key) return _layoutCache[key];
        let result = Registry.getLayout(name, 0, 0, masterWindow.width, masterWindow.height, masterWindow.globalUiScale);

        if (result && result.comp && typeof result.comp === "string") {
            result.comp = resolveComponent(result.comp);
        }

        _layoutCache = {};
        _layoutCache[key] = result;
        _layoutCacheKey = key;
        return result;
    }

    Connections {
        target: masterWindow
        function onWidthChanged()  { _layoutCacheKey = ""; handleNativeScreenChange(); }
        function onHeightChanged() { _layoutCacheKey = ""; handleNativeScreenChange(); }
    }

    function handleNativeScreenChange() {
        if (masterWindow.currentActive === "hidden") return;

        let t = getLayout(masterWindow.currentActive);
        if (!t) return;

        let currentItem = widgetStack.currentItem;
        let finalW = (currentItem && currentItem.targetMasterWidth  !== undefined) ? currentItem.targetMasterWidth  : t.w;
        let finalH = (currentItem && currentItem.targetMasterHeight !== undefined) ? currentItem.targetMasterHeight : t.h;
        let finalX = t.rx;
        if (currentItem && currentItem.targetMasterWidth !== undefined && finalW !== t.w) {
            finalX = Math.floor((masterWindow.width / 2) - (finalW / 2));
        }

        masterWindow.animX = finalX;
        masterWindow.animY = t.ry;
        masterWindow.animW = finalW;
        masterWindow.animH = finalH;
        masterWindow.targetW = finalW;
        masterWindow.targetH = finalH;
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: {
            if (masterWindow.isVisible && widgetStack.currentItem) {
                widgetStack.forceActiveFocus();
                widgetStack.currentItem.focus = false;
                widgetStack.currentItem.focus = true;
                widgetStack.currentItem.forceActiveFocus();
            }
        }
    }

    onIsVisibleChanged: {
        if (isVisible) focusTimer.restart();
        else focusTimer.stop();
    }

    Item {
        x: masterWindow.animX
        y: masterWindow.animY
        width:  masterWindow.animW
        height: masterWindow.animH
        clip: true

        Behavior on x {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on width {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }

        opacity: masterWindow.isVisible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: masterWindow.isVisible ? Easing.OutCubic : Easing.InCubic
            }
        }

        MouseArea { anchors.fill: parent }

        Item {
            anchors.fill: parent

            StackView {
                id: widgetStack
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: (event) => {
                    switchWidget("hidden", "");
                    event.accepted = true;
                }

                onCurrentItemChanged: {
                    if (currentItem) currentItem.forceActiveFocus();
                }

                replaceEnter: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            from: 0.0; to: 1.0
                            duration: masterWindow.morphDurationShift
                            easing.type: Easing.OutQuint
                        }
                        NumberAnimation {
                            property: "scale"
                            from: 0.98; to: 1.0
                            duration: masterWindow.morphDurationShift
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                replaceExit: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            from: 1.0; to: 0.0
                            duration: masterWindow.morphDurationShift
                            easing.type: Easing.InQuint
                        }
                        NumberAnimation {
                            property: "scale"
                            from: 1.0; to: 0.98
                            duration: masterWindow.morphDurationShift
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }

        // ---- Ticker UI -- renders on top of everything above (declared last =
    // painted last = on top, within this single window's z-stack). ----
    MatugenColors { id: _tickerTheme }

    Item {
        id: tickerRoot
        z: 1000
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: masterWindow.ts(2)
        anchors.rightMargin: masterWindow.ts(4)
        height: masterWindow.ts(48)
        clip: true

        property var n: masterWindow.tickerNotif
        property var actionArray: {
            try {
                return n && n.actionsJson ? JSON.parse(n.actionsJson) : [];
            } catch (e) { return []; }
        }
        property var sourceNotif: n ? (masterWindow.liveNotifs[n.uid] || null) : null
        property bool revealed: n !== null

        // Single source of truth for width -- computed once, directly from
        // the actual content, with one generous cap tied to screen width
        // (not a fixed px number). Previously the outer pill's width was
        // capped smaller than what the inner content actually needed,
        // while the content sized itself independently -- that mismatch is
        // what let text spill past the pill's edge / off-screen.
        width: revealed ? Math.min(masterWindow.screen.width * 0.4, pillContent.implicitWidth + masterWindow.ts(32)) : 0
        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        onWidthChanged: masterWindow.tickerPillWidth = width

        Connections {
            target: tickerRoot.sourceNotif || null
            function onClosed() {
                if (tickerRoot.n) masterWindow._dismissTicker(tickerRoot.n.uid);
            }
        }

        Rectangle {
            id: pillBg
            anchors.fill: parent
            radius: masterWindow.ts(14)
            color: Qt.rgba(_tickerTheme.base.r, _tickerTheme.base.g, _tickerTheme.base.b, 0.9)
            border.color: Qt.rgba(_tickerTheme.text.r, _tickerTheme.text.g, _tickerTheme.text.b, 0.08)
            border.width: 1
            clip: true

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    let liveN = tickerRoot.sourceNotif;
                    if (liveN && liveN.actions) {
                        for (let i = 0; i < liveN.actions.length; i++) {
                            if (liveN.actions[i].identifier === "default") {
                                liveN.actions[i].invoke();
                                break;
                            }
                        }
                    }
                    if (tickerRoot.n) masterWindow._dismissTicker(tickerRoot.n.uid);
                }
            }

            Item {
                id: contentSlider
                anchors.fill: parent
                anchors.leftMargin: masterWindow.ts(16)
                anchors.rightMargin: masterWindow.ts(16)
                clip: true

                Row {
                    id: pillContent
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: masterWindow.ts(10)

                    opacity: tickerRoot.revealed ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    // Fast slide, same direction (left-to-right, i.e.
                    // moving rightward into place) for both entrance and
                    // exit -- entrance slides rightward into position,
                    // exit continues rightward while fading rather than
                    // retreating back the way it came.
                    transform: Translate {
                        x: tickerRoot.revealed ? 0 : masterWindow.ts(36)
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }

                    // Single horizontal line: appName, summary, body all
                    // read left to right on one baseline.
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: tickerRoot.n && tickerRoot.n.iconPath !== ""
                        source: tickerRoot.n && tickerRoot.n.iconPath !== "" ? tickerRoot.n.iconPath : ""
                        width: masterWindow.ts(20); height: masterWindow.ts(20)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tickerRoot.n ? tickerRoot.n.appName : ""
                        font.family: "JetBrains Mono"
                        font.weight: Font.Medium
                        font.pixelSize: masterWindow.ts(11)
                        color: _tickerTheme.overlay1
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u2022"
                        font.pixelSize: masterWindow.ts(11)
                        color: _tickerTheme.overlay0
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tickerRoot.n ? tickerRoot.n.summary : ""
                        font.family: "JetBrains Mono"
                        font.weight: Font.Bold
                        font.pixelSize: masterWindow.ts(13)
                        color: _tickerTheme.text
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: text !== ""
                        text: tickerRoot.n ? tickerRoot.n.body : ""
                        font.family: "JetBrains Mono"
                        font.weight: Font.Medium
                        font.pixelSize: masterWindow.ts(13)
                        color: _tickerTheme.subtext0
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: masterWindow.ts(6)
                        visible: tickerRoot.actionArray.length > 0
                        leftPadding: masterWindow.ts(6)

                        Repeater {
                            model: tickerRoot.actionArray
                            delegate: Rectangle {
                                height: masterWindow.ts(26)
                                width: actionLabel.implicitWidth + masterWindow.ts(16)
                                radius: masterWindow.ts(8)
                                property bool isPrimary: index === 0
                                color: {
                                    if (!_tickerTheme.blue) return "transparent";
                                    if (isPrimary) return actionMa.containsMouse ? _tickerTheme.blue : Qt.darker(_tickerTheme.blue, 1.2);
                                    return actionMa.containsMouse ? _tickerTheme.surface2 : _tickerTheme.surface1;
                                }
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    text: modelData.text || "Action"
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Bold
                                    font.pixelSize: masterWindow.ts(11)
                                    color: isPrimary ? _tickerTheme.crust : _tickerTheme.text
                                }

                                MouseArea {
                                    id: actionMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        let liveN = tickerRoot.sourceNotif;
                                        if (liveN && liveN.actions) {
                                            for (let i = 0; i < liveN.actions.length; i++) {
                                                if (liveN.actions[i].identifier === modelData.id) {
                                                    liveN.actions[i].invoke();
                                                    break;
                                                }
                                            }
                                        }
                                        if (tickerRoot.n) masterWindow._dismissTicker(tickerRoot.n.uid);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    function switchWidget(newWidget, arg) {
        console.log("switchWidget:", newWidget)
        delayedClear.stop();

        if (newWidget === "hidden") {
            if (currentActive !== "hidden") {
                masterWindow.morphDuration = masterWindow.exitDuration;
                masterWindow.disableMorph = false;

                masterWindow.animW = 1;
                masterWindow.animH = 1;
                masterWindow.isVisible = false;

                delayedClear.start();
            }
        } else {
            if (currentActive === "hidden" || !masterWindow.isVisible) {
                masterWindow.morphDuration = 230;
                masterWindow.disableMorph = false;

                let t = getLayout(newWidget);
                masterWindow.animX = t.rx;
                masterWindow.animY = t.ry;
                masterWindow.animW = t.w;
                masterWindow.animH = t.h;
                masterWindow.targetW = t.w;
                masterWindow.targetH = t.h;
            } else {
                masterWindow.morphDuration = masterWindow.morphDurationShift;
                masterWindow.disableMorph = false;
            }

            executeSwitch(newWidget, arg, false);
        }
    }

    function executeSwitch(newWidget, arg, immediate) {
        console.log("executeSwitch:", newWidget)
        masterWindow.currentActive = newWidget;
        masterWindow.activeArg = arg;

        let t = getLayout(newWidget);
        if (!t || !t.comp) return;

        masterWindow.animX = t.rx;
        masterWindow.animY = t.ry;
        masterWindow.animW = t.w;
        masterWindow.animH = t.h;
        masterWindow.targetW = t.w;
        masterWindow.targetH = t.h;

        let props = {};
        props["notifModel"]   = masterWindow.notifModel;
        props["liveNotifs"]   = masterWindow.liveNotifs;
        props["layoutWidth"]  = t.w;
        props["layoutHeight"] = t.h;
        if (newWidget === "wallpaper") props["widgetArg"] = arg;

        let cached = widgetCache[newWidget];
        if (cached) {
            if (cached.notifModel   !== undefined) cached.notifModel   = masterWindow.notifModel;
            if (cached.liveNotifs   !== undefined) cached.liveNotifs   = masterWindow.liveNotifs;
            if (cached.layoutWidth  !== undefined) cached.layoutWidth  = t.w;
            if (cached.layoutHeight !== undefined) cached.layoutHeight = t.h;
            if (newWidget === "wallpaper" && cached.widgetArg !== undefined) cached.widgetArg = arg;
            if (arg !== "" && cached.activeMode !== undefined) cached.activeMode = arg;

            cached.visible = true;
            if (immediate) {
                widgetStack.replace(cached, {}, StackView.Immediate);
            } else {
                widgetStack.replace(cached, {});
            }
        } else {
            let obj = t.comp.createObject(masterWindow, props);
            if (obj) {
                widgetCache[newWidget] = obj;
                if (immediate) {
                    widgetStack.replace(obj, {}, StackView.Immediate);
                } else {
                    widgetStack.replace(obj, {});
                }
            } else {
                console.log("Failed to create widget instance for:", newWidget);
                if (immediate) {
                    widgetStack.replace(t.comp, props, StackView.Immediate);
                } else {
                    widgetStack.replace(t.comp, props);
                }
            }
        }

        let currentItem = widgetStack.currentItem;
        if (currentItem) {
            if (currentItem.targetMasterWidth !== undefined) {
                let dynW = currentItem.targetMasterWidth;
                masterWindow.animW = dynW;
                masterWindow.targetW = dynW;
                masterWindow.animX = Math.floor((masterWindow.width / 2) - (dynW / 2));
            }
            if (currentItem.targetMasterHeight !== undefined) {
                masterWindow.animH = currentItem.targetMasterHeight;
                masterWindow.targetH = currentItem.targetMasterHeight;
            }
        }

        masterWindow.isVisible = true;
        focusTimer.restart();
    }

    Timer {
        id: delayedClear
        interval: 200

        onTriggered: {
            if (!masterWindow.isVisible) {
                masterWindow.currentActive = "hidden";
                widgetStack.clear();
                masterWindow.disableMorph = false;
            }
        }
    }
}
