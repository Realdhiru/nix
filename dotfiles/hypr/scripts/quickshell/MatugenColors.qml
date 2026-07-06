import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string base: "#1e1e2e"
    property string mantle: "#181825"
    property string crust: "#11111b"
    property string text: "#cdd6f4"
    property string subtext0: "#bac2de"
    property string subtext1: "#a6adc8"
    property string surface0: "#313244"
    property string surface1: "#45475a"
    property string surface2: "#585b70"
    property string overlay0: "#6c7086"
    property string overlay1: "#7f849c"
    property string overlay2: "#9399b2"
    property string blue: "#8caaee"
    property string sapphire: "#85c1dc"
    property string peach: "#fab387"
    property string green: "#a6e3a1"
    property string red: "#f38ba8"
    property string mauve: "#cba6f7"
    property string pink: "#f5c2e7"
    property string yellow: "#f9e2af"
    property string maroon: "#eba0ac"
    property string teal: "#94e2d5"

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