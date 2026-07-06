.pragma library

function getScale(mw, mh, userScale) {
    if (arguments.length === 2) {
        userScale = mh;
        mh = mw * (1080.0 / 1920.0);
    }

    if (mw <= 0 || mh <= 0) return 1.0;
    
    let rw = mw / 1920.0;
    let rh = mh / 1080.0;
    let r = Math.min(rw, rh);
    
    let baseScale = 1.0;
    
    if (r <= 1.0) {
        baseScale = Math.max(0.35, Math.pow(r, 0.85));
    } else {
        baseScale = Math.pow(r, 0.5);
    }
    
    return baseScale * (userScale !== undefined ? userScale : 1.0);
}

function s(val, scale) {
    return Math.round(val * scale);
}

function getLayout(name, mx, my, mw, mh, userScale) {
    let scale = getScale(mw, mh, userScale);
    let t = null;

    // Use a switch block to execute math and allocate an object ONLY for the requested widget
    switch (name) {
        case "battery":
            t = { w: s(801, scale), h: s(760, scale), rx: mw - s(805, scale), ry: s(60, scale), comp: "battery/BatteryPopup.qml" };
            break;
        case "network":
            t = { w: s(900, scale), h: s(700, scale), rx: mw - s(904, scale), ry: s(60, scale), comp: "network/NetworkPopup.qml" };
            break;
        case "volume":
            t = { w: s(450, scale), h: s(700, scale), rx: mw - s(455, scale), ry: s(60, scale), comp: "volume/VolumePopup.qml" };
            break;
        case "clipboard":
            t = { w: s(800, scale), h: s(700, scale), rx: Math.floor((mw/2)-(s(800, scale)/2)), ry: Math.floor((mh/2)-(s(700, scale)/2)), comp: "clipboard/ClipboardManager.qml" };
            break;
        case "monitors":
            t = { w: s(800, scale), h: s(650, scale), rx: Math.floor((mw/2)-(s(800, scale)/2)), ry: Math.floor((mh/2)-(s(650, scale)/2)), comp: "monitors/MonitorPopup.qml" };
            break;
        case "stewart":
            t = { w: s(800, scale), h: s(650, scale), rx: Math.floor((mw/2)-(s(800, scale)/2)), ry: Math.floor((mh/2)-(s(650, scale)/2)), comp: "stewart/stewart.qml" };
            break;
        case "focustime":
            t = { w: s(900, scale), h: s(700, scale), rx: Math.floor((mw/2)-(s(900, scale)/2)), ry: Math.floor((mh/2)-(s(700, scale)/2)), comp: "focustime/FocusTimePopup.qml" };
            break;
        case "guide":
            t = { w: s(1200, scale), h: s(750, scale), rx: Math.floor((mw/2)-(s(1200, scale)/2)), ry: Math.floor((mh/2)-(s(750, scale)/2)), comp: "guide/GuidePopup.qml" };
            break;
        case "calendar":
            t = { w: s(1450, scale), h: s(750, scale), rx: Math.floor((mw/2)-(s(1450, scale)/2)), ry: s(60, scale), comp: "calendar/CalendarPopup.qml" };
            break;
        case "updater":
            t = { w: s(950, scale), h: s(850, scale), rx: Math.floor((mw/2)-(s(950, scale)/2)), ry: Math.floor((mh/2)-(s(850, scale)/2)), comp: "updater/UpdaterPopup.qml" };
            break;
        case "wallpaper":
            t = { w: mw, h: s(650, scale), rx: 0, ry: Math.floor((mh/2)-(s(650, scale)/2)), comp: "wallpaper/WallpaperPicker.qml" };
            break;
        case "music":
            t = { w: s(700, scale), h: s(650, scale), rx: s(5, scale), ry: s(60, scale), comp: "music/MusicPopup.qml" };
            break;
        case "movies":
            t = { w: s(1370, scale), h: s(850, scale), rx: Math.floor((mw / 2) - (s(1370, scale) / 2)), ry: mh - s(850, scale), comp: "movies/MovieWidget.qml" };
            break;
        case "hidden":
            t = { w: 1, h: 1, rx: -5000 - mx, ry: -5000 - my, comp: "" };
            break;
        default:
            return null;
    }

    t.x = mx + t.rx;
    t.y = my + t.ry;
    return t;
}

function getPopupLayout(mw, mh, userScale) {
    if (arguments.length === 2) {
        userScale = mh;
        mh = mw * (1080.0 / 1920.0);
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