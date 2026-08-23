import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window
    focus: true

    property real layoutWidth
    property real layoutHeight
    width: layoutWidth
    height: layoutHeight

    Scaler {
        id: scaler
    }
    function s(val) { return scaler.s(val); }

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/calendar"

    // Colors
    property color base: "#1e1e2e"
    property color mantle: "#181825"
    property color crust: "#11111b"
    property color text: "#cdd6f4"
    property color subtext0: "#a6adc8"
    property color overlay0: "#6c7086"
    property color surface0: "#313244"
    property color surface1: "#45475a"
    property color surface2: "#585b70"
    
    property color lavender: "#b4befe"
    property color blue: "#89b4fa"

    Process {
        id: searchCityProc
        property string query: ""
        command: ["bash", "-c", window.scriptsDir + "/search_city.sh '" + query + "'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                searchResultsModel.clear();
                try {
                    let json = JSON.parse(this.text);
                    for (let i = 0; i < json.length; i++) {
                        searchResultsModel.append(json[i]);
                    }
                    searchResultsList.visible = true;
                } catch(e) {}
            }
        }
    }

    ListModel { id: searchResultsModel }

    Rectangle {
        anchors.fill: parent
        color: "#d91e1e2e" // Translucent base
        border.color: "#33ffffff"
        border.width: 1
        radius: s(20)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: s(20)
            spacing: s(15)

            RowLayout {
                Layout.fillWidth: true
                spacing: s(10)
                
                Text {
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: s(24)
                    color: window.lavender
                    text: ""
                }

                Text {
                    Layout.fillWidth: true
                    font.family: "JetBrains Mono"
                    font.pixelSize: s(16)
                    font.weight: Font.Bold
                    color: window.text
                    text: "Weather Setup"
                }
            }

            Text {
                Layout.fillWidth: true
                font.family: "JetBrains Mono"
                font.pixelSize: s(11)
                color: window.subtext0
                text: "Please enter your OpenWeatherMap API key and search for a default city."
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: s(10)

                TextField {
                    id: apiKeyInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: s(36)
                    placeholderText: "API Key (e.g. abc123def456...)"
                    font.family: "JetBrains Mono"
                    font.pixelSize: s(12)
                    color: window.text
                    placeholderTextColor: window.overlay0
                    background: Rectangle {
                        color: window.surface0
                        radius: s(18)
                        border.color: apiKeyInput.activeFocus ? window.lavender : "transparent"
                        border.width: 1
                    }
                    leftPadding: s(15)
                    rightPadding: s(15)
                }

                TextField {
                    id: citySearchInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: s(36)
                    placeholderText: "Search city..."
                    font.family: "JetBrains Mono"
                    font.pixelSize: s(12)
                    color: window.text
                    placeholderTextColor: window.overlay0
                    background: Rectangle {
                        color: window.surface0
                        radius: s(18)
                        border.color: citySearchInput.activeFocus ? window.lavender : "transparent"
                        border.width: 1
                    }
                    leftPadding: s(15)
                    rightPadding: s(15)

                    Timer {
                        id: searchDebouncer
                        interval: 400
                        onTriggered: {
                            if (citySearchInput.text.length > 2) {
                                searchCityProc.query = citySearchInput.text;
                                searchCityProc.running = false;
                                searchCityProc.running = true;
                            }
                        }
                    }

                    onTextEdited: {
                        if (text.length > 2) {
                            searchDebouncer.restart();
                        } else {
                            searchDebouncer.stop();
                            searchResultsList.visible = false;
                            searchResultsModel.clear();
                        }
                    }
                }
                
                // Hidden City ID input to store the selection
                Text {
                    id: cityIdInput
                    visible: false
                    text: ""
                }

                Rectangle {
                    Layout.preferredWidth: s(80)
                    Layout.preferredHeight: s(36)
                    radius: s(18)
                    color: saveMa.containsMouse ? window.blue : window.lavender
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Text {
                        anchors.centerIn: parent
                        font.family: "JetBrains Mono"
                        font.pixelSize: s(12)
                        font.weight: Font.Bold
                        color: window.base
                        text: "Save"
                    }

                    MouseArea {
                        id: saveMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (apiKeyInput.text.length > 0 && cityIdInput.text.length > 0) {
                                Quickshell.execDetached(["bash", window.scriptsDir + "/setup_weather.sh", apiKeyInput.text, cityIdInput.text]);
                            }
                        }
                    }
                }
            }

            ListView {
                id: searchResultsList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(count * s(40), s(160))
                model: searchResultsModel
                visible: false
                clip: true
                spacing: s(4)

                delegate: Rectangle {
                    width: searchResultsList.width
                    height: s(36)
                    radius: s(8)
                    color: itemMa.containsMouse ? window.surface1 : window.surface0

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: s(15)
                        text: model.name + ", " + model.country
                        font.family: "JetBrains Mono"
                        font.pixelSize: s(12)
                        color: window.text
                    }

                    MouseArea {
                        id: itemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchResultsList.visible = false;
                            citySearchInput.text = model.name + ", " + model.country;
                            cityIdInput.text = model.id;
                        }
                    }
                }
            }
        }
    }
}
