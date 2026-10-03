import QtQuick
import QtQuick.Window
import Quickshell
import "WindowRegistry.js" as LayoutMath 

Item {
    id: root
    visible: false

    property real currentWidth: Screen.width
    property real currentHeight: Screen.height
    property real uiScale: 1.0

    property real baseScale: LayoutMath.getScale(currentWidth, currentHeight, uiScale)

    function s(val) {
        return LayoutMath.s(val, baseScale);
    }
}