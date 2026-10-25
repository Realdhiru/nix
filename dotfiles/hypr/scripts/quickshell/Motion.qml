pragma Singleton
import QtQuick

QtObject {
    readonly property int enterMs: 240
    readonly property int exitMs: 160
    readonly property int moveMs: 220
    readonly property int fadeMs: 140

    readonly property int enterEasing: Easing.OutQuart
    readonly property int exitEasing: Easing.InQuad
    readonly property int moveEasing: Easing.OutQuint
    readonly property int fadeEasing: Easing.InOutQuad

    readonly property int holdMs: 700
    readonly property int holdEasing: Easing.Linear

    readonly property real marqueeMsPerPx: 30
    readonly property int marqueePauseMs: 2500
}

