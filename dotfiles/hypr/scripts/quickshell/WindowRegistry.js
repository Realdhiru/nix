.pragma library

const REF_W = 1920.0;
const REF_H = 1080.0;
const MIN_SCALE = 0.35;
const HIDE_OFFSET = -5000;

const WIDGETS = {
    "battery":       { w: 801,  h: 660, anchor: "top-right",     path: "battery/BatteryPopup.qml" },
    "network":       { w: 900,  h: 700, anchor: "top-right",     path: "network/NetworkPopup.qml" },
    "clipboard":     { w: 800,  h: 700, anchor: "center",        path: "clipboard/ClipboardManager.qml" },
    "monitors":      { w: 700,  h: 410, anchor: "bottom-center", path: "monitors/MonitorPopup.qml" },
    "focustime":     { w: 900,  h: 700, anchor: "center",        path: "focustime/FocusTimePopup.qml" },
    "weather_setup": { w: 500,  h: 350, anchor: "center",        path: "calendar/WeatherSetupPopup.qml" },
    "calendar":      { w: 1450, h: 510, anchor: "top-center",    path: "calendar/CalendarPopup.qml" },
    "wallpaper":     { w: -1,   h: 650, anchor: "center-fill",   path: "wallpaper/WallpaperPicker.qml" },
    "music":         { w: 700,  h: 650, anchor: "top-left",      path: "music/MusicPopup.qml" },
    "sunset":        { w: 320,  h: 390, anchor: "bottom-left",   path: "sunset/SunsetPopup.qml" }
};

function getScale(mw, mh, userScale) {
    if (userScale === undefined && mh !== undefined) {
        userScale = mh;
        mh = mw * (REF_H / REF_W);
    }

    if (mw <= 0 || mh <= 0) return 1.0;
    
    let rw = mw / REF_W;
    let rh = mh / REF_H;
    let r = Math.min(rw, rh);
    
    let baseScale = 1.0;
    
    if (r <= 1.0) {
        baseScale = Math.max(MIN_SCALE, Math.pow(r, 0.85));
    } else {
        baseScale = Math.pow(r, 0.5);
    }
    
    return baseScale * (userScale !== undefined ? userScale : 1.0);
}

function s(val, scale) {
    return Math.round(val * scale);
}

function getLayout(name, mx, my, mw, mh, userScale, barPos, gapsOut) {
    if (name === "hidden") {
        return { 
            w: 1, 
            h: 1, 
            rx: HIDE_OFFSET - mx, 
            ry: HIDE_OFFSET - my, 
            comp: "",
            x: HIDE_OFFSET,
            y: HIDE_OFFSET
        };
    }

    const config = WIDGETS[name];
    if (!config) return null;

    let isLeftBar = (barPos === "left");
    let gap = (gapsOut !== undefined && gapsOut !== null && gapsOut >= 0) ? gapsOut : 12;

    // Reserve the bar's 46px content footprint; the edge margin is already
    // supplied by Hyprland's outer gap and must not be counted twice.
    const BAR_FOOTPRINT = 46;
    let usableLeft = isLeftBar ? (BAR_FOOTPRINT + gap) : gap;
    let usableRight = mw - gap;
    let usableTop = isLeftBar ? gap : (BAR_FOOTPRINT + gap);
    let usableBottom = mh - gap;

    let usableW = Math.max(0, usableRight - usableLeft);
    let usableH = Math.max(0, usableBottom - usableTop);

    let scale = getScale(mw, mh, userScale);
    let finalW = config.w === -1 ? mw : s(config.w, scale);
    let finalH = s(config.h, scale);

    // Responsive ceiling: clamp to screen bounds to prevent off-screen clipping
    let maxAllowedW = Math.floor(mw * 0.96);
    let maxAllowedH = Math.floor(mh * 0.94);
    if (config.w !== -1 && finalW > maxAllowedW) {
        finalW = maxAllowedW;
    }
    if (finalH > maxAllowedH) {
        finalH = maxAllowedH;
    }

    let rx = 0;
    let ry = 0;

    switch (config.anchor) {
        case "top-left":
            rx = usableLeft;
            ry = usableTop;
            break;
        case "bottom-left":
            rx = usableLeft;
            ry = usableBottom - finalH;
            break;
        case "top-right":
            if (isLeftBar) {
                // Dock alongside sidebar icons at bottom-left
                rx = usableLeft;
                ry = (name === "battery" || name === "network") ? (usableBottom - finalH) : usableTop;
            } else {
                rx = usableRight - finalW;
                ry = usableTop;
            }
            break;
        case "top-center":
            rx = usableLeft + Math.floor((usableW - finalW) / 2);
            ry = usableTop;
            break;
        case "center":
            rx = usableLeft + Math.floor((usableW - finalW) / 2);
            ry = usableTop + Math.floor((usableH - finalH) / 2);
            break;
        case "center-fill":
            rx = isLeftBar ? usableLeft : 0;
            ry = usableTop + Math.floor((usableH - finalH) / 2);
            break;
        case "bottom-center":
            rx = usableLeft + Math.floor((usableW - finalW) / 2);
            ry = usableBottom - finalH;
            break;
    }

    // Safety boundary clamp: ensure popups strictly stay within window margin bounds
    let minX = isLeftBar ? usableLeft : 0;
    rx = Math.max(minX, Math.min(rx, Math.max(0, mw - finalW)));
    ry = Math.max(0, Math.min(ry, Math.max(0, mh - finalH)));

    return {
        w: finalW,
        h: finalH,
        rx: rx,
        ry: ry,
        comp: config.path,
        x: mx + rx,
        y: my + ry
    };
}

function getPopupLayout(mw, mh, userScale) {
    if (userScale === undefined && mh !== undefined) {
        userScale = mh;
        mh = mw * (REF_H / REF_W);
    }
    
    let scale = getScale(mw, mh, userScale);
    return {
        w: s(350, scale),
        marginTop: s(60, scale),
        marginRight: s(20, scale),
        spacing: s(12, scale),
        radius: s(14, scale),
        padding: s(12, scale)
    };
}
