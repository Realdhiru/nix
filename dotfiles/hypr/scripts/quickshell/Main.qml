import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "WindowRegistry.js" as Registry

PanelWindow {
    id: masterWindow
    color: "transparent"

    Theme { id: themeInstance }

    Process {
        id: startupStateRestorer
        command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/restore_state.sh"]
        running: true
    }

    Keys.onEscapePressed: (event) => {
        switchWidget("hidden", "");
        event.accepted = true;
    }

    IpcHandler {
        target: "main"

        function reloadTheme(): void {
            if (themeInstance) themeInstance.reload();
        }

        function forceReload(): void {
            Quickshell.reload(true)
        }

        function handleCommand(cmd: string, targetWidget: string, arg: string): void {
            cmd = cmd || "";
            targetWidget = targetWidget || "";
            arg = arg || "";

            let isClosing = (masterWindow.currentActive !== "hidden" && !masterWindow.isWindowActive);
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

    visible: isVisible

    mask: Region { item: topBarHole; intersection: Intersection.Xor }

    Item {
        id: topBarHole
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 48

        anchors.leftMargin: (masterWindow.currentActive !== "hidden" && masterWindow.animX < 10 && masterWindow.animY < height) ? masterWindow.animW : 0
        anchors.rightMargin: (masterWindow.currentActive !== "hidden" && (masterWindow.animX + masterWindow.animW) > (parent.width - 10) && masterWindow.animY < height) ? masterWindow.animW : 0

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
        enabled: masterWindow.isWindowActive
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
            "visible": false
        });
        if (obj) {
            if (obj.notifModel !== undefined) obj.notifModel = masterWindow.notifModel;
            if (obj.liveNotifs !== undefined) obj.liveNotifs = masterWindow.liveNotifs;
            widgetCache[name] = obj;
        }
    }

    Component.onCompleted: {
        Config.masterWidth = masterWindow.width;
        Config.masterHeight = masterWindow.height;
        masterWindow.applySettings(settingsFileView.text());
    }

    property var _preloadQueue: ["sunset", "battery", "network", "music", "clipboard", "monitors", "focustime", "weather_setup", "calendar", "wallpaper"]
    property int _preloadIndex: 0

    // Defer preloading until 1.5 seconds after boot so desktop compositor finishes frame-0
    Timer {
        id: preloadIdleTimer
        interval: 1500
        running: true
        onTriggered: preloadStaggerTimer.start()
    }

    Timer {
        id: preloadStaggerTimer
        interval: 120
        repeat: true
        running: false
        onTriggered: {
            if (_preloadIndex < _preloadQueue.length) {
                preloadWidget(_preloadQueue[_preloadIndex]);
                _preloadIndex++;
            } else {
                preloadStaggerTimer.stop();
            }
        }
    }

    property string currentActive: "hidden"

    // NOTE: the old `echo > runDir/current_widget` hook is gone — its only
    // reader (TopBar's widgetPoller) was dead code, so this was a bash spawn
    // on every widget switch feeding nothing.

    property bool isVisible: false
    property bool isWindowActive: false
    property string activeArg: ""
    property bool disableMorph: false

    property int morphDuration: 110
    property int morphDurationShift: 110
    property int exitDuration: 90

    property real animW: 1
    property real animH: 1
    property real animX: 0
    property real animY: 0

    property real targetW: 1
    property real targetH: 1

    property real globalUiScale: 1.0

    // Notification state/model now lives in the NotifTicker singleton, so
    // TopBar.qml's center clock box can read it directly too -- this window
    // just forwards it to widgets that need it (battery history, etc).
    property var notifModel: NotifTicker.notifModel
    property var liveNotifs: NotifTicker.liveNotifs

    property bool isStartup: true
    Timer {
        id: startupTimer
        interval: 500
        running: true
        onTriggered: masterWindow.isStartup = false
    }

    FileView {
        id: settingsFileView
        path: Quickshell.env("HOME") + "/.config/hypr/settings.json"
        watchChanges: true
        onTextChanged: masterWindow.applySettings(text())
        onFileChanged: masterWindow.applySettings(text())
    }

    function applySettings(txt) {
        if (!txt || txt.trim().length === 0) return;
        try {
            let parsed = JSON.parse(txt);
            if (parsed.uiScale !== undefined && masterWindow.globalUiScale !== parsed.uiScale) {
                masterWindow.globalUiScale = parsed.uiScale;
            }
        } catch (e) {
            console.log("Error parsing settings.json in Main.qml:", e);
        }
    }


    property var    _layoutCache:    ({})
    property string _layoutCacheKey: ""

    FileView {
        id: monitorsFileView
        path: Quickshell.env("HOME") + "/.cache/quickshell/monitors.json"
        watchChanges: true
    }

    property int monitorPhysWidth: {
        try {
            let t = monitorsFileView.text();
            if (t && t.length > 0) {
                let m = JSON.parse(t);
                if (Array.isArray(m) && m.length > 0 && m[0].width) return m[0].width;
            }
        } catch(e) {}
        return 2880;
    }

    property int monitorPhysHeight: {
        try {
            let t = monitorsFileView.text();
            if (t && t.length > 0) {
                let m = JSON.parse(t);
                if (Array.isArray(m) && m.length > 0 && m[0].height) return m[0].height;
            }
        } catch(e) {}
        return 1620;
    }

    property real monitorScale: {
        try {
            let t = monitorsFileView.text();
            if (t && t.length > 0) {
                let m = JSON.parse(t);
                if (Array.isArray(m) && m.length > 0 && m[0].scale) return m[0].scale;
            }
        } catch(e) {}
        return 2.0;
    }

    function getLayout(name) {
        let logicalW = Math.round(masterWindow.monitorPhysWidth / (masterWindow.monitorScale > 0 ? masterWindow.monitorScale : 1.0));
        let logicalH = Math.round(masterWindow.monitorPhysHeight / (masterWindow.monitorScale > 0 ? masterWindow.monitorScale : 1.0));
        let mw = masterWindow.width > 0 ? masterWindow.width : logicalW;
        let mh = masterWindow.height > 0 ? masterWindow.height : logicalH;

        let key = name + "|" + mw + "|" + mh + "|" + masterWindow.globalUiScale;
        if (_layoutCacheKey === key) return _layoutCache[key];
        let result = Registry.getLayout(name, 0, 0, mw, mh, masterWindow.globalUiScale);

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
        function onWidthChanged()  { _layoutCacheKey = ""; Config.masterWidth = masterWindow.width; handleNativeScreenChange(); }
        function onHeightChanged() { _layoutCacheKey = ""; Config.masterHeight = masterWindow.height; handleNativeScreenChange(); }
    }

    function handleNativeScreenChange() {
        if (masterWindow.currentActive === "hidden") return;

        let t = getLayout(masterWindow.currentActive);
        if (!t) return;

        masterWindow.disableMorph = true;
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

        if (currentItem) {
            if (currentItem.layoutWidth !== undefined) currentItem.layoutWidth = t.w;
            if (currentItem.layoutHeight !== undefined) currentItem.layoutHeight = t.h;
        }
        morphReenableTimer.restart();
    }

    onGlobalUiScaleChanged: { handleNativeScreenChange(); }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: {
            if (masterWindow.isVisible && widgetStack.currentItem) {
                widgetStack.forceActiveFocus();
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
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: masterWindow.isWindowActive ? Easing.OutCubic : Easing.InCubic }
        }

        scale: masterWindow.isWindowActive ? 1.0 : 0.96
        transformOrigin: Item.Center

        Behavior on scale {
            enabled: !masterWindow.disableMorph
            NumberAnimation {
                duration: 100
                easing.type: masterWindow.isWindowActive ? Easing.OutCubic : Easing.InCubic
            }
        }

        opacity: masterWindow.isWindowActive ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation {
                duration: 100
                easing.type: masterWindow.isWindowActive ? Easing.OutCubic : Easing.InCubic
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

    function switchWidget(newWidget, arg) {
        console.log("switchWidget:", newWidget)
        delayedClear.stop();

        if (newWidget === "hidden") {
            if (currentActive !== "hidden") {
                masterWindow.morphDuration = 130;
                masterWindow.disableMorph = false;
                masterWindow.isWindowActive = false;

                delayedClear.restart();
            }
        } else {
            delayedClear.stop();
            if (currentActive === "hidden" || !masterWindow.isWindowActive) {
                morphReenableTimer.stop();
                masterWindow.morphDuration = 140;
                masterWindow.disableMorph = true;

                let t = getLayout(newWidget);
                console.log("[COLD_OPEN_DEBUG] switchWidget frame-0:", newWidget, "phys:", masterWindow.monitorPhysWidth + "x" + masterWindow.monitorPhysHeight, "scale:", masterWindow.monitorScale, "mw:", masterWindow.width, "mh:", masterWindow.height, "t.rx:", t ? t.rx : 0, "t.ry:", t ? t.ry : 0, "t.w:", t ? t.w : 0, "t.h:", t ? t.h : 0);
                let cachedWidget = widgetCache[newWidget];
                let initW = (cachedWidget && cachedWidget.targetMasterWidth !== undefined) ? cachedWidget.targetMasterWidth : t.w;
                let initH = (cachedWidget && cachedWidget.targetMasterHeight !== undefined) ? cachedWidget.targetMasterHeight : t.h;
                let initX = t.rx;
                if (cachedWidget && cachedWidget.targetMasterWidth !== undefined && initW !== t.w) {
                    let cfg = Registry.WIDGETS[newWidget];
                    if (cfg && (cfg.anchor === "top-center" || cfg.anchor === "center" || cfg.anchor === "bottom-center")) {
                        initX = Math.floor((masterWindow.width / 2) - (initW / 2));
                    } else if (cfg && cfg.anchor === "top-right") {
                        let scale = Registry.getScale(masterWindow.width, masterWindow.height, masterWindow.globalUiScale);
                        initX = masterWindow.width - initW - Registry.s(cfg.mr, scale);
                    }
                }

                masterWindow.animX = initX;
                masterWindow.animY = t.ry;
                masterWindow.animW = initW;
                masterWindow.animH = initH;
                masterWindow.targetW = initW;
                masterWindow.targetH = initH;

                masterWindow._pendingWidget = newWidget;
                masterWindow._pendingArg = arg;

                if (!widgetCache[newWidget] && t && t.comp) {
                    let obj = t.comp.createObject(masterWindow, { "visible": false });
                    if (obj) {
                        if (obj.notifModel !== undefined) obj.notifModel = masterWindow.notifModel;
                        if (obj.liveNotifs !== undefined) obj.liveNotifs = masterWindow.liveNotifs;
                        widgetCache[newWidget] = obj;
                    }
                }

                teleportTimer.restart();
            } else {
                morphReenableTimer.stop();
                let isFull = (newWidget === "wallpaper");
                masterWindow.morphDuration = masterWindow.morphDurationShift;
                masterWindow.disableMorph = isFull;
                executeSwitch(newWidget, arg, isFull);
            }
        }
    }

    function executeSwitch(newWidget, arg, immediate) {
        let t = getLayout(newWidget);
        console.log("[COLD_OPEN_DEBUG] executeSwitch settled:", newWidget, "mw:", masterWindow.width, "mh:", masterWindow.height, "t.rx:", t ? t.rx : 0, "t.ry:", t ? t.ry : 0, "t.w:", t ? t.w : 0, "t.h:", t ? t.h : 0);
        masterWindow.currentActive = newWidget;
        masterWindow.activeArg = arg;
        if (!t || !t.comp) return;

        let props = {};
        if (newWidget === "wallpaper") props["widgetArg"] = arg;

        let targetObj = widgetCache[newWidget];
        if (!targetObj) {
            let obj = t.comp.createObject(masterWindow, props);
            if (obj) {
                if (obj.notifModel   !== undefined) obj.notifModel   = masterWindow.notifModel;
                if (obj.liveNotifs   !== undefined) obj.liveNotifs   = masterWindow.liveNotifs;
                if (obj.layoutWidth  !== undefined) obj.layoutWidth  = t.w;
                if (obj.layoutHeight !== undefined) obj.layoutHeight = t.h;
                widgetCache[newWidget] = obj;
                targetObj = obj;
            } else {
                console.log("Failed to create widget instance for:", newWidget);
            }
        }

        let finalW = (targetObj && targetObj.targetMasterWidth  !== undefined) ? targetObj.targetMasterWidth  : t.w;
        let finalH = (targetObj && targetObj.targetMasterHeight !== undefined) ? targetObj.targetMasterHeight : t.h;
        let finalX = t.rx;
        if (targetObj && targetObj.targetMasterWidth !== undefined && finalW !== t.w) {
            let cfg = Registry.WIDGETS[newWidget];
            if (cfg && (cfg.anchor === "top-center" || cfg.anchor === "center" || cfg.anchor === "bottom-center")) {
                finalX = Math.floor((masterWindow.width / 2) - (finalW / 2));
            } else if (cfg && cfg.anchor === "top-right") {
                let scale = Registry.getScale(masterWindow.width, masterWindow.height, masterWindow.globalUiScale);
                finalX = masterWindow.width - finalW - Registry.s(cfg.mr, scale);
            }
        }

        masterWindow.animX = finalX;
        masterWindow.animY = t.ry;
        masterWindow.animW = finalW;
        masterWindow.animH = finalH;
        masterWindow.targetW = finalW;
        masterWindow.targetH = finalH;

        masterWindow.isVisible = true;
        masterWindow.isWindowActive = true;

        if (targetObj) {
            if (targetObj.notifModel   !== undefined) targetObj.notifModel   = masterWindow.notifModel;
            if (targetObj.liveNotifs   !== undefined) targetObj.liveNotifs   = masterWindow.liveNotifs;
            if (targetObj.layoutWidth  !== undefined) targetObj.layoutWidth  = t.w;
            if (targetObj.layoutHeight !== undefined) targetObj.layoutHeight = t.h;
            if (newWidget === "wallpaper" && targetObj.widgetArg !== undefined) targetObj.widgetArg = arg;
            if (arg !== "" && targetObj.activeMode !== undefined) targetObj.activeMode = arg;

            targetObj.visible = true;
            if (immediate) {
                widgetStack.replace(targetObj, {}, StackView.Immediate);
            } else {
                widgetStack.replace(targetObj, {});
            }
            if (targetObj.showWidget) targetObj.showWidget();
        } else {
            if (immediate) {
                widgetStack.replace(t.comp, props, StackView.Immediate);
            } else {
                widgetStack.replace(t.comp, props);
            }
        }

        focusTimer.restart();
    }

    Item {
        id: blankContainer
        visible: false
    }

    Timer {
        id: delayedClear
        interval: 100

        onTriggered: {
            if (!masterWindow.isWindowActive && !widgetStack.busy) {
                masterWindow.isVisible = false;
                masterWindow.currentActive = "hidden";
                widgetStack.replace(blankContainer, {}, StackView.Immediate);
                masterWindow.disableMorph = false;
            }
        }
    }

    Timer {
        id: morphReenableTimer
        interval: 120
        repeat: false
        onTriggered: {
            if (masterWindow.currentActive !== "wallpaper") {
                masterWindow.disableMorph = false;
            }
        }
    }

    property string _pendingWidget: ""
    property string _pendingArg: ""
    Timer {
        id: teleportTimer
        interval: 0
        onTriggered: {
            executeSwitch(masterWindow._pendingWidget, masterWindow._pendingArg, true);
            morphReenableTimer.restart();
        }
    }
}
