import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property color base: "#1e1e2e"
    property color mantle: "#181825"
    property color crust: "#11111b"
    property color text: "#EDE6DC"
    property color subtext0: "#C9BFB5"
    property color subtext1: "#A89F95"
    property color surface0: "#313244"
    property color surface1: "#45475a"
    property color surface2: "#585b70"
    property color overlay0: "#6c7086"
    property color overlay1: "#7f849c"
    property color overlay2: "#9399b2"
    property color blue: "#8caaee"
    property color sapphire: "#85c1dc"
    property color peach: "#fab387"
    property color green: "#a6e3a1"
    property color red: "#f38ba8"
    property color mauve: "#cba6f7"
    property color pink: "#f5c2e7"
    property color yellow: "#f9e2af"
    property color maroon: "#eba0ac"
    property color teal: "#94e2d5"
    property color lavender: "#b4befe"
    property color primary: "#cba6f7"

    // Dynamic wallpaper lightness indicators for adaptive widget styling
    property bool isLight: false
    property real topLuminance: 50.0

    // Dynamically resolve HOME instead of hardcoding the user profile
    readonly property string colorsFile: Quickshell.env("HOME") + "/.cache/theme/colors.json"

    // Internal state cache to prevent redundant processing
    property string _lastJson: ""

    function applyJson(txt) {
        if (!txt || txt === "" || txt === "{}" || txt === root._lastJson) return;
        try {
            let data = JSON.parse(txt);
            for (let key in data) {
                if (root.hasOwnProperty(key) && key !== "colorsFile" && key !== "_lastJson") {
                    root[key] = data[key];
                }
            }
            root._lastJson = txt;
        } catch(e) {}
    }

    function reload() {
        root._lastJson = "";
        fileView.reload();
    }

    // Instant C++ native file loader & live inotify watcher (0ms startup, zero subprocess overhead)
    FileView {
        id: fileView
        path: root.colorsFile
        watchChanges: true
        onLoadedChanged: root.applyJson(fileView.text())
        onTextChanged: root.applyJson(fileView.text())
        onFileChanged: {
            root._lastJson = "";
            fileView.reload();
        }
    }

    Component.onCompleted: {
        root.applyJson(fileView.text());
    }
}
