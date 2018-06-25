import QtQuick 2.7
import QtQuick.Window 2.2
import QtQuick.Controls 2.3
import QtQml.Models 2.2
import QtQuick.Dialogs 1.3

import Cellulo 1.0
import QMLCache 1.0
import QMLBluetoothExtras 1.0

import "./pages"

ApplicationWindow {
    id: root
    visible: true

    property bool mobile: Qt.platform.os === "android"
    width: mobile ? Screen.width : 1080
    height: mobile ? Screen.height : 720

    property bool userClosing: false

    title: "SiameseTwins"

    function reallyClose() {
        userClosing = true;
        close();
    }

    MainMenu {
        id: mainMenu
    }

    Numbers {
        id: numbers
    }

    GameSettings {
        id: gameSettings
        game: numbers
    }

    RobotSettings {
        id: robotSettings
    }

    CaptureSettings {
        id: captureSettings
        game: numbers
    }

    header: ToolBar {
        contentHeight: toolButton.implicitHeight

        ToolButton {
            id: toolButton
            text: "\u2630"
            font.pixelSize: Qt.application.font.pixelSize * 1.6
            onClicked: {
                stackView.pop()
                drawer.open()
            }
        }

        Label {
            text: stackView.currentItem.title
            anchors.centerIn: parent
        }
    }

    Drawer {
        id: drawer
        width: root.width * 0.4
        height: root.height

        Column {
            id: mainColumn
            anchors.fill: parent
            padding: 5

            ItemDelegate {
                id: startItem
                text: qsTr("Open Game")
                width: parent.width
                onClicked: {
                    numbers.players = robotSettings.robots
                    stackView.push(numbers)
                    drawer.close()
                    // activityOn = true
                    // game.drawZones(game.alpha)
                }
            }

            ItemDelegate {
                text: qsTr("Game Settings")
                width: parent.width
                onClicked: {
                    stackView.push(gameSettings)
                    drawer.close()
                    // activityOn = false
                }
            }

            ItemDelegate {
                text: qsTr("Robots Settings")
                width: parent.width
                onClicked: {
                    stackView.push(robotSettings)
                    drawer.close()
                    // activityOn = false
                }
            }

            ItemDelegate {
                text: qsTr("Capture Settings")
                width: parent.width
                onClicked: {
                    stackView.push(captureSettings)
                    drawer.close()
                    // activityOn = false
                }
            }

            Rectangle {
                width: drawer.width
                height: 2
                color: "black"
            }

            DelayButton {
                id: quitbtn
                text: "Quit (long touch)"
                delay: 1000
                onActivated: reallyClose()
            }
        }
    }

    StackView {
        id: stackView
        initialItem: mainMenu
        anchors.fill: parent
        onCurrentItemChanged: console.log(currentItem)
    }

    Component.onDestruction: console.log("Exiting app")
}
