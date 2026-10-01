import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: loaderRoot

    Theme { id: _theme }

    function s(val) {
        let masterW = (typeof Config !== "undefined" && Config.masterWidth > 0) ? Config.masterWidth : 1920;
        let masterH = (typeof Config !== "undefined" && Config.masterHeight > 0) ? Config.masterHeight : 1080;
        return Math.round(val * Math.min(masterW / 1920.0, masterH / 1080.0));
    }

    property bool isRedacting: false

    ListModel {
        id: widgetsModel
    }

    readonly property string widgetsConfigFile: Quickshell.env("HOME") + "/.config/quickshell/widgets.json"

    FileView {
        path: loaderRoot.widgetsConfigFile
        onTextChanged: {
            if (!text || text === "") return;
            try {
                let data = JSON.parse(text);
                widgetsModel.clear();
                if (Array.isArray(data)) {
                    for (let i = 0; i < data.length; i++) {
                        widgetsModel.append(data[i]);
                    }
                }
            } catch (e) {}
        }
    }

    Item {
        anchors.fill: parent

        Repeater {
            model: widgetsModel
            delegate: Rectangle {
                required property var modelData
                x: loaderRoot.s(modelData.x || 100)
                y: loaderRoot.s(modelData.y || 100)
                width: loaderRoot.s(modelData.w || 240)
                height: loaderRoot.s(modelData.h || 120)
                radius: loaderRoot.s(12)
                color: _theme.base
                border.width: loaderRoot.isRedacting ? 2 : 1
                border.color: loaderRoot.isRedacting ? _theme.mauve : _theme.surface0

                Text {
                    anchors.centerIn: parent
                    text: modelData.name || "Widget"
                    font.pixelSize: loaderRoot.s(13)
                    font.weight: Font.Bold
                    color: _theme.text
                }
            }
        }
    }
}
