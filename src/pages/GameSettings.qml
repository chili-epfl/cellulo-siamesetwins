import QtQuick 2.7
import QtQuick.Window 2.2
import QtQuick.Controls 2.3
import QtQml.Models 2.2
import QtQuick.Dialogs 1.3
import QtQuick.Layouts 1.3

import Cellulo 1.0
import QMLCache 1.0
import QMLBluetoothExtras 1.0

Page {
    id: root

    title: qsTr("Game Settings")

    Item {
        id: map 
        visible: false

        property real physicalWidth
        property real physicalHeight
        property int maxPlayers
        property var zones
    }

    Item {
        id: config
        visible: false

        property real linearVelocity
        property real maxMoveDistance
        property real leadPoseDelta
    }

    GridLayout {
        anchors.centerIn: parent
        columns: 2
        columnSpacing: 8
        rowSpacing: 24

        Text {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            text: qsTr("Game map: ")
            font.bold: true
        }

        ComboBox {
            id: mapListComboBox
            Layout.minimumWidth: 200
            Layout.preferredWidth: 300
            currentIndex: 1
            enabled: gameState == "IDLE"
            model: ListModel {
                id: mapListItems
                ListElement { text: "Numbers (A3, 2-3 players)"; name: "a3-numbers"; }
                ListElement { text: "Easymaze (A3, 2 players)"; name: "a3-easymaze"; }
                ListElement { text: "Colors (A4, 2 players)"; name: "a4-colors"; }
            }
            textRole: "text"
            onCurrentIndexChanged: loadMap(mapListItems.get(currentIndex).name)
        }


        Text {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            text: qsTr("Maximum movement distance (in mm): ")
            font.bold: true
        }

        TextInput {
            Layout.minimumWidth: 40
            Layout.preferredWidth: 40

            text: "100"
            validator: IntValidator { bottom: 5; top: 100; }

            onEditingFinished: config.maxMoveDistance = parseInt(text)
        }

        Text {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            text: qsTr("Robot velocity (in mm/s): ")
            font.bold: true
        }

        TextInput {
            Layout.minimumWidth: 40
            Layout.preferredWidth: 40

            text: "200"
            validator: IntValidator { bottom: 5; top: 500; }

            onEditingFinished: config.linearVelocity = parseInt(text)
        }

        Text {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            text: qsTr("Required pose delta for leading (in mm): ")
            font.bold: true
        }

        TextInput {
            Layout.minimumWidth: 40
            Layout.preferredWidth: 40

            text: "200"
            validator: IntValidator { bottom: 5; top: 100; }

            onEditingFinished: config.leadPoseDelta = parseInt(text)
        }
    }

    Component.onCompleted: mapListComboBox.currentIndex = 0
}
