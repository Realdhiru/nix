import QtQuick
import QtQuick.Window
import Quickshell
import "WindowRegistry.js" as LayoutMath 

Item {
    id: root
    visible: false

    // Native fallbacks prevent math errors if a widget forgets to pass dimensions
    property real currentWidth: typeof masterWindow !== "undefined" ? masterWindow.width : Screen.width
    property real currentHeight: typeof masterWindow !== "undefined" ? masterWindow.height : Screen.height
    
    // Zero-cost state binding. Inherits directly from the global RAM state.
    property real uiScale: typeof Config !== "undefined" ? Config.uiScale : 1.0

    property real baseScale: LayoutMath.getScale(currentWidth, currentHeight, uiScale)
    
    function s(val) { 
        return LayoutMath.s(val, baseScale); 
    }
}