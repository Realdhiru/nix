import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property color base: "#1e1e2e"
    property color mantle: "#181825"
    property color crust: "#11111b"
    property color text: "#cdd6f4"
    property color subtext0: "#bac2de"
    property color subtext1: "#a6adc8"
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

    // Dynamic wallpaper lightness indicators for adaptive widget styling
    property bool isLight: false
    property real topLuminance: 50.0

    // Dynamically resolve HOME instead of hardcoding the user profile
    readonly property string colorsFile: Quickshell.env("HOME") + "/.cache/matugen/qs_colors.json"

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

    // Event-driven watcher: unblocks in <10ms whenever qs_colors.json is updated
    Process {
        id: colorWatcher
        command: ["bash", "-c", "$HOME/.config/hypr/scripts/quickshell/watchers/colors_wait.sh && cat $HOME/.cache/matugen/qs_colors.json 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.applyJson(this.text ? this.text.trim() : "");
                colorWatcher.running = false;
                colorWatcher.running = true;
            }
        }
    }

    // Instant load on startup (Frame 0)
    Process {
        id: initialLoader
        command: ["cat", root.colorsFile]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.applyJson(this.text ? this.text.trim() : "");
            }
        }
    }

    // Safety fallback timer (checks every 3s in case inotify missed)
    Timer {
        id: colorPollTimer
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            if (!colorWatcher.running) {
                colorWatcher.running = true;
            }
        }
    }
}
