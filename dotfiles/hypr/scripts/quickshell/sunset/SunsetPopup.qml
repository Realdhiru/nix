import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root
    focus: true

    property real layoutWidth: 320
    property real layoutHeight: 390
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
    readonly property color yellow: _theme.yellow

    // State properties
    property int currentTemp: 6500
    property int currentGamma: 100
    property int currentSat: 100
    property int currentGrain: 0
    property int currentCrt: 0
    property bool isActive: false
    property int selectedControl: 0 // 0 = Temp, 1 = Gamma, 2 = Saturation, 3 = Grain, 4 = CRT

    Component.onCompleted: root.forceActiveFocus()

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
            root.selectedControl = (root.selectedControl + 1) % 5;
            event.accepted = true;
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
            root.selectedControl = (root.selectedControl + 4) % 5;
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            if (root.selectedControl === 0) {
                let nextTemp = Math.min(6500, root.currentTemp + 250);
                root.applyBackend(nextTemp, root.currentGamma, root.currentSat, root.currentGrain, root.currentCrt);
            } else if (root.selectedControl === 1) {
                let nextGamma = Math.max(50, root.currentGamma - 5);
                root.applyBackend(root.currentTemp, nextGamma, root.currentSat, root.currentGrain, root.currentCrt);
            } else if (root.selectedControl === 2) {
                let nextSat = Math.max(0, root.currentSat - 5);
                root.applyBackend(root.currentTemp, root.currentGamma, nextSat, root.currentGrain, root.currentCrt);
            } else if (root.selectedControl === 3) {
                let nextGrain = Math.max(0, root.currentGrain - 5);
                root.applyBackend(root.currentTemp, root.currentGamma, root.currentSat, nextGrain, root.currentCrt);
            } else if (root.selectedControl === 4) {
                let nextCrt = Math.max(0, root.currentCrt - 5);
                root.applyBackend(root.currentTemp, root.currentGamma, root.currentSat, root.currentGrain, nextCrt);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            if (root.selectedControl === 0) {
                let nextTemp = Math.max(1000, root.currentTemp - 250);
                root.applyBackend(nextTemp, root.currentGamma, root.currentSat, root.currentGrain, root.currentCrt);
            } else if (root.selectedControl === 1) {
                let nextGamma = Math.min(100, root.currentGamma + 5);
                root.applyBackend(root.currentTemp, nextGamma, root.currentSat, root.currentGrain, root.currentCrt);
            } else if (root.selectedControl === 2) {
                let nextSat = Math.min(100, root.currentSat + 5);
                root.applyBackend(root.currentTemp, root.currentGamma, nextSat, root.currentGrain, root.currentCrt);
            } else if (root.selectedControl === 3) {
                let nextGrain = Math.min(100, root.currentGrain + 5);
                root.applyBackend(root.currentTemp, root.currentGamma, root.currentSat, nextGrain, root.currentCrt);
            } else if (root.selectedControl === 4) {
                let nextCrt = Math.min(100, root.currentCrt + 5);
                root.applyBackend(root.currentTemp, root.currentGamma, root.currentSat, root.currentGrain, nextCrt);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_1) {
            if (root.selectedControl === 0) root.applyBackend(6500, root.currentGamma, root.currentSat, root.currentGrain, root.currentCrt);
            else if (root.selectedControl === 1) root.applyBackend(root.currentTemp, 50, root.currentSat, root.currentGrain, root.currentCrt);
            else if (root.selectedControl === 2) root.applyBackend(root.currentTemp, root.currentGamma, 0, root.currentGrain, root.currentCrt);
            else if (root.selectedControl === 3) root.applyBackend(root.currentTemp, root.currentGamma, root.currentSat, 0, root.currentCrt);
            else if (root.selectedControl === 4) root.applyBackend(root.currentTemp, root.currentGamma, root.currentSat, root.currentGrain, 0);
            event.accepted = true;
        } else if (event.key === Qt.Key_2) {
            if (root.selectedControl === 0) root.applyBackend(4500, root.currentGamma, root.currentSat, root.currentGrain, root.currentCrt);
            else if (root.selectedControl === 1) root.applyBackend(root.currentTemp, 70, root.currentSat, root.currentGrain, root.currentCrt);
            else if (root.selectedControl === 2) root.applyBackend(root.currentTemp, root.currentGamma, 33, root.currentGrain, root.currentCrt);
            else if (root.selectedControl === 3) root.applyBackend(root.currentTemp, root.currentGamma, root.currentSat, 25, root.currentCrt);
            else if (root.selectedControl === 4) root.applyBackend(root.currentTemp, root.currentGamma, root.currentSat, root.currentGrain, 25);
            event.accepted = true;
        } else if (event.key === Qt.Key_3) {
            if (root.selectedControl === 0) root.applyBackend(3000, root.currentGamma, root.currentSat, root.currentGrain, root.currentCrt);
            else if (root.selectedControl === 1) root.applyBackend(root.currentTemp, 85, root.currentSat, root.currentGrain, root.currentCrt);
            else if (root.selectedControl === 2) root.applyBackend(root.currentTemp, root.currentGamma, 66, root.currentGrain, root.currentCrt);
            else if (root.selectedControl === 3) root.applyBackend(root.currentTemp, root.currentGamma, root.currentSat, 50, root.currentCrt);
            else if (root.selectedControl === 4) root.applyBackend(root.currentTemp, root.currentGamma, root.currentSat, root.currentGrain, 50);
            event.accepted = true;
        } else if (event.key === Qt.Key_4) {
            if (root.selectedControl === 0) root.applyBackend(1500, root.currentGamma, root.currentSat, root.currentGrain, root.currentCrt);
            else if (root.selectedControl === 1) root.applyBackend(root.currentTemp, 100, root.currentSat, root.currentGrain, root.currentCrt);
            else if (root.selectedControl === 2) root.applyBackend(root.currentTemp, root.currentGamma, 100, root.currentGrain, root.currentCrt);
            else if (root.selectedControl === 3) root.applyBackend(root.currentTemp, root.currentGamma, root.currentSat, 100, root.currentCrt);
            else if (root.selectedControl === 4) root.applyBackend(root.currentTemp, root.currentGamma, root.currentSat, root.currentGrain, 100);
            event.accepted = true;
        } else if (event.key === Qt.Key_R || event.key === Qt.Key_0) {
            root.resetAll();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
            event.accepted = true;
        }
    }

    property string stateFile: Quickshell.env("HOME") + "/.cache/quickshell/state.json"
    property string shaderFile: Quickshell.env("HOME") + "/.cache/screen_shader.frag"
    property string satShaderFile: Quickshell.env("HOME") + "/.cache/screen_saturation.frag"

    Timer {
        id: applyTimer
        interval: 50
        repeat: false
        onTriggered: root.doApplyBackend()
    }

    Process {
        id: stateReader
        command: ["bash", "-c", `if [ -f "${root.stateFile}" ]; then cat "${root.stateFile}"; else echo '{"sunset": {"temp": 6500, "gamma": 100, "sat": 100, "grain": 0, "crt": 0, "active": false}}'; fi`]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let full = JSON.parse(this.text.trim());
                    let d = full.sunset || full;
                    if (d.temp !== undefined) root.currentTemp = d.temp;
                    if (d.gamma !== undefined) root.currentGamma = d.gamma;
                    if (d.sat !== undefined) root.currentSat = d.sat;
                    if (d.grain !== undefined) root.currentGrain = d.grain;
                    if (d.crt !== undefined) root.currentCrt = d.crt;
                    if (d.active !== undefined) root.isActive = d.active;
                } catch(e) {}
            }
        }
    }

    // Backend Synchronizer with debounced slider updates & auto-spawning daemon & cleanup on default
    function applyBackend(t, g, s, gr, crt) {
        if (t !== undefined) root.currentTemp = Math.round(t);
        if (g !== undefined) root.currentGamma = Math.round(g);
        if (s !== undefined) root.currentSat = Math.round(s);
        if (gr !== undefined) root.currentGrain = Math.round(gr);
        if (crt !== undefined) root.currentCrt = Math.round(crt);

        let isDefault = (root.currentTemp === 6500 && root.currentGamma === 100 && root.currentSat === 100 && root.currentGrain === 0 && root.currentCrt === 0);
        root.isActive = !isDefault;

        if (isDefault) {
            root.resetAll();
            return;
        }

        applyTimer.restart();
    }

    function doApplyBackend() {
        let isDefault = (root.currentTemp === 6500 && root.currentGamma === 100 && root.currentSat === 100 && root.currentGrain === 0 && root.currentCrt === 0);
        if (isDefault) {
            root.resetAll();
            return;
        }

        let satFloat = (root.currentSat / 100.0).toFixed(3);
        let grainFloat = (root.currentGrain / 100.0 * 1.5).toFixed(3);
        let crtFloat = (root.currentCrt / 100.0).toFixed(3);

        let needsShader = (root.currentSat !== 100 || root.currentGrain > 0 || root.currentCrt > 0);

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

            # 2. Dynamic Shader Pipeline (Sat / Grain / CRT)
            rm -f "${root.satShaderFile}"
            if [ "${needsShader ? 1 : 0}" -eq 0 ]; then
                hyprctl eval "hl.config({ decoration = { screen_shader = '' } })" >/dev/null 2>&1 || true
                rm -f "${root.shaderFile}"
            else
                cat <<'EOF' > "${root.shaderFile}"
#version 300 es
#define HYPRLAND_HOOK debug:damage_tracking 1
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

float paper_grain(vec2 uv){
    mediump float g = fract(sin(dot(uv * 800.0, vec2(12.9898,78.233))) * 43758.5453);
    return g * 0.12 - 0.06;
}

vec2 crtCurve(vec2 uv, float strength){
    if (strength <= 0.0) return uv;
    vec2 p = uv * 2.0 - 1.0;
    vec2 off = abs(p.yx) / 4.8;
    p += (p * off * off) * strength;
    return p * 0.5 + 0.5;
}

void main(){
    vec2 uv0 = v_texcoord;

    float crtStrength = ${crtFloat};
    vec2 uv = crtCurve(uv0, crtStrength);

    // Zoom fix for CRT corners (compensates CRT empty corners)
    float ZOOM = mix(1.0, 1.015, crtStrength);
    uv = (uv - 0.5) / ZOOM + 0.5;

    vec4 pix = texture(tex, clamp(uv, 0.0, 1.0));
    vec3 col = pix.rgb;

    // Saturation pass
    float sat = ${satFloat};
    if (sat != 1.0) {
        float gray = dot(col, vec3(0.299, 0.587, 0.114));
        col = mix(vec3(gray), col, sat);
    }

    // Paper grain pass
    float grainVal = ${grainFloat};
    if (grainVal > 0.0) {
        float g = paper_grain(uv0);
        col = clamp(col + g * grainVal, 0.0, 1.0);
    }

    fragColor = vec4(col, pix.a);
}
EOF
                hyprctl eval "hl.config({ decoration = { screen_shader = '${root.shaderFile}' } })" >/dev/null 2>&1 || true
            fi

            # 3. Save persistent state in canonical state.json
            bash "${Quickshell.env("HOME")}/.config/hypr/scripts/quickshell/state_ctl.sh" sunset ${root.currentTemp} ${root.currentGamma} ${root.currentSat} ${root.currentGrain} ${root.currentCrt} true
        `;

        Quickshell.execDetached(["bash", "-c", script]);
    }

    function resetAll() {
        applyTimer.stop();
        root.currentTemp = 6500;
        root.currentGamma = 100;
        root.currentSat = 100;
        root.currentGrain = 0;
        root.currentCrt = 0;
        root.isActive = false;

        let script = `
            if pgrep -x hyprsunset >/dev/null 2>&1; then
                hyprctl hyprsunset identity >/dev/null 2>&1 || true
                hyprctl hyprsunset gamma 100 >/dev/null 2>&1 || true
                pkill -x hyprsunset >/dev/null 2>&1 || true
            fi
            hyprctl eval "hl.config({ decoration = { screen_shader = '' } })" >/dev/null 2>&1 || true
            rm -f "${root.shaderFile}" "${root.satShaderFile}"
            bash "${Quickshell.env("HOME")}/.config/hypr/scripts/quickshell/state_ctl.sh" sunset 6500 100 100 0 0 false
        `;

        Quickshell.execDetached(["bash", "-c", script]);
    }

    // Outer Glass Container with Anti-Bleed Frost Layering
    Rectangle {
        id: bgCard
        anchors.fill: parent
        radius: root.s(20)
        color: Qt.rgba(root.base.r, root.base.g, root.base.b, Config.effectivePopupOpacity)
        border.color: Config.borderWidth > 0 ? Qt.rgba(255, 255, 255, Config.borderOpacity) : Qt.rgba(255, 255, 255, Config.glassSpecular)
        border.width: Math.max(1, Config.borderWidth)
        clip: true

        // Subtle anti-bleed base layer
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(root.crust.r, root.crust.g, root.crust.b, Config.antiBleedOpacity)
            z: -1
        }


        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(12)
            spacing: root.s(8)

            // 1. TEMPERATURE CARD
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.s(64)
                radius: root.s(12)
                color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.38)
                border.width: 1
                border.color: root.selectedControl === 0 ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.50) : Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.25)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.s(10)
                    spacing: root.s(6)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.s(8)

                        Rectangle {
                            width: root.s(6)
                            height: root.s(6)
                            radius: root.s(3)
                            color: root.selectedControl === 0 ? root.primary : "transparent"
                            border.color: root.selectedControl === 0 ? root.primary : Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.4)
                            border.width: 1
                        }

                        Text {
                            text: "Color Temperature (Warmth)"
                            font.family: "JetBrains Mono"
                            font.pixelSize: root.s(12)
                            font.weight: Font.DemiBold
                            color: root.selectedControl === 0 ? root.primary : root.text
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: tempValText.implicitWidth + root.s(12)
                            height: root.s(18)
                            radius: root.s(5)
                            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.18)

                            Text {
                                id: tempValText
                                anchors.centerIn: parent
                                text: `${root.currentTemp}K`
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.s(11)
                                font.weight: Font.Bold
                                color: root.primary
                            }
                        }
                    }

                    Slider {
                        id: tempSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.s(20)
                        from: 6500
                        to: 1000
                        stepSize: 50
                        value: root.currentTemp

                        onMoved: root.applyBackend(value, root.currentGamma, root.currentSat, root.currentGrain, root.currentCrt)

                        background: Rectangle {
                            x: tempSlider.leftPadding
                            y: tempSlider.topPadding + (tempSlider.availableHeight - height) / 2
                            width: tempSlider.availableWidth
                            height: root.s(6)
                            radius: root.s(3)
                            color: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.6)

                            Rectangle {
                                width: tempSlider.visualPosition * parent.width
                                height: parent.height
                                radius: root.s(3)
                                color: root.primary
                            }
                        }

                        handle: Rectangle {
                            x: tempSlider.leftPadding + tempSlider.visualPosition * (tempSlider.availableWidth - width)
                            y: tempSlider.topPadding + (tempSlider.availableHeight - height) / 2
                            width: root.s(16)
                            height: root.s(16)
                            radius: root.s(8)
                            color: tempSlider.pressed ? root.primary : root.text
                            border.width: root.selectedControl === 0 ? root.s(2) : root.s(1)
                            border.color: root.selectedControl === 0 ? root.primary : root.crust
                        }
                    }
                }
            }

            // 2. GAMMA CARD
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.s(64)
                radius: root.s(12)
                color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.38)
                border.width: 1
                border.color: root.selectedControl === 1 ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.50) : Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.25)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.s(10)
                    spacing: root.s(6)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.s(8)

                        Rectangle {
                            width: root.s(6)
                            height: root.s(6)
                            radius: root.s(3)
                            color: root.selectedControl === 1 ? root.primary : "transparent"
                            border.color: root.selectedControl === 1 ? root.primary : Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.4)
                            border.width: 1
                        }

                        Text {
                            text: "Display Gamma (Brightness)"
                            font.family: "JetBrains Mono"
                            font.pixelSize: root.s(12)
                            font.weight: Font.DemiBold
                            color: root.selectedControl === 1 ? root.primary : root.text
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: gammaValText.implicitWidth + root.s(12)
                            height: root.s(18)
                            radius: root.s(5)
                            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.18)

                            Text {
                                id: gammaValText
                                anchors.centerIn: parent
                                text: `${root.currentGamma}%`
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.s(11)
                                font.weight: Font.Bold
                                color: root.primary
                            }
                        }
                    }

                    Slider {
                        id: gammaSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.s(20)
                        from: 50
                        to: 100
                        stepSize: 1
                        value: root.currentGamma

                        onMoved: root.applyBackend(root.currentTemp, value, root.currentSat, root.currentGrain, root.currentCrt)

                        background: Rectangle {
                            x: gammaSlider.leftPadding
                            y: gammaSlider.topPadding + (gammaSlider.availableHeight - height) / 2
                            width: gammaSlider.availableWidth
                            height: root.s(6)
                            radius: root.s(3)
                            color: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.6)

                            Rectangle {
                                width: gammaSlider.visualPosition * parent.width
                                height: parent.height
                                radius: root.s(3)
                                color: root.primary
                            }
                        }

                        handle: Rectangle {
                            x: gammaSlider.leftPadding + gammaSlider.visualPosition * (gammaSlider.availableWidth - width)
                            y: gammaSlider.topPadding + (gammaSlider.availableHeight - height) / 2
                            width: root.s(16)
                            height: root.s(16)
                            radius: root.s(8)
                            color: gammaSlider.pressed ? root.primary : root.text
                            border.width: root.selectedControl === 1 ? root.s(2) : root.s(1)
                            border.color: root.selectedControl === 1 ? root.primary : root.crust
                        }
                    }
                }
            }

            // 3. SATURATION / GRAYSCALE CARD
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.s(64)
                radius: root.s(12)
                color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.38)
                border.width: 1
                border.color: root.selectedControl === 2 ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.50) : Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.25)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.s(10)
                    spacing: root.s(6)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.s(8)

                        Rectangle {
                            width: root.s(6)
                            height: root.s(6)
                            radius: root.s(3)
                            color: root.selectedControl === 2 ? root.primary : "transparent"
                            border.color: root.selectedControl === 2 ? root.primary : Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.4)
                            border.width: 1
                        }

                        Text {
                            text: "Saturation & Grayscale"
                            font.family: "JetBrains Mono"
                            font.pixelSize: root.s(12)
                            font.weight: Font.DemiBold
                            color: root.selectedControl === 2 ? root.primary : root.text
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: satValText.implicitWidth + root.s(12)
                            height: root.s(18)
                            radius: root.s(5)
                            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.18)

                            Text {
                                id: satValText
                                anchors.centerIn: parent
                                text: `${root.currentSat}%`
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.s(11)
                                font.weight: Font.Bold
                                color: root.primary
                            }
                        }
                    }

                    Slider {
                        id: satSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.s(20)
                        from: 0
                        to: 100
                        stepSize: 1
                        value: root.currentSat

                        onMoved: root.applyBackend(root.currentTemp, root.currentGamma, value, root.currentGrain, root.currentCrt)

                        background: Rectangle {
                            x: satSlider.leftPadding
                            y: satSlider.topPadding + (satSlider.availableHeight - height) / 2
                            width: satSlider.availableWidth
                            height: root.s(6)
                            radius: root.s(3)
                            color: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.6)

                            Rectangle {
                                width: satSlider.visualPosition * parent.width
                                height: parent.height
                                radius: root.s(3)
                                color: root.primary
                            }
                        }

                        handle: Rectangle {
                            x: satSlider.leftPadding + satSlider.visualPosition * (satSlider.availableWidth - width)
                            y: satSlider.topPadding + (satSlider.availableHeight - height) / 2
                            width: root.s(16)
                            height: root.s(16)
                            radius: root.s(8)
                            color: satSlider.pressed ? root.primary : root.text
                            border.width: root.selectedControl === 2 ? root.s(2) : root.s(1)
                            border.color: root.selectedControl === 2 ? root.primary : root.crust
                        }
                    }
                }
            }

            // 4. PAPER GRAIN CARD
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.s(64)
                radius: root.s(12)
                color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.38)
                border.width: 1
                border.color: root.selectedControl === 3 ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.50) : Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.25)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.s(10)
                    spacing: root.s(6)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.s(8)

                        Rectangle {
                            width: root.s(6)
                            height: root.s(6)
                            radius: root.s(3)
                            color: root.selectedControl === 3 ? root.primary : "transparent"
                            border.color: root.selectedControl === 3 ? root.primary : Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.4)
                            border.width: 1
                        }

                        Text {
                            text: "Paper Film Grain"
                            font.family: "JetBrains Mono"
                            font.pixelSize: root.s(12)
                            font.weight: Font.DemiBold
                            color: root.selectedControl === 3 ? root.primary : root.text
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: grainValText.implicitWidth + root.s(12)
                            height: root.s(18)
                            radius: root.s(5)
                            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.18)

                            Text {
                                id: grainValText
                                anchors.centerIn: parent
                                text: `${root.currentGrain}%`
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.s(11)
                                font.weight: Font.Bold
                                color: root.primary
                            }
                        }
                    }

                    Slider {
                        id: grainSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.s(20)
                        from: 0
                        to: 100
                        stepSize: 1
                        value: root.currentGrain

                        onMoved: root.applyBackend(root.currentTemp, root.currentGamma, root.currentSat, value, root.currentCrt)

                        background: Rectangle {
                            x: grainSlider.leftPadding
                            y: grainSlider.topPadding + (grainSlider.availableHeight - height) / 2
                            width: grainSlider.availableWidth
                            height: root.s(6)
                            radius: root.s(3)
                            color: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.6)

                            Rectangle {
                                width: grainSlider.visualPosition * parent.width
                                height: parent.height
                                radius: root.s(3)
                                color: root.primary
                            }
                        }

                        handle: Rectangle {
                            x: grainSlider.leftPadding + grainSlider.visualPosition * (grainSlider.availableWidth - width)
                            y: grainSlider.topPadding + (grainSlider.availableHeight - height) / 2
                            width: root.s(16)
                            height: root.s(16)
                            radius: root.s(8)
                            color: grainSlider.pressed ? root.primary : root.text
                            border.width: root.selectedControl === 3 ? root.s(2) : root.s(1)
                            border.color: root.selectedControl === 3 ? root.primary : root.crust
                        }
                    }
                }
            }

            // 5. CRT CURVATURE CARD
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.s(64)
                radius: root.s(12)
                color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.38)
                border.width: 1
                border.color: root.selectedControl === 4 ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.50) : Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.25)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.s(10)
                    spacing: root.s(6)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.s(8)

                        Rectangle {
                            width: root.s(6)
                            height: root.s(6)
                            radius: root.s(3)
                            color: root.selectedControl === 4 ? root.primary : "transparent"
                            border.color: root.selectedControl === 4 ? root.primary : Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.4)
                            border.width: 1
                        }

                        Text {
                            text: "CRT Window Curvature"
                            font.family: "JetBrains Mono"
                            font.pixelSize: root.s(12)
                            font.weight: Font.DemiBold
                            color: root.selectedControl === 4 ? root.primary : root.text
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: crtValText.implicitWidth + root.s(12)
                            height: root.s(18)
                            radius: root.s(5)
                            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.18)

                            Text {
                                id: crtValText
                                anchors.centerIn: parent
                                text: `${root.currentCrt}%`
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.s(11)
                                font.weight: Font.Bold
                                color: root.primary
                            }
                        }
                    }

                    Slider {
                        id: crtSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.s(20)
                        from: 0
                        to: 100
                        stepSize: 1
                        value: root.currentCrt

                        onMoved: root.applyBackend(root.currentTemp, root.currentGamma, root.currentSat, root.currentGrain, value)

                        background: Rectangle {
                            x: crtSlider.leftPadding
                            y: crtSlider.topPadding + (crtSlider.availableHeight - height) / 2
                            width: crtSlider.availableWidth
                            height: root.s(6)
                            radius: root.s(3)
                            color: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.6)

                            Rectangle {
                                width: crtSlider.visualPosition * parent.width
                                height: parent.height
                                radius: root.s(3)
                                color: root.primary
                            }
                        }

                        handle: Rectangle {
                            x: crtSlider.leftPadding + crtSlider.visualPosition * (crtSlider.availableWidth - width)
                            y: crtSlider.topPadding + (crtSlider.availableHeight - height) / 2
                            width: root.s(16)
                            height: root.s(16)
                            radius: root.s(8)
                            color: crtSlider.pressed ? root.primary : root.text
                            border.width: root.selectedControl === 4 ? root.s(2) : root.s(1)
                            border.color: root.selectedControl === 4 ? root.primary : root.crust
                        }
                    }
                }
            }
        }
    }
}
