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

    // Dynamically resolve HOME instead of hardcoding the user profile
    readonly property string colorsFile: Quickshell.env("HOME") + "/.cache/matugen/qs_colors.json"
    
    // Internal state cache to prevent redundant processing
    property string _lastJson: ""

    Process {
        id: colorReader
        command: ["cat", root.colorsFile]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text ? this.text.trim() : "";
                
                // Only parse JSON and trigger property updates if the file content actually changed
                if (txt !== "" && txt !== root._lastJson) {
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
            }
        }
    }

    Timer {
        id: colorPollTimer
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            colorReader.running = false;
            colorReader.running = true;
        }
    }
}