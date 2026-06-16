import QtQuick
import Quickshell.Io

QtObject {
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

    Process {
        running: true
        command: ["cat", "/home/realdhiru/.cache/matugen/qs_colors.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try {
                        let data = JSON.parse(txt);
                        for (let key in data) {
                            if (root.hasOwnProperty(key)) {
                                root[key] = data[key];
                            }
                        }
                    } catch(e) {}
                }
            }
        }
    }
}
