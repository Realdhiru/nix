import QtQuick
import QtQuick.Window
import Quickshell
import "WindowRegistry.js" as LayoutMath 

Item {
    id: root
    visible: false

    // Native fallbacks prevent math errors if a widget forgets to pass dimensions
    property real currentWidth: typeof masterWindow !== "undefined" ? masterWindow.width : (typeof Config !== "undefined" ? Config.masterWidth : Screen.width)
    property real currentHeight: typeof masterWindow !== "undefined" ? masterWindow.height : (typeof Config !== "undefined" ? Config.masterHeight : Screen.height)
    
    // Divide by devicePixelRatio to offset Wayland's compositor-level scaling on High-DPI screens
    property real uiScale: (typeof Config !== "undefined" ? Config.uiScale : 1.0) / Math.max(1.0, Screen.devicePixelRatio * 0.75)

    property real baseScale: LayoutMath.getScale(currentWidth, currentHeight, uiScale)
    
    function s(val) { 
        return LayoutMath.s(val, baseScale); 
    }
}