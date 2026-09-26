import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root
    focus: true

    property real layoutWidth: 580
    property real layoutHeight: 530
    width: layoutWidth
    height: layoutHeight

    Scaler {
        id: scaler
        currentWidth: Screen.width
    }
    function s(val) { return scaler.s(val); }

    Theme { id: _theme }
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay0: _theme.overlay0
    readonly property color primary: _theme.primary
    readonly property color peach: _theme.peach
    readonly property color yellow: _theme.yellow

    // State properties
    property int currentTemp: 6500
    property int currentGamma: 100
    property int currentSat: 100
    property bool isActive: false

    property string stateFile: Quickshell.env("HOME") + "/.cache/hyprsunset_state.json"
    property string satShaderFile: Quickshell.env("HOME") + "/.cache/screen_saturation.frag"

    Process {
        id: stateReader
        command: ["bash", "-c", `if [ -f "${root.stateFile}" ]; then cat "${root.stateFile}"; else echo '{"temp": 6500, "gamma": 100, "sat": 100, "active": false}'; fi`]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(this.text.trim());
                    if (d.temp !== undefined) root.currentTemp = d.temp;
                    if (d.gamma !== undefined) root.currentGamma = d.gamma;
                    if (d.sat !== undefined) root.currentSat = d.sat;
                    if (d.active !== undefined) root.isActive = d.active;
                } catch(e) {}
            }
        }
    }

    // Backend Synchronizer with auto-spawning daemon & cleanup on default
    function applyBackend(t, g, s) {
        root.currentTemp = Math.round(t);
        root.currentGamma = Math.round(g);
        root.currentSat = Math.round(s);

        let isDefault = (root.currentTemp === 6500 && root.currentGamma === 100 && root.currentSat === 100);
        root.isActive = !isDefault;

        if (isDefault) {
            root.resetAll();
            return;
        }

        let satFloat = (root.currentSat / 100.0).toFixed(2);

        let script = `
            # 1. Hardware CTM (hyprsunset)
            if [ "${root.currentTemp}" -ne 6500 ] || [ "${root.currentGamma}" -ne 100 ]; then
                if ! pgrep -x hyprsunset >/dev/null 2>&1; then
                    hyprsunset -t ${root.currentTemp} -g ${root.currentGamma} >/dev/null 2>&1 &
                    sleep 0.08
                fi
                hyprctl hyprsunset temperature ${root.currentTemp} >/dev/null 2>&1 || true
                hyprctl hyprsunset gamma ${root.currentGamma} >/dev/null 2>&1 || true
            else
                if pgrep -x hyprsunset >/dev/null 2>&1; then
                    hyprctl hyprsunset identity >/dev/null 2>&1 || true
                    pkill -x hyprsunset >/dev/null 2>&1 || true
                fi
            fi

            # 2. Saturation / Grayscale Shader
            if [ "${root.currentSat}" -eq 100 ]; then
                hyprctl eval "hl.config({ decoration = { screen_shader = '' } })" >/dev/null 2>&1 || true
                rm -f "${root.satShaderFile}"
            else
                cat <<'EOF' > "${root.satShaderFile}"
#version 300 es
precision highp float;
in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
void main() {
    vec4 pix = texture(tex, v_texcoord);
    float gray = dot(pix.rgb, vec3(0.299, 0.587, 0.114));
    pix.rgb = mix(vec3(gray), pix.rgb, ${satFloat});
    fragColor = pix;
}
EOF
                hyprctl eval "hl.config({ decoration = { screen_shader = '${root.satShaderFile}' } })" >/dev/null 2>&1 || true
            fi

            # 3. Save persistent state
            echo '{"temp": ${root.currentTemp}, "gamma": ${root.currentGamma}, "sat": ${root.currentSat}, "active": true}' > "${root.stateFile}"
        `;

        Quickshell.execDetached(["bash", "-c", script]);
    }

    function resetAll() {
        root.currentTemp = 6500;
        root.currentGamma = 100;
        root.currentSat = 100;
        root.isActive = false;

        let script = `
            if pgrep -x hyprsunset >/dev/null 2>&1; then
                hyprctl hyprsunset identity >/dev/null 2>&1 || true
                hyprctl hyprsunset gamma 100 >/dev/null 2>&1 || true
                pkill -x hyprsunset >/dev/null 2>&1 || true
            fi
            hyprctl eval "hl.config({ decoration = { screen_shader = '' } })" >/dev/null 2>&1 || true
            rm -f "${root.satShaderFile}"
            echo '{"temp": 6500, "gamma": 100, "sat": 100, "active": false}' > "${root.stateFile}"
        `;

        Quickshell.execDetached(["bash", "-c", script]);
    }

    Rectangle {
        id: bgCard
        anchors.fill: parent
        radius: root.s(22)
        color: Qt.rgba(root.base.r, root.base.g, root.base.b, Config.effectivePopupOpacity)
        border.color: Config.borderWidth > 0 ? root.surface0 : "transparent"
        border.width: Config.borderWidth

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(22)
            spacing: root.s(14)

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(12)

                Rectangle {
                    width: root.s(42)
                    height: root.s(42)
                    radius: root.s(12)
                    color: root.isActive ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.22) : Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.g, 0.4)

                    Text {
                        anchors.centerIn: parent
                        text: root.isActive ? "󱩌" : "󰌵"
                        font.family: "Iosevka Nerd Font, JetBrains Mono"
                        font.pixelSize: root.s(22)
                        color: root.isActive ? root.primary : root.subtext0
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: root.s(2)

                    Text {
                        text: "Display & Night Light"
                        font.family: "JetBrains Mono"
                        font.pixelSize: root.s(16)
                        font.weight: Font.Bold
                        color: root.text
                    }

                    Text {
                        text: root.isActive ? `${root.currentTemp}K  •  ${root.currentGamma}% Gamma  •  ${root.currentSat}% Saturation` : "Default (6500K • 100% Gamma • 100% Color)"
                        font.family: "JetBrains Mono"
                        font.pixelSize: root.s(11)
                        color: root.isActive ? root.primary : root.subtext0
                    }
                }

                // Reset All Button
                Rectangle {
                    width: resetText.implicitWidth + root.s(24)
                    height: root.s(32)
                    radius: root.s(10)
                    color: resetMa.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25) : Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.5)
                    border.width: 1
                    border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.3)

                    Text {
                        id: resetText
                        anchors.centerIn: parent
                        text: "Reset All"
                        font.family: "JetBrains Mono"
                        font.pixelSize: root.s(12)
                        font.weight: Font.Bold
                        color: resetMa.containsMouse ? root.primary : root.text
                    }

                    MouseArea {
                        id: resetMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetAll()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.4)
            }

            // 1. TEMPERATURE (Decreasing from 6500K on Left to 1000K on Right)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.s(6)

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Color Temperature (Warmth)"
                        font.family: "JetBrains Mono"
                        font.pixelSize: root.s(13)
                        font.weight: Font.DemiBold
                        color: root.text
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: `${root.currentTemp}K`
                        font.family: "JetBrains Mono"
                        font.pixelSize: root.s(13)
                        font.weight: Font.Bold
                        color: root.primary
                    }
                }

                Slider {
                    id: tempSlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(22)
                    from: 6500
                    to: 1000
                    stepSize: 50
                    value: root.currentTemp

                    onMoved: root.applyBackend(value, root.currentGamma, root.currentSat)

                    background: Rectangle {
                        x: tempSlider.leftPadding
                        y: tempSlider.topPadding + (tempSlider.availableHeight - height) / 2
                        width: tempSlider.availableWidth
                        height: root.s(8)
                        radius: root.s(4)
                        color: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.6)

                        Rectangle {
                            width: tempSlider.visualPosition * parent.width
                            height: parent.height
                            radius: root.s(4)
                            color: root.primary
                        }
                    }

                    handle: Rectangle {
                        x: tempSlider.leftPadding + tempSlider.visualPosition * (tempSlider.availableWidth - width)
                        y: tempSlider.topPadding + (tempSlider.availableHeight - height) / 2
                        width: root.s(18)
                        height: root.s(18)
                        radius: root.s(9)
                        color: tempSlider.pressed ? root.primary : root.text
                        border.width: root.s(2)
                        border.color: root.crust
                    }
                }

                // Preset Buttons aligned directly with the slider positions
                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.s(6)

                    Repeater {
                        model: [
                            { name: "Day (6500K)", val: 6500 },
                            { name: "Soft (4500K)", val: 4500 },
                            { name: "Warm (3000K)", val: 3000 },
                            { name: "Deep (1500K)", val: 1500 }
                        ]

                        Rectangle {
                            Layout.fillWidth: true
                            height: root.s(26)
                            radius: root.s(7)
                            color: (root.currentTemp === modelData.val)
                                ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
                                : (pMa.containsMouse ? Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.5) : Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.4))
                            border.width: 1
                            border.color: (root.currentTemp === modelData.val) ? root.primary : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.s(10)
                                font.weight: (root.currentTemp === modelData.val) ? Font.Bold : Font.Normal
                                color: (root.currentTemp === modelData.val) ? root.primary : root.text
                            }

                            MouseArea {
                                id: pMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.applyBackend(modelData.val, root.currentGamma, root.currentSat)
                            }
                        }
                    }
                }
            }

            // 2. GAMMA (60% to 140%, Default 100% in Exact Middle)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.s(6)

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Display Gamma (Brightness)"
                        font.family: "JetBrains Mono"
                        font.pixelSize: root.s(13)
                        font.weight: Font.DemiBold
                        color: root.text
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: `${root.currentGamma}%`
                        font.family: "JetBrains Mono"
                        font.pixelSize: root.s(13)
                        font.weight: Font.Bold
                        color: root.primary
                    }
                }

                Slider {
                    id: gammaSlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(22)
                    from: 50
                    to: 100
                    stepSize: 1
                    value: root.currentGamma

                    onMoved: root.applyBackend(root.currentTemp, value, root.currentSat)

                    background: Rectangle {
                        x: gammaSlider.leftPadding
                        y: gammaSlider.topPadding + (gammaSlider.availableHeight - height) / 2
                        width: gammaSlider.availableWidth
                        height: root.s(8)
                        radius: root.s(4)
                        color: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.6)

                        Rectangle {
                            width: gammaSlider.visualPosition * parent.width
                            height: parent.height
                            radius: root.s(4)
                            color: root.primary
                        }
                    }

                    handle: Rectangle {
                        x: gammaSlider.leftPadding + gammaSlider.visualPosition * (gammaSlider.availableWidth - width)
                        y: gammaSlider.topPadding + (gammaSlider.availableHeight - height) / 2
                        width: root.s(18)
                        height: root.s(18)
                        radius: root.s(9)
                        color: gammaSlider.pressed ? root.primary : root.text
                        border.width: root.s(2)
                        border.color: root.crust
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.s(6)

                    Repeater {
                        model: [
                            { name: "Dim (60%)", val: 60 },
                            { name: "Soft (80%)", val: 80 },
                            { name: "Default (100%)", val: 100 }
                        ]

                        Rectangle {
                            Layout.fillWidth: true
                            height: root.s(26)
                            radius: root.s(7)
                            color: (root.currentGamma === modelData.val)
                                ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
                                : (gMa.containsMouse ? Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.5) : Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.4))
                            border.width: 1
                            border.color: (root.currentGamma === modelData.val) ? root.primary : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.s(10)
                                font.weight: (root.currentGamma === modelData.val) ? Font.Bold : Font.Normal
                                color: (root.currentGamma === modelData.val) ? root.primary : root.text
                            }

                            MouseArea {
                                id: gMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.applyBackend(root.currentTemp, modelData.val, root.currentSat)
                            }
                        }
                    }
                }
            }

            // 3. SATURATION / GRAYSCALE (0% Monochrome to 100% Full Color)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.s(6)

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Saturation & Grayscale"
                        font.family: "JetBrains Mono"
                        font.pixelSize: root.s(13)
                        font.weight: Font.DemiBold
                        color: root.text
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: `${root.currentSat}%`
                        font.family: "JetBrains Mono"
                        font.pixelSize: root.s(13)
                        font.weight: Font.Bold
                        color: root.primary
                    }
                }

                Slider {
                    id: satSlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(22)
                    from: 0
                    to: 100
                    stepSize: 1
                    value: root.currentSat

                    onMoved: root.applyBackend(root.currentTemp, root.currentGamma, value)

                    background: Rectangle {
                        x: satSlider.leftPadding
                        y: satSlider.topPadding + (satSlider.availableHeight - height) / 2
                        width: satSlider.availableWidth
                        height: root.s(8)
                        radius: root.s(4)
                        color: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.6)

                        Rectangle {
                            width: satSlider.visualPosition * parent.width
                            height: parent.height
                            radius: root.s(4)
                            color: root.primary
                        }
                    }

                    handle: Rectangle {
                        x: satSlider.leftPadding + satSlider.visualPosition * (satSlider.availableWidth - width)
                        y: satSlider.topPadding + (satSlider.availableHeight - height) / 2
                        width: root.s(18)
                        height: root.s(18)
                        radius: root.s(9)
                        color: satSlider.pressed ? root.primary : root.text
                        border.width: root.s(2)
                        border.color: root.crust
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.s(6)

                    Repeater {
                        model: [
                            { name: "Grayscale (0%)", val: 0 },
                            { name: "Muted (50%)", val: 50 },
                            { name: "Full Color (100%)", val: 100 }
                        ]

                        Rectangle {
                            Layout.fillWidth: true
                            height: root.s(26)
                            radius: root.s(7)
                            color: (root.currentSat === modelData.val)
                                ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
                                : (sMa.containsMouse ? Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.5) : Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.4))
                            border.width: 1
                            border.color: (root.currentSat === modelData.val) ? root.primary : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.s(10)
                                font.weight: (root.currentSat === modelData.val) ? Font.Bold : Font.Normal
                                color: (root.currentSat === modelData.val) ? root.primary : root.text
                            }

                            MouseArea {
                                id: sMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.applyBackend(root.currentTemp, root.currentGamma, modelData.val)
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
