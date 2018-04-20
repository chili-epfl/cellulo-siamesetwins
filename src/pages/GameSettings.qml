import QtQuick 2.7
import QtQuick.Window 2.2
import QtQuick.Controls 2.3
import QtQml.Models 2.2
import QtQuick.Dialogs 1.3
import QtQuick.Layouts 1.3

import Cellulo 1.0
import QMLCache 1.0
import QMLBluetoothExtras 1.0

import ch.epfl.chili.fileio 1.0

Page {
    id: root
    title: qsTr("Game Settings")

    property var game

    FileIo {
        id: fileIo
        visible: false
    }

    Item {
        id: map 
        visible: false

        property real physicalWidth
        property real physicalHeight
        property int minPlayers
        property int maxPlayers
        property var initialPositions
        property var zones
        property var data
    }

    Item {
        id: config
        visible: false

        property real linearVelocity
        property real maxMoveDistance
        property real leadPoseDelta
    }

    function loadMap(name) {
        console.log("Loading map " + name + "...")

        fileIo.path = ":/assets/" + name + "-config.json"
        var config = JSON.parse(fileIo.readAll())

        map.physicalWidth = config["physicalWidth"]
        map.physicalHeight = config["physicalHeight"]
        map.minPlayers = config["minPlayers"]
        map.maxPlayers = config["maxPlayers"]
        map.data = config["data"];


        var positions = config["initialPositions"]
        map.initialPositions = []
        for (var i = 0; i < positions.length; ++i) {
            map.initialPositions.push(Qt.vector2d(positions[i][0], positions[i][1]))
            console.log("Initial position " + i + ": " + map.initialPositions[i].x + ", " + map.initialPositions[i].y)
        }

        map.zones = CelluloZoneJsonHandler.loadZonesQML(":/assets/" + name + "-zones.json")

        config.maxMoveDistance = config["maxMoveDistance"]
        config.linearVelocity = config["linearVelocity"]
        config.leadPoseDelta = config["leadPoseDelta"]

        maxMoveDistanceInput.text = config.maxMoveDistance
        linearVelocityInput.text = config.linearVelocity
        leadPoseDeltaInput.text = config.leadPoseDelta

        game.map = map 
        game.config = config
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
            currentIndex: 0
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
            id: maxMoveDistanceInput
            inputMethodHints: Qt.ImhDigitsOnly
            Layout.minimumWidth: 40
            Layout.preferredWidth: 40

            validator: IntValidator { bottom: 5; top: 1000; }

            onEditingFinished: config.maxMoveDistance = parseInt(text)
        }

        Text {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            text: qsTr("Robot velocity (in mm/s): ")
            font.bold: true
        }

        TextInput {
            id: linearVelocityInput
            inputMethodHints: Qt.ImhDigitsOnly
            Layout.minimumWidth: 40
            Layout.preferredWidth: 40

            validator: IntValidator { bottom: 5; top: 500; }

            onEditingFinished: config.linearVelocity = parseInt(text)
        }

        Text {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            text: qsTr("Required pose delta for leading (in mm): ")
            font.bold: true
        }

        TextInput {
            id: leadPoseDeltaInput
            inputMethodHints: Qt.ImhDigitsOnly
            Layout.minimumWidth: 40
            Layout.preferredWidth: 40

            validator: IntValidator { bottom: 5; top: 150; }

            onEditingFinished: config.leadPoseDelta = parseInt(text)
        }
    }

    Component.onCompleted: {
        loadMap(mapListItems.get(mapListComboBox.currentIndex).name)
    }
}
