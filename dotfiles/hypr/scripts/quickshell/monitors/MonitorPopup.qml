import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window
    focus: true

    property real layoutWidth
    property real layoutHeight
    width: layoutWidth
    height: layoutHeight

    // --- Responsive Scaling Logic ---
    Scaler {
        id: scaler
        currentWidth: Screen.width
    }

    // Helper function scoped to the root Item
    function s(val) {
        return scaler.s(val);
    }

    // Custom Logger
    function debugLog(msg) {
        console.log("[MonitorPopup]", msg);
    }

    // -------------------------------------------------------------------------
    // COLORS (Dynamic Matugen Palette)
    // -------------------------------------------------------------------------
    Theme { id: _theme }
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay0: _theme.overlay0
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color primary: _theme.primary

    readonly property color mauve: _theme.mauve
    readonly property color blue: _theme.blue
    readonly property color yellow: _theme.yellow
    readonly property color peach: _theme.peach
    readonly property color green: _theme.green
    readonly property color red: _theme.red

    // -------------------------------------------------------------------------
    // STATE & MATH
    // -------------------------------------------------------------------------
    property int activeEditIndex: 0
    property int activeFocusIndex: 0 // 0: Res, 1: Orientation, 2: Frame, 3: Scale, 4: Apply
    property real uiScale: 0.10

    // Wayland Absolute Anchor tracking
    property int originalLayoutOriginX: 0
    property int originalLayoutOriginY: 0

    ListModel {
        id: monitorsModel
    }

    // Common presets, used as a floor so the picker is never degenerate. The
    // authoritative list is the union of these with the active monitor's real
    // Hyprland `availableModes`, so any mode an attached output actually
    // supports (2560x1440@180, 3440x1440 ultrawide, 5120x1440, arbitrary
    // laptop panels) is selectable without touching this table.
    property var _presetRes: [
        {w: 3840, h: 2160, l: "4K"},
        {w: 3440, h: 1440, l: "UWQHD"},
        {w: 2560, h: 1440, l: "QHD"},
        {w: 2880, h: 1620, l: "QHD+"},
        {w: 1920, h: 1080, l: "FHD"},
        {w: 1600, h: 900,  l: "HD+"},
        {w: 1366, h: 768,  l: "WXGA"},
        {w: 1280, h: 720,  l: "HD"},
        {w: 1024, h: 768,  l: "XGA"},
        {w: 800,  h: 600,  l: "SVGA"}
    ]

    // Extra distinct modes used ONLY to pad the 2-column grid to an even row
    // count. Must never duplicate an already-listed entry.
    property var _padRes: [
        {w: 2560, h: 1600, l: "WQXGA"},
        {w: 1920, h: 1200, l: "DCI"},
        {w: 1680, h: 1050, l: "WSXGA+"},
        {w: 1440, h: 900,  l: "WXGA+"},
        {w: 1280, h: 1024, l: "SXGA"},
        {w: 1152, h: 720,  l: "WGA"}
    ]

    function _resLabel(w, h) {
        for (let i = 0; i < _presetRes.length; i++) {
            if (_presetRes[i].w === w && _presetRes[i].h === h) return _presetRes[i].l;
        }
        return "";
    }

    function _activeAvailableModes() {
        if (monitorsModel.count === 0) return [];
        let m = monitorsModel.get(window.activeEditIndex);
        if (!m || !m.availableModes) return [];
        try { return JSON.parse(m.availableModes) || []; } catch(e) { return []; }
    }

    // Resolution picker: union of curated presets + the monitor's real modes,
    // deduped, sorted by pixel count descending. Padded to an even length so
    // the 2-column GridLayout and the Left/Right/Up/Down keyboard navigation
    // keep their row-pair invariant without a hardcoded entry count.
    property var resList: {
        let seen = {};
        let out = [];

        let push = function(w, h) {
            if (!w || !h || w < 200 || h < 200) return;
            let k = w + "x" + h;
            if (seen[k]) return;
            seen[k] = true;
            let lbl = _resLabel(w, h);
            out.push({ w: w, h: h, l: lbl.length > 0 ? lbl : (w + "x" + h), accent: window.primary });
        };

        // Real monitor modes first — exact strings straight from Hyprland.
        let modes = _activeAvailableModes();
        for (let i = 0; i < modes.length; i++) {
            let wh = String(modes[i]).split("@")[0].trim().split("x");
            let w = parseInt(wh[0]), h = parseInt(wh[1]);
            if (!isNaN(w) && !isNaN(h)) push(w, h);
        }

        // Current mode always reachable, even if Hyprland didn't enumerate it.
        if (monitorsModel.count > 0) {
            let m = monitorsModel.get(window.activeEditIndex);
            push(m.resW, m.resH);
        }

        for (let i = 0; i < _presetRes.length; i++) push(_presetRes[i].w, _presetRes[i].h);

        // Sort by pixel count desc, then width desc — stable, deterministic.
        out.sort(function(a, b) {
            let pa = a.w * a.h, pb = b.w * b.h;
            if (pb !== pa) return pb - pa;
            return b.w - a.w;
        });

        // Even count for the 2-column grid, padding only with modes that are
        // not already listed (duplicating an entry renders two identical tiles).
        for (let i = 0; i < _padRes.length && out.length % 2 !== 0; i++) {
            push(_padRes[i].w, _padRes[i].h);
        }
        return out;
    }

    // Bumped every time the selected resolution changes (arrow nav, grid
    // click). ListModel.setProperty role changes do NOT re-trigger bindings
    // that read via monitorsModel.get(), so rateList references this epoch
    // to recompute when resW/resH change. Monitor switches need no epoch —
    // activeEditIndex is a plain property the binding already tracks.
    property int _resEpoch: 0

    // Refresh-rate picker: ONLY the rates the active monitor advertises for
    // the CURRENTLY SELECTED resolution. A real panel exposes 1–3 rates per
    // mode (eDP-1 @2880x1620 → 60 + 120) — that short list is the entire
    // point. The old 13-entry table (24…360) offered modes no real monitor
    // has. Falls back to the current rate so the slider is never empty.
    property var rateList: {
        _resEpoch;
        let seen = {};
        let out = [];
        let push = function(r) {
            let v = Math.round(parseFloat(r));
            if (isNaN(v) || v < 20 || v > 1000) return;
            if (seen[v]) return;
            seen[v] = true;
            out.push(v);
        };
        if (monitorsModel.count > 0) {
            let cur = monitorsModel.get(window.activeEditIndex);
            let modes = _activeAvailableModes();
            for (let i = 0; i < modes.length; i++) {
                let parts = String(modes[i]).split("@");
                if (parts.length < 2) continue;
                let wh = parts[0].trim().split("x");
                if (parseInt(wh[0]) === cur.resW && parseInt(wh[1]) === cur.resH) {
                    push(parts[1].replace(/[^0-9.]/g, ""));
                }
            }
            push(cur.rate);
        } else {
            push(60);
        }
        out.sort(function(a, b) { return a - b; });
        return out;
    }

    property color selectedResAccent: window.primary
    property color selectedRateAccent: window.primary
    property color selectedScaleAccent: window.primary

    property int currentTransform: monitorsModel.count > 0 ? monitorsModel.get(window.activeEditIndex).transform : 0
    property bool currentIsPortrait: currentTransform === 1 || currentTransform === 3

    // Fallbacks below are the model-empty case only (popup opening before its
    // one-shot `hyprctl monitors -j` collector lands). Sourced from the live
    // Quickshell.screens list rather than resolution literals so an external
    // monitor at any mode/scale is already correct on frame 0.
    property var _fallbackScreen: {
        let sc = Quickshell.screens;
        return (sc && sc.length > 0) ? sc[0] : null;
    }

    property real currentSimW: {
        if (monitorsModel.count === 0) {
            // Physical pixels, same units as the model — logical screen size
            // times scale (eDP-1: 1440×2 = 2880), not logical px.
            let s = _fallbackScreen;
            if (!s || !(s.width > 0)) return 1280;
            let sc = (s.scale && s.scale > 0) ? s.scale : 1.0;
            return Math.round(s.width * sc);
        }
        let mon = monitorsModel.get(window.activeEditIndex);
        return currentIsPortrait ? mon.resH : mon.resW;
    }
    property real currentSimH: {
        if (monitorsModel.count === 0) {
            let s = _fallbackScreen;
            if (!s || !(s.height > 0)) return 800;
            let sc = (s.scale && s.scale > 0) ? s.scale : 1.0;
            return Math.round(s.height * sc);
        }
        let mon = monitorsModel.get(window.activeEditIndex);
        return currentIsPortrait ? mon.resW : mon.resH;
    }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0
        to: Math.PI * 2
        duration: 90000
        loops: Animation.Infinite
        running: window.visible
    }

    // -------------------------------------------------------------------------
    // KEYBOARD NAVIGATION LOGIC
    // -------------------------------------------------------------------------
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Tab) {
            if (event.modifiers & Qt.ControlModifier) {
                if (monitorsModel.count > 1) {
                    window.activeEditIndex = (window.activeEditIndex + 1) % monitorsModel.count;
                }
            } else {
                window.activeFocusIndex = (window.activeFocusIndex + 1) % 5;
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Backtab) {
            if (event.modifiers & Qt.ControlModifier) {
                if (monitorsModel.count > 1) {
                    window.activeEditIndex = (window.activeEditIndex - 1 + monitorsModel.count) % monitorsModel.count;
                }
            } else {
                window.activeFocusIndex = (window.activeFocusIndex - 1 + 5) % 5;
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            handleArrowKey("Left"); event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            handleArrowKey("Right"); event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            handleArrowKey("Up"); event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            handleArrowKey("Down"); event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (activeFocusIndex === 4) {
                window.applyPressed = true;
                window.triggerApply();
            }
            event.accepted = true;
        }
    }

    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            window.applyPressed = false;
        }
    }

    function scrollResIntoView(idx) {
        if (typeof resFlickable === "undefined" || !resFlickable) return;
        let row = Math.floor(idx / 2);
        let rowH = window.s(42) + window.s(8);
        let targetY = row * rowH;
        if (targetY < resFlickable.contentY) {
            resFlickable.contentY = Math.max(0, targetY);
        } else if (targetY + rowH > resFlickable.contentY + resFlickable.height) {
            resFlickable.contentY = Math.min(resFlickable.contentHeight - resFlickable.height, targetY + rowH - resFlickable.height);
        }
    }

    function handleArrowKey(dir) {
        if (monitorsModel.count === 0) return;

        if (activeFocusIndex === 0) {
            let activeMon = monitorsModel.get(window.activeEditIndex);
            let list = window.resList;
            // Bounds derived from the actual list length: the grid is 2 columns,
            // so rows are index pairs (even, odd). These used to be hardcoded to
            // an 8-entry table and silently clamped any real monitor mode.
            let lastRow = list.length - 2;
            if (lastRow < 0) lastRow = 0;
            let idx = 0;
            for (let i = 0; i < list.length; i++) {
                if (list[i].w === activeMon.resW && list[i].h === activeMon.resH) {
                    idx = i; break;
                }
            }

            if (dir === "Left" && idx % 2 !== 0) idx--;
            else if (dir === "Right" && idx % 2 === 0 && idx < lastRow) idx++;
            else if (dir === "Up" && idx >= 2) idx -= 2;
            else if (dir === "Down" && idx <= lastRow - 1) idx += 2;

            idx = Math.max(0, Math.min(list.length - 1, idx));
            window.selectedResAccent = window.resList[idx].accent;
            monitorsModel.setProperty(window.activeEditIndex, "resW", window.resList[idx].w);
            monitorsModel.setProperty(window.activeEditIndex, "resH", window.resList[idx].h);
            window._resEpoch++;
            delayedLayoutUpdate.restart();
            scrollResIntoView(idx);
        } else if (activeFocusIndex === 1) {
            let t = monitorsModel.get(window.activeEditIndex).transform;
            if (dir === "Up") t = 0;
            else if (dir === "Right") t = 1;
            else if (dir === "Down") t = 2;
            else if (dir === "Left") t = 3;
            monitorsModel.setProperty(window.activeEditIndex, "transform", t);
            delayedLayoutUpdate.restart();

        } else if (activeFocusIndex === 2) {
            let cIdx = sliderContainer.currentIndex;
            if (dir === "Left" && cIdx > 0) cIdx--;
            else if (dir === "Right" && cIdx < sliderContainer.rates.length - 1) cIdx++;
            sliderContainer.updateSelectionVisual(cIdx);
        } else if (activeFocusIndex === 3) {
            let cIdx = scaleSliderContainer.currentIndex;
            if (dir === "Left" && cIdx > 0) cIdx--;
            else if (dir === "Right" && cIdx < scaleSliderContainer.scales.length - 1) cIdx++;
            scaleSliderContainer.updateSelectionVisual(cIdx);
        }
    }

    // -------------------------------------------------------------------------
    // FLUID STARTUP ANIMATIONS
    // -------------------------------------------------------------------------
    property real introProgress: 0.0
    property real monitorScale: 0.85
    property real uiYOffset: window.s(25)
    property real screenLight: 0.0

    Component.onCompleted: startupAnim.start()

    ParallelAnimation {
        id: startupAnim
        NumberAnimation { target: window; property: "introProgress"; from: 0.0; to: 1.0; duration: 900; easing.type: Easing.OutQuint }
        NumberAnimation { target: window; property: "monitorScale"; from: 0.85; to: 1.0; duration: 1200; easing.type: Easing.OutQuint }
        NumberAnimation { target: window; property: "uiYOffset"; from: window.s(25); to: 0; duration: 1800; easing.type: Easing.OutQuint }
        NumberAnimation { target: window; property: "screenLight"; from: 0.0; to: 1.0; duration: 1500; easing.type: Easing.InOutQuad }
    }
    property bool applyHovered: false
    property bool applyPressed: false

    onActiveEditIndexChanged: {
        menuTransitionAnim.restart();
    }

    // -------------------------------------------------------------------------
    // MATHEMATICAL PERIMETER GLUE (Virtual Coordinates - Do not scale)
    // -------------------------------------------------------------------------
    function isOverlapping(ax, ay, aw, ah, bx, by, bw, bh) {
        return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
    }

    function isOverlappingAny(x, y, w, h, skipIdx) {
        for (let i = 0; i < monitorsModel.count; i++) {
            if (i === skipIdx) continue;
            let m = monitorsModel.get(i);
            let isP = m.transform === 1 || m.transform === 3;
            let mW = ((isP ? m.resH : m.resW) / m.sysScale) * window.uiScale;
            let mH = ((isP ? m.resW : m.resH) / m.sysScale) * window.uiScale;
            if (isOverlapping(x, y, w, h, m.uiX, m.uiY, mW, mH)) return true;
        }
        return false;
    }

    function getPerimeterSnap(pX, pY, sX, sY, sW, sH, mW, mH, snapT) {
        let edges = [
            { x1: sX - mW, x2: sX + sW, y1: sY - mH, y2: sY - mH }, // Top Edge
            { x1: sX - mW, x2: sX + sW, y1: sY + sH, y2: sY + sH }, // Bottom Edge
            { x1: sX - mW, x2: sX - mW, y1: sY - mH, y2: sY + sH }, // Left Edge
            { x1: sX + sW, x2: sX + sW, y1: sY - mH, y2: sY + sH }  // Right Edge
        ];

        let bestX = pX;
        let bestY = pY;
        let minDist = 999999;

        for (let i = 0; i < 4; i++) {
            let e = edges[i];

            let cx = Math.max(e.x1, Math.min(pX, e.x2));
            let cy = Math.max(e.y1, Math.min(pY, e.y2));

            if (Math.abs(cx - sX) < snapT) cx = sX;
            if (Math.abs(cx - (sX + sW - mW)) < snapT) cx = sX + sW - mW;
            if (Math.abs(cx - (sX + sW/2 - mW/2)) < snapT) cx = sX + sW/2 - mW/2;

            if (Math.abs(cy - sY) < snapT) cy = sY;
            if (Math.abs(cy - (sY + sH - mH)) < snapT) cy = sY + sH - mH;
            if (Math.abs(cy - (sY + sH/2 - mH/2)) < snapT) cy = sY + sH/2 - mH/2;

            let dist = Math.hypot(pX - cx, pY - cy);
            if (dist < minDist) {
                minDist = dist;
                bestX = cx;
                bestY = cy;
            }
        }
        return { x: bestX, y: bestY };
    }

    function forceLayoutUpdate() {
        if (monitorsModel.count < 2) return;

        let mIdx = window.activeEditIndex;
        let mModel = monitorsModel.get(mIdx);
        let isP = mModel.transform === 1 || mModel.transform === 3;
        let mW = ((isP ? mModel.resH : mModel.resW) / mModel.sysScale) * window.uiScale;
        let mH = ((isP ? mModel.resW : mModel.resH) / mModel.sysScale) * window.uiScale;

        let bestX = mModel.uiX;
        let bestY = mModel.uiY;
        let bestDist = 999999;

        for (let i = 0; i < monitorsModel.count; i++) {
            if (i === mIdx) continue;
            let sModel = monitorsModel.get(i);
            let sIsP = sModel.transform === 1 || sModel.transform === 3;
            let sW = ((sIsP ? sModel.resH : sModel.resW) / sModel.sysScale) * window.uiScale;
            let sH = ((sIsP ? sModel.resW : sModel.resH) / sModel.sysScale) * window.uiScale;

            let snapped = window.getPerimeterSnap(
                mModel.uiX, mModel.uiY,
                sModel.uiX, sModel.uiY,
                sW, sH, mW, mH, window.s(20)
            );

            let dist = Math.hypot(snapped.x - mModel.uiX, snapped.y - mModel.uiY);
            if (dist < bestDist) {
                bestDist = dist;
                bestX = snapped.x;
                bestY = snapped.y;
            }
        }

        monitorsModel.setProperty(mIdx, "uiX", bestX);
        monitorsModel.setProperty(mIdx, "uiY", bestY);
    }

    Timer {
        id: delayedLayoutUpdate
        interval: 10
        running: false
        repeat: false
        onTriggered: window.forceLayoutUpdate()
    }

    // -------------------------------------------------------------------------
    // NATIVE SYSTEM PROCESSES
    // -------------------------------------------------------------------------
    StackView.onActivated: {
        // Populate once. Re-running the poller on every activation wiped
        // the model (clear + re-append): unapplied res/rate/scale edits were
        // lost, the grid rebuilt/flashed, and recycled delegates could show
        // phantom duplicate tiles. Hotplug while open is covered by the
        // live Quickshell.screens bindings + Apply re-poll.
        if (monitorsModel.count === 0) {
            displayPoller.running = false;
            displayPoller.running = true;
        }
    }

    Process {
        id: displayPoller
        command: ["hyprctl", "monitors", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim());
                    monitorsModel.clear();

                    let minX = 999999, minY = 999999;

                    for (let i = 0; i < data.length; i++) {
                        if (data[i].x < minX) minX = data[i].x;
                        if (data[i].y < minY) minY = data[i].y;
                    }

                    window.originalLayoutOriginX = minX !== 999999 ? minX : 0;
                    window.originalLayoutOriginY = minY !== 999999 ? minY : 0;

                    let batch = [];
                    for (let i = 0; i < data.length; i++) {
                        let scl = data[i].scale !== undefined ? data[i].scale : 1.0;
                        let tf = data[i].transform !== undefined ? data[i].transform : 0;
                        let normalizedX = (data[i].x - minX) * window.uiScale;
                        let normalizedY = (data[i].y - minY) * window.uiScale;

                        batch.push({
                            name: data[i].name,
                            resW: data[i].width,
                            resH: data[i].height,
                            sysScale: scl,
                            rate: Math.round(data[i].refreshRate).toString(),
                            bitDepth: 10,
                            uiX: normalizedX,
                            uiY: normalizedY,
                            transform: tf,
                            availableModes: JSON.stringify(data[i].availableModes || [])
                        });

                        if (data[i].focused) window.activeEditIndex = i;
                    }
                    if (batch.length > 0) monitorsModel.append(batch);

                    window.forceLayoutUpdate();
                } catch(e) {}
            }
        }
    }

    // -------------------------------------------------------------------------
    // SYSTEM APPLY FUNCTION & DEBUG LOGGING
    // -------------------------------------------------------------------------
    function triggerApply() {
        flashRect.opacity = 0.8;
        applyFlashAnim.start();

        if (monitorsModel.count === 0) return;

        window.debugLog("================= NEW APPLY RUN =================");

        if (monitorsModel.count === 1) {
            let m = monitorsModel.get(0);
            let monitorStr = m.name + "," + m.resW + "x" + m.resH + "@" + m.rate + ",0x0," + m.sysScale + ",bitdepth,10";
            if (m.transform !== 0) {
                monitorStr += ",transform," + m.transform;
            }

            let jsonMonitorsArray = [{
                name: m.name, resW: m.resW, resH: m.resH, rate: parseInt(m.rate),
                x: 0, y: 0, scale: m.sysScale, transform: m.transform
            }];
            let safeJson = JSON.stringify(jsonMonitorsArray).replace(/'/g, "'\\''");
            let jsonCmd = "jq '.monitors = " + safeJson + "' ~/.config/hypr/settings.json > ~/.config/hypr/settings.json.tmp && mv ~/.config/hypr/settings.json.tmp ~/.config/hypr/settings.json";
            let postReloadCmd = "~/.config/hypr/scripts/ensure_awww.sh --restart";

            let cacheWriteCmd = "echo 'monitor=" + monitorStr + "' > ~/.cache/hypr_power_monitor.conf";

            let evalCmd = "hyprctl eval \"hl.monitor({output='" + m.name + "',mode='" + m.resW + "x" + m.resH + "@" + m.rate + "',position='0x0',scale='" + m.sysScale + "',bitdepth=10" + (m.transform !== 0 ? ",transform=" + m.transform : "") + "})\"";

            Quickshell.execDetached(["notify-send", "Display Applied"]);
            Quickshell.execDetached(["sh", "-c", cacheWriteCmd + " ; " + evalCmd + " ; " + jsonCmd + " ; " + postReloadCmd]);

            window.debugLog("Executed single monitor apply.");
        } else {
            let rects = [];
            let finalMinX = 999999;
            let finalMinY = 999999;

            for (let i = 0; i < monitorsModel.count; i++) {
                let m = monitorsModel.get(i);
                let isP = m.transform === 1 || m.transform === 3;
                let physW = Math.round((isP ? m.resH : m.resW) / m.sysScale);
                let physH = Math.round((isP ? m.resW : m.resH) / m.sysScale);

                let rawX = m.uiX / window.uiScale;
                let rawY = m.uiY / window.uiScale;

                rects.push({
                    x: rawX, y: rawY, w: physW, h: physH,
                    resW: m.resW, resH: m.resH, name: m.name,
                    rate: m.rate, sysScale: m.sysScale, transform: m.transform
                });
            }

            function getTightSnap(pX, pY, sX, sY, sW, sH, mW, mH, t) {
                let cx = pX; let cy = pY;
                if (Math.abs(cx - (sX - mW)) < t) cx = sX - mW;
                else if (Math.abs(cx - (sX + sW)) < t) cx = sX + sW;
                else if (Math.abs(cx - sX) < t) cx = sX;
                else if (Math.abs(cx - (sX + sW - mW)) < t) cx = sX + sW - mW;
                else if (Math.abs(cx - (sX + sW/2 - mW/2)) < t) cx = sX + sW/2 - mW/2;

                if (Math.abs(cy - (sY - mH)) < t) cy = sY - mH;
                else if (Math.abs(cy - (sY + sH)) < t) cy = sY + sH;
                else if (Math.abs(cy - sY) < t) cy = sY;
                else if (Math.abs(cy - (sY + sH - mH)) < t) cy = sY + sH - mH;
                else if (Math.abs(cy - (sY + sH/2 - mH/2)) < t) cy = sY + sH/2 - mH/2;

                return {x: cx, y: cy};
            }

            for (let i = 1; i < rects.length; i++) {
                let bestX = rects[i].x;
                let bestY = rects[i].y;
                let bestDist = 999999;
                for (let j = 0; j < i; j++) {
                    let r0 = rects[j];
                    let snapped = getTightSnap(
                        rects[i].x, rects[i].y,
                        r0.x, r0.y,
                        r0.w, r0.h, rects[i].w, rects[i].h, 25 // Intentionally unscaled (Physical display coordinates)
                    );
                    let dist = Math.hypot(rects[i].x - snapped.x, rects[i].y - snapped.y);
                    if (dist < bestDist) {
                        bestDist = dist;
                        bestX = Math.round(snapped.x);
                        bestY = Math.round(snapped.y);
                    }
                }
                rects[i].x = bestX;
                rects[i].y = bestY;
            }

            for (let i = 0; i < rects.length; i++) {
                if (rects[i].x < finalMinX) finalMinX = rects[i].x;
                if (rects[i].y < finalMinY) finalMinY = rects[i].y;
            }

            let batchCmds = [];
            let summaryString = "";
            let jsonMonitorsArray = [];
            let confLines = [];

            for (let i = 0; i < rects.length; i++) {
                let r = rects[i];

                r.x = Math.round(r.x - finalMinX);
                r.y = Math.round(r.y - finalMinY);

                let monitorStr = r.name + "," + r.resW + "x" + r.resH + "@" + r.rate + "," + r.x + "x" + r.y + "," + r.sysScale + ",bitdepth,10";
                if (r.transform !== 0) {
                    monitorStr += ",transform," + r.transform;
                }

                batchCmds.push("hl.monitor({output='" + r.name + "',mode='" + r.resW + "x" + r.resH + "@" + r.rate + "',position='" + r.x + "x" + r.y + "',scale='" + r.sysScale + "',bitdepth=10" + (r.transform !== 0 ? ",transform=" + r.transform : "") + "})");
                confLines.push("monitor=" + monitorStr);
                summaryString += r.name + " ";

                jsonMonitorsArray.push({
                    name: r.name, resW: r.resW, resH: r.resH, rate: parseInt(r.rate),
                    x: r.x, y: r.y, scale: r.sysScale, transform: r.transform
                });
            }

            let fullHyprCmd = batchCmds.map(lua => "hyprctl eval '" + lua.replace(/'/g, "'\\''") + "'").join(" ; ");
            let safeJson = JSON.stringify(jsonMonitorsArray).replace(/'/g, "'\\''");
            let jsonCmd = "jq '.monitors = " + safeJson + "' ~/.config/hypr/settings.json > ~/.config/hypr/settings.json.tmp && mv ~/.config/hypr/settings.json.tmp ~/.config/hypr/settings.json";
            let postReloadCmd = "~/.config/hypr/scripts/ensure_awww.sh --restart";
            let cacheWriteCmd = "echo -e '" + confLines.join("\\n") + "' > ~/.cache/hypr_power_monitor.conf";

            Quickshell.execDetached(["sh", "-c", cacheWriteCmd + " ; " + fullHyprCmd + " ; " + jsonCmd + " ; " + postReloadCmd]);
            Quickshell.execDetached(["notify-send", "Layout Applied"]);

            window.debugLog("Executed multi monitor apply: " + fullHyprCmd);
        }
    }


    // -------------------------------------------------------------------------
    // UI LAYOUT
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        scale: 0.95 + (0.05 * window.introProgress)
        opacity: window.introProgress

        // Anti-bleed base
        Rectangle {
            anchors.fill: parent
            radius: window.s(30)
            color: Qt.rgba(window.crust.r, window.crust.g, window.crust.b, Config.antiBleedOpacity)
            z: -1
        }

        Rectangle {
            anchors.fill: parent
            radius: window.s(30)
            color: Qt.rgba(window.base.r, window.base.g, window.base.b, Config.effectivePopupOpacity)
            border.color: "transparent"
            border.width: 0
            clip: true


            Rectangle {
                width: parent.width * 0.8
                height: width
                radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * window.s(150)
                y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * window.s(100)
                opacity: 0.04
                color: window.selectedResAccent
                Behavior on color { ColorAnimation { duration: 1000 } }
            }
            Rectangle {
                width: parent.width * 0.9
                height: width
                radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * window.s(-150)
                y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * window.s(-100)
                opacity: 0.04
                color: window.selectedRateAccent
                Behavior on color { ColorAnimation { duration: 1000 } }
            }

            // ==========================================
            // LEFT SIDE VISUAL AREA
            // ==========================================
            Item {
                id: leftVisualArea
                width: window.s(380)
                height: window.s(300)
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: window.s(20)

                // --------------------------------------------------
                // MODE 1: SINGLE MONITOR
                // --------------------------------------------------
                Item {
                    anchors.fill: parent
                    visible: monitorsModel.count === 1

                    Item {
                        id: singleMonitorZoom
                        anchors.centerIn: parent
                        width: window.s(380)
                        height: window.s(280)

                        property real baseScale: Math.min(1.0, Math.min(2200 / window.currentSimW, 1400 / Math.max(1, window.currentSimH)))
                        scale: baseScale * window.monitorScale
                        opacity: window.introProgress
                        Behavior on baseScale { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }

                        Rectangle {
                            id: deskSurface
                            width: window.s(1000)
                            height: window.s(14)
                            radius: window.s(6)
                            anchors.top: standBase.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: window.mantle
                            border.color: window.surface0
                            border.width: 1

                            Rectangle {
                                width: window.s(24)
                                height: window.s(350)
                                radius: window.s(4)
                                color: window.crust
                                anchors.top: parent.bottom
                                anchors.topMargin: window.s(-5)
                                anchors.left: parent.left
                                anchors.leftMargin: window.s(100)
                                z: -1
                            }
                            Rectangle {
                                width: window.s(24)
                                height: window.s(350)
                                radius: window.s(4)
                                color: window.crust
                                anchors.top: parent.bottom
                                anchors.topMargin: window.s(-5)
                                anchors.right: parent.right
                                anchors.rightMargin: window.s(100)
                                z: -1
                            }
                        }

                        Rectangle {
                            id: standBase
                            width: window.s(130)
                            height: window.s(8)
                            radius: window.s(4)
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: window.s(20)
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: window.surface1
                        }

                        Rectangle {
                            id: standNeck
                            width: window.s(34)
                            height: window.s(70)
                            anchors.bottom: standBase.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: window.surface0
                            Rectangle {
                                width: window.s(10)
                                height: window.s(30)
                                radius: window.s(5)
                                anchors.centerIn: parent
                                color: window.base
                            }
                        }

                        Rectangle {
                            id: screenBezel

                            // Fit inside a s(320) square stage preserving the REAL panel aspect —
                            // no square monitors exist. Landscape (16:9 → 320x180), portrait
                            // (9:16 → 180x320) and ultrawide all render true to life. The old math
                            // scaled w and h independently off the same s(320) base, which made
                            // every 16:9 panel a perfect square (320×1.5 × 320×1.5).
                            width: {
                                let w = Math.max(1, window.currentSimW), h = Math.max(1, window.currentSimH);
                                return w * Math.min(window.s(320) / w, window.s(320) / h);
                            }
                            height: {
                                let w = Math.max(1, window.currentSimW), h = Math.max(1, window.currentSimH);
                                return h * Math.min(window.s(320) / w, window.s(320) / h);
                            }

                            anchors.bottom: standNeck.top
                            anchors.bottomMargin: window.s(-10)
                            anchors.horizontalCenter: parent.horizontalCenter
                            radius: window.s(12)
                            color: window.crust
                            border.color: window.surface2
                            border.width: window.s(2)

                            Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }
                            Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: window.s(10)
                                radius: window.s(6)
                                color: window.surface0
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    opacity: window.screenLight

                                    gradient: Gradient {
                                        orientation: Gradient.Vertical
                                        GradientStop {
                                            position: 0.0
                                            color: Qt.tint(window.surface0, Qt.alpha(window.selectedResAccent, 0.15))
                                            Behavior on color { ColorAnimation { duration: 400 } }
                                        }
                                        GradientStop {
                                            position: 1.0
                                            color: Qt.tint(window.surface0, Qt.alpha(window.selectedRateAccent, 0.1))
                                            Behavior on color { ColorAnimation { duration: 400 } }
                                        }
                                    }

                                    Grid {
                                        anchors.centerIn: parent
                                        rows: 10
                                        columns: 15
                                        spacing: window.s(20)
                                        Repeater {
                                            model: 150
                                            Rectangle { width: window.s(2); height: window.s(2); radius: window.s(1); color: Qt.alpha(window.text, 0.1) }
                                        }
                                    }
                                }

                                Item {
                                    anchors.centerIn: parent
                                    width: window.s(160)
                                    height: window.s(100)

                                    // 1. Counteract the environmental zoom factor
                                    property real counterScale: 1.0 / singleMonitorZoom.scale

                                    // 2. Compute a safe physical boundary based on current visual rotation
                                    // If rotated (portrait), we compare the wrapper's height to the screen's width, etc.
                                    property real maxPhysicalScale: window.currentIsPortrait
                                        ? Math.min((parent.width * 0.9) / height, (parent.height * 0.9) / width)
                                        : Math.min((parent.width * 0.9) / width, (parent.height * 0.9) / height)

                                    scale: Math.min(counterScale, maxPhysicalScale)

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: window.s(4)

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: window.s(38)
                                            color: window.selectedResAccent
                                            text: "󰍹"
                                            Behavior on color { ColorAnimation { duration: 400 } }
                                        }
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            font.family: "JetBrains Mono"
                                            font.weight: Font.Bold
                                            font.pixelSize: window.s(16)
                                            color: window.text
                                            text: monitorsModel.count > 0 ? monitorsModel.get(0).name : "Unknown"
                                        }
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: window.s(12)
                                            color: window.subtext0
                                            text: window.currentSimW + "x" + window.currentSimH + " @ " + SysData.displayRefreshRate + "Hz"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // --------------------------------------------------
                // MODE 2: MULTI-MONITOR (3+ Supported)
                // --------------------------------------------------
                Item {
                    anchors.fill: parent
                    visible: monitorsModel.count > 1

                    Item {
                        id: multiMonitorView
                        width: window.s(380)
                        height: window.s(280)
                        anchors.centerIn: parent
                        clip: true

                        Grid {
                            anchors.centerIn: parent
                            rows: 25
                            columns: 34
                            spacing: window.s(18)
                            Repeater {
                                model: 850
                                Rectangle { width: window.s(2); height: window.s(2); radius: window.s(1); color: Qt.alpha(window.text, 0.1) }
                            }
                        }

                        property real targetScale: {
                            if (monitorsModel.count < 2) return 1.0;
                            let minX = 999999, minY = 999999, maxX = -999999, maxY = -999999;

                            for (let i = 0; i < monitorsModel.count; i++) {
                                let m = monitorsModel.get(i);
                                let isP = m.transform === 1 || m.transform === 3;
                                let w = ((isP ? m.resH : m.resW) / m.sysScale) * window.uiScale;
                                let h = ((isP ? m.resW : m.resH) / m.sysScale) * window.uiScale;

                                minX = Math.min(minX, m.uiX);
                                minY = Math.min(minY, m.uiY);
                                maxX = Math.max(maxX, m.uiX + w);
                                maxY = Math.max(maxY, m.uiY + h);
                            }

                            let requiredW = (maxX - minX) + window.s(80);
                            let requiredH = (maxY - minY) + window.s(80);

                            return Math.min(1.8 * scaler.baseScale, Math.min(window.s(340) / requiredW, window.s(240) / requiredH));
                        }

                        property real offsetX: {
                            if (monitorsModel.count < 2) return 0;
                            let minX = 999999, maxX = -999999;

                            for (let i = 0; i < monitorsModel.count; i++) {
                                let m = monitorsModel.get(i);
                                let isP = m.transform === 1 || m.transform === 3;
                                let w = ((isP ? m.resH : m.resW) / m.sysScale) * window.uiScale;

                                minX = Math.min(minX, m.uiX);
                                maxX = Math.max(maxX, m.uiX + w);
                            }

                            let centerX = minX + (maxX - minX) / 2;
                            return window.s(190) - (centerX * targetScale);
                        }

                        property real offsetY: {
                            if (monitorsModel.count < 2) return 0;
                            let minY = 999999, maxY = -999999;

                            for (let i = 0; i < monitorsModel.count; i++) {
                                let m = monitorsModel.get(i);
                                let isP = m.transform === 1 || m.transform === 3;
                                let h = ((isP ? m.resW : m.resH) / m.sysScale) * window.uiScale;

                                minY = Math.min(minY, m.uiY);
                                maxY = Math.max(maxY, m.uiY + h);
                            }

                            let centerY = minY + (maxY - minY) / 2;
                            return window.s(140) - (centerY * targetScale);
                        }

                        Item {
                            id: transformNode
                            x: multiMonitorView.offsetX
                            y: multiMonitorView.offsetY
                            scale: multiMonitorView.targetScale
                            transformOrigin: Item.TopLeft

                            Behavior on x { enabled: window.visible; NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                            Behavior on y { enabled: window.visible; NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                            Behavior on scale { enabled: window.visible; NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                            Repeater {
                                id: monitorRepeater
                                model: monitorsModel

                                Item {
                                    property bool isActive: window.activeEditIndex === index
                                    property bool isPortrait: model.transform === 1 || model.transform === 3

                                    // THE VISIBLE SNAPPED MONITOR CARD
                                    Rectangle {
                                        id: monitorCard
                                        x: model.uiX
                                        y: model.uiY

                                        width: (isPortrait ? model.resH : model.resW) / model.sysScale * window.uiScale
                                        height: (isPortrait ? model.resW : model.resH) / model.sysScale * window.uiScale

                                        radius: window.s(8)
                                        color: isActive ? Qt.alpha(window.selectedResAccent, 0.2) : (Config.effectiveCardOpacity > 0 ? Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, Config.effectiveCardOpacity) : Qt.rgba(window.text.r, window.text.g, window.text.b, 0.08))
                                        border.color: isActive ? window.selectedResAccent : Qt.alpha(window.surface2, 0.4)
                                        border.width: isActive ? window.s(2) : window.s(1)
                                        z: isActive ? 5 : 0

                                        Behavior on x { enabled: window.visible; NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                                        Behavior on y { enabled: window.visible; NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

                                        Behavior on border.color { ColorAnimation { duration: 300 } }
                                        Behavior on color { ColorAnimation { duration: 300 } }
                                        Behavior on width { enabled: window.visible; NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                                        Behavior on height { enabled: window.visible; NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                        Item {
                                            anchors.centerIn: parent
                                            width: window.s(110)
                                            height: window.s(80)

                                            property real idealScale: 1.2 / transformNode.scale
                                            // Ensure the bounded box checks against the correct axis when visually rotated
                                            property real maxPhysicalScale: isPortrait
                                                ? Math.min((parent.width * 0.9) / height, (parent.height * 0.9) / width)
                                                : Math.min((parent.width * 0.9) / width, (parent.height * 0.9) / height)

                                            scale: Math.min(idealScale, maxPhysicalScale)

                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: window.s(2)

                                                Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    font.family: "Iosevka Nerd Font"
                                                    font.pixelSize: window.s(32)
                                                    color: isActive ? window.selectedResAccent : window.text
                                                    text: "󰍹"
                                                    Behavior on color { ColorAnimation { duration: 300 } }
                                                }
                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    font.family: "JetBrains Mono"
                                                    font.weight: Font.Black
                                                    font.pixelSize: window.s(13)
                                                    color: window.text
                                                    text: model.name
                                                }
                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    font.family: "JetBrains Mono"
                                                    font.pixelSize: window.s(10)
                                                    color: window.subtext0
                                                    text: model.resW + "x" + model.resH + " @ " + model.rate + "Hz"
                                                }
                                            }
                                        }
                                    }

                                    // THE INVISIBLE GHOST DRAGGER
                                    Item {
                                        id: ghostDrag
                                        x: model.uiX
                                        y: model.uiY
                                        width: monitorCard.width
                                        height: monitorCard.height
                                        z: isActive ? 10 : 1

                                        MouseArea {
                                            id: ghostMa
                                            anchors.fill: parent
                                            drag.target: ghostDrag
                                            drag.axis: Drag.XAndYAxis

                                            onPressed: {
                                                window.activeEditIndex = index;
                                                ghostDrag.x = model.uiX;
                                                ghostDrag.y = model.uiY;
                                            }

                                            onPositionChanged: {
                                                if (drag.active && monitorsModel.count >= 2) {
                                                    let mW = monitorCard.width;
                                                    let mH = monitorCard.height;

                                                    let padding = window.s(40);
                                                    let boundMinX = 999999, boundMinY = 999999;
                                                    let boundMaxX = -999999, boundMaxY = -999999;

                                                    for (let j = 0; j < monitorsModel.count; j++) {
                                                        if (j === index) continue;
                                                        let sModel = monitorsModel.get(j);
                                                        let sIsP = sModel.transform === 1 || sModel.transform === 3;
                                                        let sW = ((sIsP ? sModel.resH : sModel.resW) / sModel.sysScale) * window.uiScale;
                                                        let sH = ((sIsP ? sModel.resW : sModel.resH) / sModel.sysScale) * window.uiScale;

                                                        boundMinX = Math.min(boundMinX, sModel.uiX - mW - padding);
                                                        boundMinY = Math.min(boundMinY, sModel.uiY - mH - padding);
                                                        boundMaxX = Math.max(boundMaxX, sModel.uiX + sW + padding);
                                                        boundMaxY = Math.max(boundMaxY, sModel.uiY + sH + padding);
                                                    }

                                                    ghostDrag.x = Math.max(boundMinX, Math.min(ghostDrag.x, boundMaxX));
                                                    ghostDrag.y = Math.max(boundMinY, Math.min(ghostDrag.y, boundMaxY));

                                                    let bestX = ghostDrag.x;
                                                    let bestY = ghostDrag.y;
                                                    let bestDist = 999999;

                                                    for (let j = 0; j < monitorsModel.count; j++) {
                                                        if (j === index) continue;
                                                        let sModel = monitorsModel.get(j);
                                                        let sIsP = sModel.transform === 1 || sModel.transform === 3;
                                                        let sW = ((sIsP ? sModel.resH : sModel.resW) / sModel.sysScale) * window.uiScale;
                                                        let sH = ((sIsP ? sModel.resW : sModel.resH) / sModel.sysScale) * window.uiScale;

                                                        let snapped = window.getPerimeterSnap(
                                                            ghostDrag.x, ghostDrag.y,
                                                            sModel.uiX, sModel.uiY,
                                                            sW, sH, mW, mH, window.s(20)
                                                        );

                                                        let dist = Math.hypot(ghostDrag.x - snapped.x, ghostDrag.y - snapped.y);
                                                        if (dist < bestDist) {
                                                            bestDist = dist;
                                                            bestX = snapped.x;
                                                            bestY = snapped.y;
                                                        }
                                                    }

                                                    if (!window.isOverlappingAny(bestX, bestY, mW, mH, index)) {
                                                        monitorsModel.setProperty(index, "uiX", bestX);
                                                        monitorsModel.setProperty(index, "uiY", bestY);
                                                    }
                                                }
                                            }

                                            onReleased: {
                                                ghostDrag.x = model.uiX;
                                                ghostDrag.y = model.uiY;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // INTERACTIVE SELECTION GRIDS
            // ==========================================
            Item {
                id: rightSideOuter
                anchors.left: leftVisualArea.right
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: window.s(20)
                anchors.bottomMargin: window.s(20)
                anchors.leftMargin: window.s(10)
                anchors.rightMargin: window.s(24)

                opacity: window.introProgress
                transform: Translate { y: window.uiYOffset }

                SequentialAnimation {
                    id: menuTransitionAnim
                    ParallelAnimation {
                        ScaleAnimator {
                            target: rightSideContainer
                            from: 0.99
                            to: 1.0
                            duration: 200
                            easing.type: Easing.OutSine
                        }
                        NumberAnimation {
                            target: highlightFlash
                            property: "opacity"
                            from: 0.05
                            to: 0.0
                            duration: 250
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                Rectangle {
                    id: highlightFlash
                    anchors.fill: rightSideContainer
                    anchors.margins: window.s(-10)
                    color: window.selectedResAccent
                    opacity: 0.0
                    radius: window.s(12)
                }

                ColumnLayout {
                    id: rightSideContainer
                    anchors.fill: parent
                    spacing: window.s(8)

                    // --- RESOLUTION CARDS SECTION (SCROLLABLE & RESPONSIVE) ---
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        Flickable {
                            id: resFlickable
                            anchors.fill: parent
                            contentWidth: width
                            contentHeight: resGrid.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            GridLayout {
                                id: resGrid
                                width: resFlickable.width - (resFlickable.contentHeight > resFlickable.height ? window.s(10) : 0)
                                columns: 2
                                columnSpacing: window.s(8)
                                rowSpacing: window.s(8)

                                Repeater {
                                    model: window.resList

                                    delegate: Rectangle {
                                        // Built-in Repeater `modelData` role (the resList element)
                                        // is used directly — no shadow binding, so recycled delegates
                                        // can never render a stale index's tile as a phantom duplicate.
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: window.s(42)
                                        radius: window.s(10)

                                        property bool isSel: {
                                            if (monitorsModel.count === 0) return false;
                                            let activeMon = monitorsModel.get(window.activeEditIndex);
                                            return activeMon.resW === modelData.w && activeMon.resH === modelData.h;
                                        }
                                        property color accentColor: modelData.accent

                                        color: isSel ? Qt.alpha(accentColor, 0.15) : (resMa.containsMouse ? Qt.rgba(window.text.r, window.text.g, window.text.b, 0.12) : (Config.effectiveCardOpacity > 0 ? Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, Config.effectiveCardOpacity) : Qt.rgba(window.text.r, window.text.g, window.text.b, 0.08)))
                                        border.color: isSel ? accentColor : (resMa.containsMouse ? Qt.alpha(window.text, 0.2) : Qt.alpha(window.surface1, 0.3))
                                        border.width: isSel ? window.s(2) : window.s(1)

                                        Behavior on color { ColorAnimation { duration: 200 } }
                                        Behavior on border.color { ColorAnimation { duration: 200 } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: window.s(10)
                                            spacing: window.s(6)

                                            Text {
                                                font.family: "JetBrains Mono"
                                                font.weight: isSel ? Font.Black : Font.Bold
                                                font.pixelSize: window.s(14)
                                                color: isSel ? accentColor : window.text
                                                text: modelData.l
                                                Behavior on color { ColorAnimation { duration: 200 } }
                                            }

                                            Item { Layout.fillWidth: true }

                                            Text {
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: window.s(10)
                                                color: isSel ? window.text : window.subtext0
                                                text: modelData.w + "x" + modelData.h
                                                Behavior on color { ColorAnimation { duration: 200 } }
                                            }
                                        }

                                        scale: resMa.pressed ? 0.96 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutSine } }

                                        MouseArea {
                                            id: resMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                window.activeFocusIndex = 0;
                                                if (monitorsModel.count > 0) {
                                                    window.selectedResAccent = accentColor;
                                                    monitorsModel.setProperty(window.activeEditIndex, "resW", modelData.w);
                                                    monitorsModel.setProperty(window.activeEditIndex, "resH", modelData.h);
                                                    window._resEpoch++;
                                                    delayedLayoutUpdate.restart();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Scroll Indicator
                        Rectangle {
                            id: scrollBarTrack
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: window.s(4)
                            radius: window.s(2)
                            color: "transparent"
                            visible: resFlickable.contentHeight > resFlickable.height

                            Rectangle {
                                width: parent.width
                                height: Math.max(window.s(24), resFlickable.height * (resFlickable.height / Math.max(1, resFlickable.contentHeight)))
                                y: resFlickable.contentHeight > resFlickable.height ? (resFlickable.contentY / (resFlickable.contentHeight - resFlickable.height)) * (resFlickable.height - height) : 0
                                radius: parent.radius
                                color: Qt.alpha(window.text, 0.25)
                            }
                        }

                        WheelHandler {
                            target: resFlickable
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: (event) => {
                                let delta = -event.angleDelta.y * 0.8;
                                resFlickable.contentY = Math.max(0, Math.min(resFlickable.contentHeight - resFlickable.height, resFlickable.contentY + delta));
                            }
                        }
                    }

                    Item { Layout.preferredHeight: window.s(2) }

                    // --- ROTATION CLOCK DIAL SECTION ---
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.s(120)

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            id: clockDial
                            Layout.preferredWidth: window.s(120)
                            Layout.preferredHeight: window.s(120)
                            Layout.alignment: Qt.AlignCenter

                            radius: width / 2
                            color: Config.effectiveCardOpacity > 0 ? Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, Config.effectiveCardOpacity) : Qt.rgba(window.text.r, window.text.g, window.text.b, 0.08)

                            border.color: window.activeFocusIndex === 1 ? window.primary : Qt.alpha(window.surface1, 0.3)
                            border.width: window.activeFocusIndex === 1 ? window.s(3) : window.s(2)
                            Behavior on border.color { ColorAnimation { duration: 200 } }
                            Behavior on border.width { NumberAnimation { duration: 200 } }

                            // 12-Hour Clock Tick Marks
                            Repeater {
                                model: 12
                                Item {
                                    anchors.fill: parent
                                    rotation: index * 30
                                    Rectangle {
                                        width: index % 3 === 0 ? window.s(4) : window.s(2)
                                        height: index % 3 === 0 ? window.s(8) : window.s(4)
                                        radius: width / 2
                                        color: index % 3 === 0 ? window.subtext0 : window.surface2
                                        anchors.top: parent.top
                                        anchors.topMargin: window.s(4)
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            // The Interactive Pointer
                            Item {
                                id: dialPointer
                                anchors.fill: parent
                                property int activeTransform: monitorsModel.count > 0 ? monitorsModel.get(window.activeEditIndex).transform : 0
                                rotation: activeTransform * 90
                                Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }

                                // Pointer Line
                                Rectangle {
                                    width: window.s(5)
                                    height: parent.height / 2 - window.s(20)
                                    radius: window.s(2.5)
                                    color: window.primary
                                    anchors.bottom: parent.verticalCenter
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }

                                // Center Dot
                                Rectangle {
                                    width: window.s(18)
                                    height: window.s(18)
                                    radius: width / 2
                                    color: window.base
                                    border.color: window.primary
                                    border.width: window.s(4)
                                    anchors.centerIn: parent
                                    Behavior on border.color { ColorAnimation { duration: 300 } }
                                }
                            }

                            MouseArea {
                                id: dialMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                function updateAngle(mouse) {
                                    if (monitorsModel.count === 0) return;
                                    window.activeFocusIndex = 1;

                                    let dx = mouse.x - width / 2;
                                    let dy = mouse.y - height / 2;

                                    if (Math.hypot(dx, dy) < window.s(20)) return;

                                    let snap = 0;
                                    if (Math.abs(dx) > Math.abs(dy)) {
                                        snap = dx > 0 ? 1 : 3;
                                    } else {
                                        snap = dy > 0 ? 2 : 0;
                                    }

                                    monitorsModel.setProperty(window.activeEditIndex, "transform", snap);
                                    delayedLayoutUpdate.restart();
                                }

                                onPressed: (mouse) => updateAngle(mouse)
                                onPositionChanged: (mouse) => { if (pressed) updateAngle(mouse) }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                    Item { Layout.preferredHeight: window.s(2) }

                    // --- REFRESH RATE SLIDER SECTION ---
                    Item {
                        id: sliderContainer
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.s(45)
                        Layout.leftMargin: window.s(6)
                        Layout.rightMargin: window.s(6)

                        property var rates: window.rateList.length > 0 ? window.rateList : [60, 120]

                        property int currentIndex: {
                            if (monitorsModel.count === 0) return 0;
                            let currentVal = parseInt(monitorsModel.get(window.activeEditIndex).rate) || 60;
                            let closestIdx = 0;
                            let minDiff = 9999;
                            for (let i = 0; i < rates.length; i++) {
                                let diff = Math.abs(rates[i] - currentVal);
                                if (diff < minDiff) {
                                    minDiff = diff;
                                    closestIdx = i;
                                }
                            }
                            return closestIdx;
                        }

                        property real visualPct: currentIndex / Math.max(1, rates.length - 1)

                        onCurrentIndexChanged: {
                            if (!sliderMa.pressed) visualPct = currentIndex / Math.max(1, rates.length - 1);
                        }

                        function updateSelectionVisual(idx) {
                            if (monitorsModel.count === 0) return;
                            visualPct = idx / Math.max(1, rates.length - 1);
                            monitorsModel.setProperty(window.activeEditIndex, "rate", rates[idx].toString());
                            window.selectedRateAccent = window.primary;
                        }

                        Rectangle {
                            id: track
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: window.s(15)
                            anchors.rightMargin: window.s(15)
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: window.s(-10)
                            height: window.s(12)
                            radius: window.s(6)
                            color: Qt.rgba(window.text.r, window.text.g, window.text.b, 0.10)
                            border.color: Qt.alpha(window.surface2, 0.3)
                            border.width: Config.borderWidth

                            Rectangle {
                                id: trackFill
                                width: Math.max(0, knob.x + knob.width / 2)
                                height: parent.height
                                radius: parent.radius
                                color: window.selectedRateAccent
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }

                            Rectangle {
                                id: knob
                                width: window.s(24)
                                height: window.s(24)
                                radius: window.s(12)
                                color: sliderMa.containsPress ? window.selectedRateAccent : window.text
                                anchors.verticalCenter: parent.verticalCenter
                                x: (sliderContainer.visualPct * parent.width) - width / 2

                                Behavior on x {
                                    enabled: !sliderMa.pressed
                                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                                }
                                Behavior on color { ColorAnimation { duration: 150 } }

                                border.width: (sliderMa.containsMouse || window.activeFocusIndex === 2) ? window.s(4) : 0
                                border.color: Qt.alpha(window.selectedRateAccent, 0.4)
                                Behavior on border.width { NumberAnimation { duration: 150 } }
                            }
                        }

                        Repeater {
                            model: sliderContainer.rates.length
                            Item {
                                x: track.x + (index / Math.max(1, sliderContainer.rates.length - 1)) * track.width
                                y: track.y + window.s(20)

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: sliderContainer.rates[index]
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: window.s(13)
                                    font.weight: sliderContainer.currentIndex === index ? Font.Bold : Font.Normal
                                    color: sliderContainer.currentIndex === index ? window.selectedRateAccent : window.subtext0
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }
                        }

                        MouseArea {
                            id: sliderMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            function updateSelection(mouseX, snapToGrid) {
                                if (monitorsModel.count === 0) return;
                                window.activeFocusIndex = 2;

                                let pct = (mouseX - track.x) / track.width;
                                pct = Math.max(0, Math.min(1, pct));
                                let idx = Math.round(pct * (sliderContainer.rates.length - 1));

                                if (snapToGrid) {
                                    sliderContainer.visualPct = idx / Math.max(1, sliderContainer.rates.length - 1);
                                } else {
                                    sliderContainer.visualPct = pct;
                                }

                                monitorsModel.setProperty(window.activeEditIndex, "rate", sliderContainer.rates[idx].toString());
                                window.selectedRateAccent = window.primary;
                            }

                            onPressed: (mouse) => updateSelection(mouse.x, false)
                            onPositionChanged: (mouse) => { if (pressed) updateSelection(mouse.x, false) }
                            onReleased: (mouse) => updateSelection(mouse.x, true)
                            onCanceled: () => sliderContainer.visualPct = sliderContainer.currentIndex / Math.max(1, sliderContainer.rates.length - 1)
                        }
                    }

                    Item { Layout.preferredHeight: window.s(2) }

                    // --- SCALE SLIDER SECTION ---
                    Item {
                        id: scaleSliderContainer
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.s(45)
                        Layout.leftMargin: window.s(6)
                        Layout.rightMargin: window.s(6)

                        property var scales: [1.0, 1.25, 1.33, 1.5, 1.8, 2.0, 2.5]
                        property var scaleLabels: ["1x", "1.25", "1.33", "1.5", "1.8", "2x", "2.5x"]

                        property int currentIndex: {
                            if (monitorsModel.count === 0) return 0;
                            let currentVal = parseFloat(monitorsModel.get(window.activeEditIndex).sysScale) || 1.0;
                            let closestIdx = 0;
                            let minDiff = 9999;
                            for (let i = 0; i < scales.length; i++) {
                                let diff = Math.abs(scales[i] - currentVal);
                                if (diff < minDiff) {
                                    minDiff = diff;
                                    closestIdx = i;
                                }
                            }
                            return closestIdx;
                        }

                        property real visualPct: currentIndex / (scales.length - 1)

                        onCurrentIndexChanged: {
                            if (!scaleSliderMa.pressed) visualPct = currentIndex / (scales.length - 1);
                        }

                        function updateSelectionVisual(idx) {
                            if (monitorsModel.count === 0) return;
                            visualPct = idx / (scales.length - 1);
                            monitorsModel.setProperty(window.activeEditIndex, "sysScale", scales[idx]);
                            window.selectedScaleAccent = window.primary;
                            delayedLayoutUpdate.restart();
                        }

                        Rectangle {
                            id: scaleTrack
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: window.s(15)
                            anchors.rightMargin: window.s(15)
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: window.s(-10)
                            height: window.s(12)
                            radius: window.s(6)
                            color: Qt.rgba(window.text.r, window.text.g, window.text.b, 0.10)
                            border.color: Qt.alpha(window.surface2, 0.3)
                            border.width: Config.borderWidth

                            Rectangle {
                                id: scaleTrackFill
                                width: Math.max(0, scaleKnob.x + scaleKnob.width / 2)
                                height: parent.height
                                radius: parent.radius
                                color: window.selectedScaleAccent
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }

                            Rectangle {
                                id: scaleKnob
                                width: window.s(24)
                                height: window.s(24)
                                radius: window.s(12)
                                color: scaleSliderMa.containsPress ? window.selectedScaleAccent : window.text
                                anchors.verticalCenter: parent.verticalCenter
                                x: (scaleSliderContainer.visualPct * parent.width) - width / 2

                                Behavior on x {
                                    enabled: !scaleSliderMa.pressed
                                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                                }
                                Behavior on color { ColorAnimation { duration: 150 } }

                                border.width: (scaleSliderMa.containsMouse || window.activeFocusIndex === 3) ? window.s(4) : 0
                                border.color: Qt.alpha(window.selectedScaleAccent, 0.4)
                                Behavior on border.width { NumberAnimation { duration: 150 } }
                            }
                        }

                        Repeater {
                            model: scaleSliderContainer.scales.length
                            Item {
                                x: scaleTrack.x + (index / (scaleSliderContainer.scales.length - 1)) * scaleTrack.width
                                y: scaleTrack.y + window.s(20)

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: scaleSliderContainer.scaleLabels[index]
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: window.s(13)
                                    font.weight: scaleSliderContainer.currentIndex === index ? Font.Bold : Font.Normal
                                    color: scaleSliderContainer.currentIndex === index ? window.selectedScaleAccent : window.subtext0
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }
                        }

                        MouseArea {
                            id: scaleSliderMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            function updateSelection(mouseX, snapToGrid) {
                                if (monitorsModel.count === 0) return;
                                window.activeFocusIndex = 3;

                                let pct = (mouseX - scaleTrack.x) / scaleTrack.width;
                                pct = Math.max(0, Math.min(1, pct));
                                let idx = Math.round(pct * (scaleSliderContainer.scales.length - 1));

                                if (snapToGrid) {
                                    scaleSliderContainer.visualPct = idx / (scaleSliderContainer.scales.length - 1);
                                } else {
                                    scaleSliderContainer.visualPct = pct;
                                }

                                monitorsModel.setProperty(window.activeEditIndex, "sysScale", scaleSliderContainer.scales[idx]);
                                window.selectedScaleAccent = window.primary;
                                delayedLayoutUpdate.restart();
                            }

                            onPressed: (mouse) => updateSelection(mouse.x, false)
                            onPositionChanged: (mouse) => { if (pressed) updateSelection(mouse.x, false) }
                            onReleased: (mouse) => updateSelection(mouse.x, true)
                            onCanceled: () => scaleSliderContainer.visualPct = scaleSliderContainer.currentIndex / (scaleSliderContainer.scales.length - 1)
                        }
                    }

                    Item { Layout.preferredHeight: window.s(15) }

                    // ==========================================
                    // FLOATING APPLY BUTTON
                    // ==========================================
                    Item {
                        id: applyButtonContainer
                        Layout.alignment: Qt.AlignRight
                        Layout.preferredWidth: window.s(170)
                        Layout.preferredHeight: window.s(50)

                        MultiEffect {
                            source: applyBtn
                            anchors.fill: applyBtn
                            shadowEnabled: true
                            shadowColor: window.primary
                            shadowBlur: window.applyHovered || window.activeFocusIndex === 4 ? 1.2 : 0.6
                            shadowOpacity: window.applyHovered || window.activeFocusIndex === 4 ? 0.6 : 0.2
                            shadowVerticalOffset: window.s(4)
                            z: -1
                            Behavior on shadowBlur { NumberAnimation { duration: 300 } }
                            Behavior on shadowOpacity { NumberAnimation { duration: 300 } }
                            Behavior on shadowColor { ColorAnimation { duration: 400 } }
                        }

                        Rectangle {
                            id: applyBtn
                            anchors.fill: parent
                            radius: window.s(25)
                            color: window.primary
                            Behavior on color { ColorAnimation { duration: 300 } }

                            border.color: window.activeFocusIndex === 4 ? window.crust : "transparent"
                            border.width: window.activeFocusIndex === 4 ? window.s(2) : 0

                            scale: window.applyPressed ? 0.94 : (window.applyHovered || window.activeFocusIndex === 4 ? 1.04 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                            Rectangle {
                                id: flashRect
                                anchors.fill: parent
                                radius: window.s(25)
                                color: window.text
                                opacity: 0.0
                                PropertyAnimation on opacity {
                                    id: applyFlashAnim
                                    to: 0.0
                                    duration: 400
                                    easing.type: Easing.OutExpo
                                }
                            }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: window.s(8)

                                Text {
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: window.s(20)
                                    color: window.crust
                                    text: "󰸵"
                                }

                                Text {
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Black
                                    font.pixelSize: window.s(14)
                                    color: window.crust
                                    text: monitorsModel.count > 1 ? "Apply All" : "Apply"
                                }
                            }
                        }

                        MouseArea {
                            id: applyMa
                            anchors.fill: parent
                            z: 10
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: { window.applyHovered = true; window.activeFocusIndex = 4; }
                            onExited: window.applyHovered = false
                            onPressed: window.applyPressed = true
                            onReleased: window.applyPressed = false
                            onCanceled: window.applyPressed = false

                            onClicked: window.triggerApply()
                        }
                    }
                }
            }
        }
    }
}