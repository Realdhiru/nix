.pragma library

const REF_W = 1920.0;
const REF_H = 1080.0;
const MIN_SCALE = 0.35;
const HIDE_OFFSET = -5000;

const WIDGETS = {
    "battery":   { w: 801,  h: 660, anchor: "top-right",     mx: 0, my: 60, mr: 4, mb: 0, path: "battery/BatteryPopup.qml" },
    "network":   { w: 900,  h: 700, anchor: "top-right",     mx: 0, my: 60, mr: 4, mb: 0, path: "network/NetworkPopup.qml" },
    "clipboard": { w: 800,  h: 700, anchor: "center",        mx: 0, my: 0,  mr: 0, mb: 0, path: "clipboard/ClipboardManager.qml" },
    "monitors":  { w: 800,  h: 720, anchor: "center",        mx: 0, my: 0,  mr: 0, mb: 0, path: "monitors/MonitorPopup.qml" },
    "focustime": { w: 900,  h: 700, anchor: "center",        mx: 0, my: 0,  mr: 0, mb: 0, path: "focustime/FocusTimePopup.qml" },
    "weather_setup": { w: 500,  h: 350, anchor: "center",     mx: 0, my: 0,  mr: 0, mb: 0, path: "calendar/WeatherSetupPopup.qml" },
    "calendar":      { w: 1450, h: 510, anchor: "top-center", mx: 0, my: 60, mr: 0, mb: 0, path: "calendar/CalendarPopup.qml" },
    "wallpaper": { w: -1,   h: 650, anchor: "center-fill",   mx: 0, my: 0,  mr: 0, mb: 0, path: "wallpaper/WallpaperPicker.qml" },
    "music":     { w: 700,  h: 650, anchor: "top-left",      mx: 5, my: 60, mr: 0, mb: 0, path: "music/MusicPopup.qml" },
    "sunset":    { w: 320,  h: 390, anchor: "bottom-left", mx: 52, my: 0,  mr: 0, mb: 12, path: "sunset/SunsetPopup.qml" }
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

function getLayout(name, mx, my, mw, mh, userScale, barPos) {
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

    let scale = getScale(mw, mh, userScale);
    let finalW = config.w === -1 ? mw : s(config.w, scale);
    let finalH = s(config.h, scale);

    // Responsive ceiling: clamp to 96% width and 94% height to prevent off-screen clipping
    let maxAllowedW = Math.floor(mw * 0.96);
    let maxAllowedH = Math.floor(mh * 0.94);
    if (config.w !== -1 && finalW > maxAllowedW) {
        finalW = maxAllowedW;
    }
    if (finalH > maxAllowedH) {
        finalH = maxAllowedH;
    }
    
    let isLeftBar = (barPos === "left");
    let rx = 0;
    let ry = 0;

    switch (config.anchor) {
        case "top-left":
            rx = isLeftBar ? 52 : s(config.mx, scale);
            ry = isLeftBar ? 10 : s(config.my, scale);
            break;
        case "bottom-left":
            rx = isLeftBar ? 52 : (s(config.mx, scale) || 12);
            ry = mh - finalH - (isLeftBar ? 12 : s(config.mb, scale));
            break;
        case "top-right":
            if (isLeftBar) {
                rx = 52;
                // battery and network pop up at bottom-left next to sidebar icons
                ry = (name === "battery" || name === "network") ? (mh - finalH - 12) : 10;
            } else {
                rx = mw - finalW - s(config.mr, scale);
                ry = s(config.my, scale);
            }
            break;
        case "top-center":
            rx = Math.floor((mw / 2) - (finalW / 2)) + (isLeftBar ? 26 : 0);
            ry = isLeftBar ? 10 : s(config.my, scale);
            break;
        case "center":
            rx = Math.floor((mw / 2) - (finalW / 2)) + (isLeftBar ? 26 : 0);
            ry = Math.floor((mh / 2) - (finalH / 2));
            break;
        case "center-fill":
            rx = isLeftBar ? 48 : 0;
            ry = Math.floor((mh / 2) - (finalH / 2));
            break;
        case "bottom-center":
            rx = Math.floor((mw / 2) - (finalW / 2)) + (isLeftBar ? 26 : 0);
            ry = mh - finalH - s(config.mb, scale);
            break;
    }

    // Safety boundary clamp: ensure popups never render outside screen edges
    let minX = isLeftBar ? 48 : 0;
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