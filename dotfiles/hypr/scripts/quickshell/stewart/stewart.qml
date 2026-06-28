import QtQuick
import QtQuick.Effects
import "../"

Item {
    id: root

    MatugenColors { id: _theme }

    // -------------------------------------------------------------------------
    // COLORS (Dynamic Matugen Palette)
    // -------------------------------------------------------------------------
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2

    readonly property color mauve: _theme.mauve
    readonly property color pink: _theme.pink
    readonly property color blue: _theme.blue
    readonly property color sapphire: _theme.sapphire

    // Master Container
    Rectangle {
        id: windowContent
        anchors.fill: parent
        radius: 12
        color: root.base
        clip: true

        // ---------------------------------------------------------------------
        // GLOBAL THEME & STATE CONTROLS
        // ---------------------------------------------------------------------

        // 5. Slow Color Temperature Drift
        property real baseBlend: 0.0
        SequentialAnimation on baseBlend {
            loops: Animation.Infinite; running: !SysData.onBattery
            NumberAnimation { to: 1.0; duration: 15000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.0; duration: 15000; easing.type: Easing.InOutSine }
        }
        
        property color currentBasePurple: Qt.tint(root.mauve, Qt.rgba(root.pink.r, root.pink.g, root.pink.b, baseBlend))

        property real accentBlend: 0.0
        SequentialAnimation on accentBlend {
            loops: Animation.Infinite; running: !SysData.onBattery
            NumberAnimation { to: 1.0; duration: 15000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.0; duration: 15000; easing.type: Easing.InOutSine }
        }
        
        property color currentAccentLavender: Qt.tint(root.blue, Qt.rgba(root.sapphire.r, root.sapphire.g, root.sapphire.b, accentBlend))

        // Animation States
        property real calmState: 0.0
        property real popShockwave: 0.0

        // 9. Breathing Phase Offsets (Continuous Time Engine)
        property real time: 0
        NumberAnimation on time {
            from: 0; to: Math.PI * 2; duration: 15000; loops: Animation.Infinite; running: !SysData.onBattery
        }

        // 3 separate breathing phases for organic offset
        property real breathA: (Math.sin(time * 3) + 1) / 2       
        property real breathB: (Math.sin(time * 3 + 0.6) + 1) / 2 
        property real breathC: (Math.sin(time * 3 + 1.2) + 1) / 2 

        // Window Entrance Animation
        opacity: 0.0
        scale: 0.98

        Component.onCompleted: entranceAnimation.start()

        ParallelAnimation {
            id: entranceAnimation
            NumberAnimation { target: windowContent; property: "opacity"; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
            NumberAnimation { target: windowContent; property: "scale"; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
        }

        property real globalOrbitAngle: 0
        NumberAnimation on globalOrbitAngle {
            from: 0; to: Math.PI * 2; duration: 60000; loops: Animation.Infinite; running: !SysData.onBattery
        }

        // ---------------------------------------------------------------------
        // BACKGROUND ARTIFACTS
        // ---------------------------------------------------------------------

        // 1. Large Flowing Background Orb A
        Rectangle {
            id: backgroundOrbA
            width: parent.width * 0.8
            height: width
            radius: width / 2

            x: (parent.width / 2 - width / 2) + Math.cos(windowContent.globalOrbitAngle * 2) * (250 - windowContent.calmState * 60) + (worldCenter.driftX * 0.4)
            y: (parent.height / 2 - height / 2) + Math.sin(windowContent.globalOrbitAngle * 2) * (150 - windowContent.calmState * 40) + (worldCenter.driftY * 0.4)

            opacity: 0.025 + (windowContent.breathC * 0.015 * (1.0 - (windowContent.calmState * 0.3)))
            color: windowContent.currentBasePurple
            antialiasing: true

            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 64; blur: 1.0 }
        }

        // 2. Large Flowing Background Orb B
        Rectangle {
            id: backgroundOrbB
            width: parent.width * 0.9
            height: width
            radius: width / 2

            x: (parent.width / 2 - width / 2) + Math.sin(windowContent.globalOrbitAngle * 1.5) * -(250 - windowContent.calmState * 60) + (worldCenter.driftX * 0.3)
            y: (parent.height / 2 - height / 2) + Math.cos(windowContent.globalOrbitAngle * 1.5) * -(150 - windowContent.calmState * 40) + (worldCenter.driftY * 0.3)

            opacity: 0.020 + (windowContent.breathC * 0.012 * (1.0 - (windowContent.calmState * 0.3)))
            color: windowContent.currentAccentLavender
            antialiasing: true

            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 80; blur: 1.0 }
        }

        // 3. Gravitational Floating Particles
        Repeater {
            model: 20

            Rectangle {
                id: particle
                property real randomPhase: index * 0.47
                property real baseX: (index * 113) % root.width
                property real baseY: (index * 137) % root.height

                property real vecX: (root.width / 2) - baseX
                property real vecY: (root.height / 2) - baseY

                width: (index % 4) + 3
                height: width
                radius: width / 2

                x: baseX + Math.cos(windowContent.time * 4 + randomPhase) * 15 * windowContent.calmState + (worldCenter.driftX * 0.8) - (vecX * 0.04 * windowContent.popShockwave)
                y: baseY + Math.sin(windowContent.time * 3 + randomPhase) * 15 * windowContent.calmState + (worldCenter.driftY * 0.8) - (vecY * 0.04 * windowContent.popShockwave)

                color: index % 3 === 0 ? windowContent.currentAccentLavender : windowContent.currentBasePurple

                opacity: ((index % 3) * 0.1 + 0.1) + (windowContent.popShockwave * 0.2)
                antialiasing: true

                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blurMax: (index % 3) * 3 + 2; blur: 1.0 }
            }
        }

        // ---------------------------------------------------------------------
        // THE ASSISTANT CORE
        // ---------------------------------------------------------------------

        Item {
            id: orbGlow
            anchors.centerIn: parent
            width: 150
            height: 150

            property real baseOpacity: 0.0
            property real baseScale: 0.8

            opacity: baseOpacity * (1.0 - (windowContent.calmState * 0.2)) * (0.8 + (windowContent.breathA * 0.2))
            scale: baseScale + (windowContent.breathA * 0.03)

            Repeater {
                model: 2
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + (index * 40) + 20
                    height: width
                    radius: width / 2
                    color: windowContent.currentBasePurple
                    opacity: index === 0 ? 0.12 : 0.05
                    antialiasing: true
                }
            }
        }

        Rectangle {
            id: diffuseShockwave
            anchors.centerIn: parent
            width: 150
            height: 150
            radius: width / 2
            color: windowContent.currentAccentLavender
            opacity: windowContent.popShockwave * 0.12
            scale: 1.0 + (windowContent.popShockwave * 0.8)
            antialiasing: true
        }

        Item {
            id: worldCenter
            width: 150
            height: 150

            property real driftX: 0
            property real driftY: 0

            SequentialAnimation on driftX {
                loops: Animation.Infinite; running: !SysData.onBattery
                NumberAnimation { to: 2; duration: 7450; easing.type: Easing.InOutSine }
                NumberAnimation { to: -1.5; duration: 6920; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on driftY {
                loops: Animation.Infinite; running: !SysData.onBattery
                NumberAnimation { to: 1.5; duration: 8210; easing.type: Easing.InOutSine }
                NumberAnimation { to: -2; duration: 7630; easing.type: Easing.InOutSine }
            }

            anchors.centerIn: parent
            anchors.horizontalCenterOffset: driftX
            anchors.verticalCenterOffset: driftY

            rotation: windowContent.calmState * Math.sin(windowContent.time * 2) * 2.0

            Item {
                id: orb
                anchors.fill: parent

                Rectangle {
                    id: loadingShell
                    anchors.fill: parent
                    radius: width / 2
                    antialiasing: true
                    opacity: 1.0

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.surface2 }
                        GradientStop { position: 1.0; color: root.surface0 }
                    }
                }

                Item {
                    id: activeEnergyCore
                    anchors.fill: parent
                    opacity: 0.0
                    scale: 1.0 + (windowContent.breathB * 0.015)

                    Rectangle {
                        id: fluidGradientLayer
                        anchors.fill: parent
                        radius: width / 2
                        antialiasing: true

                        property real oscRotation: 0
                        SequentialAnimation on oscRotation {
                            loops: Animation.Infinite; running: !SysData.onBattery
                            NumberAnimation { to: 15; duration: 6000; easing.type: Easing.InOutSine }
                            NumberAnimation { to: -15; duration: 6000; easing.type: Easing.InOutSine }
                        }
                        rotation: oscRotation

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.0
                                color: windowContent.currentBasePurple
                                SequentialAnimation on position {
                                    loops: Animation.Infinite; running: !SysData.onBattery
                                    NumberAnimation { to: 0.2; duration: 5000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 0.0; duration: 5000; easing.type: Easing.InOutSine }
                                }
                            }
                            GradientStop {
                                position: 1.0
                                color: windowContent.currentAccentLavender
                                SequentialAnimation on position {
                                    loops: Animation.Infinite; running: !SysData.onBattery
                                    NumberAnimation { to: 0.8; duration: 4500; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 4500; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        opacity: 0.3 + (windowContent.breathB * 0.2)
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.6
                            height: width
                            radius: width / 2
                            color: windowContent.currentAccentLavender
                            opacity: 0.4
                            layer.enabled: true
                            layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: 1.0 }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        antialiasing: true
                        opacity: 0.8

                        property real maskRotation: 0
                        SequentialAnimation on maskRotation {
                            loops: Animation.Infinite; running: !SysData.onBattery
                            NumberAnimation { to: -20; duration: 7000; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 20; duration: 7000; easing.type: Easing.InOutSine }
                        }
                        rotation: maskRotation

                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.4; color: windowContent.currentAccentLavender }
                            GradientStop { position: 0.6; color: windowContent.currentAccentLavender }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        opacity: 0.03
                        clip: true
                        layer.enabled: true
                        layer.effect: MultiEffect { blurEnabled: true; blurMax: 2; blur: 1.0 }
                        Repeater {
                            model: 24
                            Rectangle {
                                property real angle: index * 15
                                property real dist: (index * 4) % (parent.width / 2.2)
                                x: (parent.width / 2) + Math.cos(angle) * dist - width/2
                                y: (parent.height / 2) + Math.sin(angle) * dist - height/2
                                width: (index % 3) + 2
                                height: width
                                radius: width/2
                                color: root.text
                                rotation: windowContent.time * 20 * (index % 2 === 0 ? 1 : -1)
                            }
                        }
                    }

                    Rectangle {
                        id: refractionLayer
                        anchors.fill: parent
                        radius: width / 2
                        antialiasing: true
                        rotation: 25
                        color: "transparent"
                        opacity: 1.0 - (windowContent.calmState * 0.2)

                        property real sweepPos: 0.0
                        SequentialAnimation on sweepPos {
                            loops: Animation.Infinite; running: !SysData.onBattery
                            NumberAnimation { from: -0.5; to: 1.5; duration: 8000; easing.type: Easing.InOutSine }
                            PauseAnimation { duration: 4000 }
                        }

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: Math.max(0.0, Math.min(1.0, refractionLayer.sweepPos - 0.2)); color: "transparent" }
                            GradientStop { position: Math.max(0.0, Math.min(1.0, refractionLayer.sweepPos)); color: Qt.alpha(root.text, 0.08) }
                            GradientStop { position: Math.max(0.0, Math.min(1.0, refractionLayer.sweepPos + 0.2)); color: "transparent" }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1 
                        radius: width / 2
                        color: "transparent"
                        border.width: 1.5
                        border.color: Qt.rgba(root.text.r, root.text.g, root.text.b, 0.15 + windowContent.breathA * 0.1)
                        antialiasing: true
                        layer.enabled: true
                        layer.effect: MultiEffect { blurEnabled: true; blurMax: 4; blur: 1.0 }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // MASTER CINEMATIC SEQUENCE
        // ---------------------------------------------------------------------
        SequentialAnimation {
            id: introSequence
            running: true

            PauseAnimation { duration: 200 }

            NumberAnimation { target: loadingShell; property: "rotation"; from: 0; to: 360; duration: 1200; easing.type: Easing.InCubic }
            NumberAnimation { target: orb; property: "scale"; to: 0.96; duration: 250; easing.type: Easing.InOutSine }
            
            PauseAnimation { duration: 100 }

            ParallelAnimation {
                NumberAnimation { target: loadingShell; property: "opacity"; to: 0.0; duration: 150 }
                NumberAnimation { target: activeEnergyCore; property: "opacity"; to: 1.0; duration: 300 }

                SequentialAnimation {
                    NumberAnimation { target: orb; property: "scale"; to: 1.05; duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { target: orb; property: "scale"; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                }

                SequentialAnimation {
                    NumberAnimation { target: windowContent; property: "popShockwave"; from: 0.0; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
                    NumberAnimation { target: windowContent; property: "popShockwave"; to: 0.0; duration: 1200; easing.type: Easing.OutQuart }
                }

                NumberAnimation { target: orbGlow; property: "baseOpacity"; to: 1.0; duration: 400; easing.type: Easing.InOutSine }
                NumberAnimation { target: orbGlow; property: "baseScale"; to: 1.0; duration: 600; easing.type: Easing.OutBack }
            }

            NumberAnimation { target: windowContent; property: "calmState"; from: 0.0; to: 1.0; duration: 2500; easing.type: Easing.InOutSine }
        }
    }
}