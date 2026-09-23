import QtQuick
import QtQuick.Window

Item {
    id: root
    visible: false

    property real currentWidth: Screen.width > 0 ? Screen.width : 1920.0
    property real currentHeight: Screen.height > 0 ? Screen.height : 1080.0
    property real uiScale: 1.0

    readonly property real refW: 1920.0
    readonly property real refH: 1080.0
    readonly property real minScale: 0.35

    property real baseScale: {
        let rw = currentWidth / refW;
        let rh = currentHeight / refH;
        let r = Math.min(rw, rh);
        if (r <= 1.0) {
            return Math.max(minScale, Math.pow(r, 0.85)) * uiScale;
        } else {
            return Math.pow(r, 0.5) * uiScale;
        }
    }

    function s(val) {
        return Math.round(val * baseScale);
    }
}
