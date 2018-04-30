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
        property real translationDelta
        property real gameLength
    }

    function loadMap(name) {
        console.log("Loading map " + name + "...")

        fileIo.path = ":/assets/" + name + "-config.json"
        var config = JSON.parse(fileIo.readAll())

        map.physicalWidth = config["physicalWidth"]
        map.physicalHeight = config["physicalHeight"]
        map.minPlayers = config["minPlayers"]
        map.maxPlayers = config["maxPlayers"]
        map.data = config["data"]

        map.zones = CelluloZoneJsonHandler.loadZonesQML(":/assets/" + name + "-zones.json")
        for (var i = 0; i < map.zones.length; ++i) {
            console.log("Loaded zone " + map.zones[i].name + " with center " + map.zones[i].x + ", " + map.zones[i].y)
        }

        config.maxMoveDistance = config["maxMoveDistance"]
        config.linearVelocity = config["linearVelocity"]
        config.angularVelocity = config["angularVelocity"]
        config.translationDelta = config["translationDelta"]
        config.rotationDelta = config["rotationDelta"]
        config.gameLength = config["gameLength"]

        maxMoveDistanceInput.text = config.maxMoveDistance
        linearVelocityInput.text = config.linearVelocity
        angularVelocityInput.text = config.angularVelocity
        translationDeltaInput.text = config.translationDelta
        rotationDeltaInput.text = config.rotationDelta
        gameLengthInput.text = config.gameLength

        game.map = map 
        game.config = config
        game.mapChanged = true
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

            onEditingFinished: {
                game.config.maxMoveDistance = parseInt(text)
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            text: qsTr("Robot linear velocity (in mm/s): ")
            font.bold: true
        }

        TextInput {
            id: linearVelocityInput
            inputMethodHints: Qt.ImhDigitsOnly
            Layout.minimumWidth: 40
            Layout.preferredWidth: 40

            validator: IntValidator { bottom: 5; top: 500; }

            onEditingFinished: {
                game.config.linearVelocity = parseInt(text)
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            text: qsTr("Robot angular velocity (in mm/s): ")
            font.bold: true
        }

        TextInput {
            id: angularVelocityInput
            inputMethodHints: Qt.ImhDigitsOnly
            Layout.minimumWidth: 40
            Layout.preferredWidth: 40

            validator: IntValidator { bottom: 5; top: 500; }

            onEditingFinished: {
                game.config.angularVelocity = parseInt(text)
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            text: qsTr("Required pose delta for leading (in mm): ")
            font.bold: true
        }

        TextInput {
            id: translationDeltaInput
            inputMethodHints: Qt.ImhDigitsOnly
            Layout.minimumWidth: 40
            Layout.preferredWidth: 40

            validator: IntValidator { bottom: 5; top: 150; }

            onEditingFinished: {
                game.config.translationDelta = parseInt(text)
            }
        }

        TextInput {
            id: rotationDeltaInput
            inputMethodHints: Qt.ImhDigitsOnly
            Layout.minimumWidth: 40
            Layout.preferredWidth: 40

            validator: IntValidator { bottom: 5; top: 150; }

            onEditingFinished: {
                game.config.rotationDelta = parseInt(text)
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            text: qsTr("Game length (in s): ")
            font.bold: true
        }

        TextInput {
            id: gameLengthInput
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            Layout.minimumWidth: 40
            Layout.preferredWidth: 40

            validator: DoubleValidator { bottom: 5; top: 3600; }

            onEditingFinished: {
                game.config.gameLength = parseFloat(text)
            }
        }
    }

    Component.onCompleted: {
        loadMap(mapListItems.get(mapListComboBox.currentIndex).name)
    }
}
