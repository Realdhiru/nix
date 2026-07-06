.pragma library

const REF_W = 1920.0;
const REF_H = 1080.0;
const MIN_SCALE = 0.35;
const HIDE_OFFSET = -5000;

const WIDGETS = {
    "battery":   { w: 801,  h: 760, anchor: "top-right",     mx: 0, my: 60, mr: 4, mb: 0, path: "battery/BatteryPopup.qml" },
    "network":   { w: 900,  h: 700, anchor: "top-right",     mx: 0, my: 60, mr: 4, mb: 0, path: "network/NetworkPopup.qml" },
    "volume":    { w: 450,  h: 700, anchor: "top-right",     mx: 0, my: 60, mr: 5, mb: 0, path: "volume/VolumePopup.qml" },
    "clipboard": { w: 800,  h: 700, anchor: "center",        mx: 0, my: 0,  mr: 0, mb: 0, path: "clipboard/ClipboardManager.qml" },
    "monitors":  { w: 800,  h: 650, anchor: "center",        mx: 0, my: 0,  mr: 0, mb: 0, path: "monitors/MonitorPopup.qml" },
    "stewart":   { w: 800,  h: 650, anchor: "center",        mx: 0, my: 0,  mr: 0, mb: 0, path: "stewart/stewart.qml" },
    "focustime": { w: 900,  h: 700, anchor: "center",        mx: 0, my: 0,  mr: 0, mb: 0, path: "focustime/FocusTimePopup.qml" },
    "guide":     { w: 1200, h: 750, anchor: "center",        mx: 0, my: 0,  mr: 0, mb: 0, path: "guide/GuidePopup.qml" },
    "calendar":  { w: 1450, h: 750, anchor: "top-center",    mx: 0, my: 60, mr: 0, mb: 0, path: "calendar/CalendarPopup.qml" },
    "updater":   { w: 950,  h: 850, anchor: "center",        mx: 0, my: 0,  mr: 0, mb: 0, path: "updater/UpdaterPopup.qml" },
    "wallpaper": { w: -1,   h: 650, anchor: "center-fill",   mx: 0, my: 0,  mr: 0, mb: 0, path: "wallpaper/WallpaperPicker.qml" },
    "music":     { w: 700,  h: 650, anchor: "top-left",      mx: 5, my: 60, mr: 0, mb: 0, path: "music/MusicPopup.qml" },
    "movies":    { w: 1370, h: 850, anchor: "bottom-center", mx: 0, my: 0,  mr: 0, mb: 0, path: "movies/MovieWidget.qml" }
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

function getLayout(name, mx, my, mw, mh, userScale) {
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
    
    let rx = 0;
    let ry = 0;

    switch (config.anchor) {
        case "top-left":
            rx = s(config.mx, scale);
            ry = s(config.my, scale);
            break;
        case "top-right":
            rx = mw - finalW - s(config.mr, scale);
            ry = s(config.my, scale);
            break;
        case "top-center":
            rx = Math.floor((mw / 2) - (finalW / 2));
            ry = s(config.my, scale);
            break;
        case "center":
            rx = Math.floor((mw / 2) - (finalW / 2));
            ry = Math.floor((mh / 2) - (finalH / 2));
            break;
        case "center-fill":
            rx = 0;
            ry = Math.floor((mh / 2) - (finalH / 2));
            break;
        case "bottom-center":
            rx = Math.floor((mw / 2) - (finalW / 2));
            ry = mh - finalH - s(config.mb, scale);
            break;
    }

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