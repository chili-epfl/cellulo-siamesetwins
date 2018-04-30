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
    title: qsTr("Numbers")

    property var config
    property var map
    property var players
    property bool mapChanged: false

    property string gameState: "IDLE"
    property int movesRemaining: 0
    property int score
    property var horizontalColor: "#0000FF"
    property var verticalColor: "#00FF00"
    property var animationColors: ["#0000FF", "#00FF00", "#FFFF00", "#FF00FF"]
    property int animationProgress: 0
    property int playersWantingToChangeAxis: 0

    property var gameTransitions: {
        "IDLE": [
            "INIT"
        ],
        "INIT": [
            "RUNNING",
            "IDLE"
        ],
        "RUNNING": [
            "IDLE"
        ]
    }
    
    property var playerTransitions: {
        "IDLE": [
            "INIT"
        ],
        "INIT": [
            "MOVING",
            "IDLE"
        ],
        "READY": [
            "MOVING",
            "CANCELLING",
            "BLOCKING",
            "CELEBRATING",
            "IDLE"
        ],
        "MOVING": [
            "READY", 
            "CELEBRATING",
            "IDLE"
        ],
        "CANCELLING": [
            "READY", 
            "MOVING",
            "IDLE"
        ],
        "BLOCKING": [
            "READY", 
            "MOVING",
            "IDLE"
        ],        
        "CELEBRATING": [
            "READY",
            "MOVING",
            "IDLE"
        ]
    }

    ToastManager {
        id: toast
    }

    CelluloZoneEngine {
        id: zoneEngine
        active: false
    }

    Rectangle {
        id: mainDisplay
        anchors.centerIn: parent
        width: 0.7 * parent.width
        height: 0.7 * parent.height
        color: "#ccccff"
        border.color: "#cccccc"
        border.width: 8
        radius: 16

        Column {
            width: parent.width
            height: parent.height
            
            Text {
                id: timeRemainingText
                anchors.horizontalCenter: parent.horizontalCenter
                verticalAlignment: Text.AlignVCenter
                height: 0.333 * parent.height
                font.pixelSize: 0.1 * parent.height
            }
            
            Text {
                id: movesRemainingText
                anchors.horizontalCenter: parent.horizontalCenter
                verticalAlignment: Text.AlignVCenter
                height: 0.333 * parent.height
                text: "Moves left: " + String(movesRemaining)
                font.pixelSize: 0.2 * parent.height
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                verticalAlignment: Text.AlignVCenter
                height: 0.333 * parent.height
                text: "Score: " + score
                font.pixelSize: 0.1 * parent.height
            }
        }
    }

    Button {
        id: startStopButton
        anchors.top: mainDisplay.bottom
        anchors.horizontalCenter: mainDisplay.horizontalCenter
        anchors.topMargin: 8
        font.pixelSize: 0.05 * parent.height
        text: "Start game"
        onClicked: {
            if (gameState == "IDLE") {
                start()
            }
            else {
                stop()
            }
        }
    }

    Timer {
        id: gameTimer
        interval: 100
        repeat: true
        running: false
        triggeredOnStart: true

        property var startTime: 0
        onTriggered: {
            if (startTime == 0) {
                startTime = new Date().getTime()
            }

            var timeLeft = config.gameLength - 1e-3 * (new Date().getTime() - startTime)

            if (timeLeft <= 0) {
                timeRemainingText.text = "Game Over!"
                stop()
            } else {
                timeRemainingText.text = "Time left: " + timeLeft.toFixed(2)
            }
        }
    }

    Timer {
        id: animationTimer
        interval: 5e2

        property int count: 6
        onTriggered: {
            animationProgress += 1

            if (animationProgress > count) {
                animationProgress = 0
                chooseNewTargetZones()

                for (var i = 0; i < players.length; ++i) {
                    changePlayerState(players[i], "MOVING")
                }

                return
            }
            else {
                animationTimer.restart()

                for (var i = 0; i < players.length; ++i) {
                    var colorIndex = animationProgress % animationColors.length
                    players[i].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, animationColors[colorIndex], 0)
                }
            }
        }
    }

    Timer {
        id: positionResetTimer
        interval: 2e3

        property int index: -1

        onTriggered: {
            console.log("Position reset timeout triggered")
            players[index].lastPosition = Qt.vector3d(players[index].x, players[index].y, players[index].theta)
            index = -1
        }
    }

    Timer {
        id: blockingTimer
        interval: 1e3

        onTriggered: {
            console.log("Blocking timeout triggered")
            var blockers = findPlayersInState("BLOCKING")
            for (var i = 0; i < blockers.length; ++i) {
                changePlayerState(blockers[i], "MOVING")
            }

            var cancellers = findPlayersInState("CANCELLING")
            for (var i = 0; i < cancellers.length; ++i) {
                changePlayerState(cancellers[i], "MOVING")
            }
        }
    }

    function start() {
        timeRemainingText.text = "Time left: " + config.gameLength.toFixed(2)

        if (players.length < map.minPlayers) {
            toast.show("Minimum number of players not met (minimum: " + map.minPlayers + ", current: " + players.length + ")")
            stop()
            return
        }
        else if (players.length > map.maxPlayers) {
            toast.show("Maximum number of players exceeded (maximum: " + map.maxPlayers + ", current: " + players.length + ")")
            stop()
            return
        }

        startStopButton.text = "Stop game"

        console.log("Starting game with " + players.length + " players")

        changeGameState("INIT")
    }

    function stop() {
        for (var i = 0; i < players.length; ++i) {
            changePlayerState(players[i], "IDLE")
        }

        changeGameState("IDLE")
        
        timeRemainingText.text = null
        startStopButton.text = "Start game"
    }

    function changeGameState(newState) {
        if (gameState == newState)
            return

        console.assert(find(gameTransitions[gameState], newState) != -1)
        console.log("Game state changed from " + gameState + " to " + newState)

        if (newState == "INIT") {
            if (mapChanged) {
                zoneEngine.clearZones()
                zoneEngine.addNewZones(map.zones)
                mapChanged = false
            }
            zoneEngine.active = true

            for (var i = 0; i < players.length; ++i) {
                players[i].zoneValueChanged.connect(zoneValueChanged(players[i]))
                players[i].kidnappedChanged.connect(kidnappedChanged(players[i]))
                players[i].trackingGoalReached.connect(trackingGoalReached(players[i]))
                players[i].poseChanged.connect(poseChanged(players[i]))
                players[i].ledColor = animationColors[i]

                changePlayerState(players[i], "INIT")

                zoneEngine.addNewClient(players[i])
            }
        }
        else if (newState == "RUNNING") {
            gameTimer.start()
        }
        else if (newState == "IDLE") {
            gameTimer.stop()
            gameTimer.startTime = 0

            zoneEngine.active = false
        }

        gameState = newState
    }

    function changePlayerState(player, newState) {
        if (player.state == newState)
            return

        console.log("Player " + player.number + " state changed from " + player.state + " to " + newState)
        console.assert(find(playerTransitions[player.state], newState) != -1, "Cannot transition from " + player.state + " to " + newState)

        player.state = newState

        switch (player.state) {
            case "IDLE":
            player.clearTracking()
            player.setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, "#000000", 0)
            player.simpleVibrate(0, 0, 0, 0, 0)
            break

            case "INIT":
            player.targetZone = map.data["initialZones"][player.number]
            player.nextZone = player.targetZone
            player.setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, player.ledColor, 10)
            player.simpleVibrate(0, 0, 0, 0, 0)
            changePlayerState(player, "MOVING")
            break
        
            case "READY":
            if (gameState == "INIT" && areAllPlayersInState("READY")) {
                chooseNewTargetZones()
                changeGameState("RUNNING")
            }

            for (var i = 0; i < players.length; ++i) {
                players[i].lastPosition = Qt.vector3d(players[i].x, players[i].y, players[i].theta)
            }

            player.setCasualBackdriveAssistEnabled(true)
            player.simpleVibrate(0, 0, 0, 0, 0);
            displayTargetZoneWithLeds(player, CelluloBluetoothEnums.VisualEffectConstSingle, player.ledColor)
            break
        
            case "CELEBRATING":
            animationProgress = 0
            animationTimer.restart()
            break

            case "MOVING":
            player.setCasualBackdriveAssistEnabled(false)
            moveToZone(player, player.nextZone)

            if (gameState == "RUNNING") {
                displayTargetZoneWithLeds(player, CelluloBluetoothEnums.VisualEffectConstSingle, player.ledColor)
            }
            else {
                player.setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, "#FFFFFF", 10)
            }
            break

            case "CANCELLING":
            player.setCasualBackdriveAssistEnabled(false)
            displayTargetZoneWithLeds(player, CelluloBluetoothEnums.VisualEffectConstSingle, player.ledColor)
            break

            case "BLOCKING":
            player.setCasualBackdriveAssistEnabled(false)
            player.setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, "#FF0000", 0)
            player.simpleVibrate(config.linearVelocity, config.linearVelocity, config.angularVelocity, 20, 0);
            blockingTimer.start()
            break
        }

        if (areAllPlayersInState("READY")) {
            checkZones()
            if (!areAllPlayersInState("CELEBRATING") && movesRemaining == 0) {
                stop()
            }
        }
    }

    function randomInt(min, max) {
        min = Math.ceil(min)
        max = Math.floor(max)
        return Math.floor(Math.random() * (max - min)) + min
    }

    function find(list, element) {
        console.assert(list && element, "List or element is undefined!")

        for (var i = 0; i < list.length; ++i)
            if (list[i] === element)
                return i

        return -1
    }

    function chooseNewTargetZones() {
        var newTargetZones = []

        for (var i = 0; i < players.length; ++i) {
            var choice
            do {
                choice = 1 + randomInt(0, map.zones.length)
            } while (choice == players[i].targetZone ||
                     find(newTargetZones, choice) != -1)

            newTargetZones.push(choice)
        }

        var positions = []
        var targets = []
        for (var i = 0; i < players.length; ++i) {
            console.log("Player " + i + " changed target zone from " + players[i].targetZone + " to " + newTargetZones[i])
            players[i].targetZone = newTargetZones[i]
            displayTargetZoneWithLeds(players[i], CelluloBluetoothEnums.VisualEffectConstSingle, players[i].ledColor)

            positions.push(map.data.zoneIndices[players[i].currentZone - 1])
            targets.push(map.data.zoneIndices[players[i].targetZone - 1])
        }

        movesRemaining = findMimimumMoves(map.data["zoneMatrix"], positions, targets, 8)
        console.log("Minimum moves: " + movesRemaining)
    }

    function checkZones() {
        var targetReached = true
        for (var i = 0; i < players.length; ++i) {
            if (players[i].currentZone != players[i].targetZone) {
                targetReached = false
                break
            }
        }

        if (gameState == "RUNNING" && targetReached) {
            score += 1
            for (var i = 0; i < players.length; ++i) {
                changePlayerState(players[i], "CELEBRATING")
            }
        }
    }

    function displayTargetZoneWithLeds(player, effect, color) {
        for (var i = 0; i < player.targetZone; ++i) {
            player.setVisualEffect(effect, color, i)
        }
        for (var i = player.targetZone; i < 6; ++i) {
            player.setVisualEffect(effect, "#000000", i)
        }
    }

    function areAllPlayersInState(state) {
        var answer = true
        for (var i = 0; i < players.length; ++i) {
            if (players[i].state != state) {
                answer = false
            }
        }

        return answer
    }

    function findPlayersInState(state) {
        var found = []
        for (var i = 0; i < players.length; ++i) {
            if (players[i].state == state) {
                found.push(players[i])
            }
        }

        return found
    }

    function queuePositionReset(player) {
        if (positionResetTimer.index == player.number)
            return

        if (positionResetTimer.index != -1) {
            var prevPlayer = players[positionResetTimer.index]
            prevPlayer.lastPosition = Qt.vector3d(prevPlayer.x, prevPlayer.y, prevPlayer.theta)
        }

        positionResetTimer.index = player.number
        positionResetTimer.restart()
    }

    function moveToZone(player, zoneNumber) {
        player.setGoalPosition(
            map.zones[zoneNumber - 1].x,
            map.zones[zoneNumber - 1].y,
            config.linearVelocity
        )
    }

    function zoneValueChanged(player) {
        return function(zone, value) {
            if (value == 1) {
                player.currentZone = map.data["zoneNumbers"][zone.name]
            }
            else if (zone == player.currentZone) {
                player.currentZone = null
            }

            console.log("Player " + player.number + ": value of zone " + zone.name + " changed to " + value)
            checkZones()
        }
    }

    function kidnappedChanged(player) {
        return function() {
            if (gameState == "RUNNING") {
                if (player.kidnapped == false) {
                    changePlayerState(player, "MOVING")
                }
            }
        }
    }

    function trackingGoalReached(player) {
        return function() {
            player.clearTracking()

            changePlayerState(player, "READY")
        }
    }

    function poseChanged(player) {
        return function() {
            if (gameState == "RUNNING") {
                if (player.state == "READY") {
                    if (player.currentZone != player.nextZone) {
                        console.log("Player " + player.number + " currentZone: " + player.currentZone + ", nextZone: " + player.nextZone)
                        changePlayerState(player, "MOVING")
                        return
                    }

                    if (!areAllPlayersInState("READY")) {
                        player.lastPosition = Qt.vector3d(player.x, player.y, player.theta)
                        return
                    }

                    var translation = Qt.vector2d(player.x - player.lastPosition.x, player.y - player.lastPosition.y)

                    // prevent issue when player.theta wraps around
                    var rotation = player.theta - player.lastPosition.z
                    if (rotation > 180.0) {
                        rotation -= 360.0
                    }
                    else if (rotation < -180.0) {
                        rotation += 360.0
                    }

                    if (Math.abs(translation.x) > config.translationDelta) {
                            movesRemaining -= 1
                            translate(player, [Math.sign(translation.x), 0])
                    }
                    else if (Math.abs(translation.y) > config.translationDelta) {
                        movesRemaining -= 1
                        translate(player, [0, Math.sign(translation.y)])
                    }
                    else if (Math.abs(rotation) > config.rotationDelta) {
                        movesRemaining -= 1
                        rotate(player, Math.sign(rotation))
                    }
                    else {
                        var translationThreshold = 0.25 * config.translationDelta
                        var rotationThreshold = 0.25 * config.rotationDelta

                        if (Math.abs(translation.x) > translationThreshold ||
                            Math.abs(translation.y) > translationThreshold ||
                            Math.abs(rotation) > rotationThreshold) {
                            queuePositionReset(player)
                        }
                    }
                }
                else if (player.state == "MOVING") {
                    var zone = map.zones[player.nextZone - 1]
                    var distanceToCenter = Qt.vector2d(player.x - zone.x, player.y - zone.y)
                    if (distanceToCenter.dotProduct(distanceToCenter) < 10.0) {
                        trackingGoalReached(player)
                    }
                }
            }
        }
    }

    function translate(player, delta) {
        console.log("Trying to translate with delta = [" + delta[0] + ", " + delta[1] + "]")

        var zoneMatrix = map.data["zoneMatrix"]
        var zoneIndices = map.data["zoneIndices"]
        var blockers = []
        var newZones = []

        var positions = []
        for (var i = 0; i < players.length; ++i) {
            positions.push(zoneIndices[players[i].currentZone - 1])
        }

        var newPositions = findZonesAfterTranslation(zoneMatrix, delta, positions)
        for (var i = 0; i < newPositions.length; ++i) {
            if (newPositions[i][0] < 0 || newPositions[i][0] > zoneMatrix.length - 1 ||
                newPositions[i][1] < 0 || newPositions[i][1] > zoneMatrix[0].length - 1) {
                console.log("Player " + i + " cannot move from zone " + players[i].currentZone + " to zone " + newPositions[i][0] + ", " + newPositions[i][1])
                blockers.push(sorted[i])
            }
            else {
                console.log("Player " + i + " will move from zone " + players[i].currentZone + " to zone " + zoneMatrix[newPositions[i][0]][newPositions[i][1]])
                newZones.push(zoneMatrix[newPositions[i][0]][newPositions[i][1]])
            }
        }

        var translationPossible = (blockers.length == 0)

        if (translationPossible) {
            for (var i = 0; i < players.length; ++i) {
                console.log("Translating player " + i + " from zone " + players[i].currentZone + " to zone " + newZones[i])

                players[i].nextZone = newZones[i]
                changePlayerState(players[i], "MOVING")
            }
        }
        else {
            changePlayerState(player, "CANCELLING")
            for (var i = 0; i < blockers.length; ++i) {
                changePlayerState(blockers[i], "BLOCKING")
            }
        }
    }

    function rotate(player, delta) {
        console.log("Trying to rotate around player " + player.number + " with delta = " + delta)

        var zoneMatrix = map.data["zoneMatrix"]
        var zoneIndices = map.data["zoneIndices"]
        var blockers = []
        var newZones = []
        var moverZoneIndices = zoneIndices[player.currentZone - 1]

        console.log("Mover zone is " + player.currentZone + ", indices are " + moverZoneIndices[0] + ", " + moverZoneIndices[1])

        for (var i = 0; i < players.length; ++i) {
            var playerZoneIndices = zoneIndices[players[i].currentZone - 1]
            var newZoneIndices = findZoneAfterRotation(moverZoneIndices, delta, playerZoneIndices)

            if (newZoneIndices[0] < 0 || newZoneIndices[0] > zoneMatrix.length - 1 ||
                newZoneIndices[1] < 0 || newZoneIndices[1] > zoneMatrix[0].length - 1) {
                console.log("Player " + i + " cannot move from zone " + players[i].currentZone + " to indices " + newZoneIndices[0] + ", " + newZoneIndices[1])
                blockers.push(players[i])
            }
            else {
                newZones.push(zoneMatrix[newZoneIndices[0]][newZoneIndices[1]])
            }
        }

        var rotationPossible = (blockers.length == 0)

        if (rotationPossible) {
            for (var i = 0; i < players.length; ++i) {
                console.log("Rotating player " + i + " from zone " + players[i].currentZone + " to zone " + newZones[i])

                players[i].nextZone = newZones[i]
                changePlayerState(players[i], "MOVING")
            }
        }
        else {
            changePlayerState(player, "CANCELLING")
            for (var i = 0; i < blockers.length; ++i) {
                changePlayerState(blockers[i], "BLOCKING")
            }
        }
    }

    /**
     * Finds coordinates of all players in zone matrix after translation.
     *  - direction: vector of translation direction
     *  - positions: current zone matrix coords of all players
     * Output:
     *  - new zone matrix coords of all players
    */
    function findZonesAfterTranslation(zoneMatrix, direction, positions) {
        var indexed = []
        for (var i = 0; i < positions.length; ++i) {
            indexed.push([i, positions[i]])
        }

        indexed.sort(function (a, b) {
            if (direction[0] > 0) {
                return (a[1][0] > b[1][0]) ? -1 : 1
            }
            else if (direction[0] < 0) {
                return (a[1][0] < b[1][0]) ? -1 : 1
            }
            else if (direction[1] > 0) {
                return (a[1][1] > b[1][1]) ? -1 : 1
            }
            else if (direction[1] < 0) {
                return (a[1][1] < b[1][1]) ? -1 : 1
            }

            return 0
        })

        var limit
        if (direction[0] > 0) {
            limit = zoneMatrix.length - 1
        }
        else if (direction[0] < 0) {
            limit = 0
        }
        else if (direction[1] > 0) {
            limit = zoneMatrix[0].length - 1
        }
        else if (direction[1] < 0) {
            limit = 0
        }
        else {
            console.assert(false, "Invalid translation direction!")
        }

        var furthest = []
        if (direction[0] != 0) {
            for (var i = 0; i < zoneMatrix[0].length; ++i) {
                furthest.push(limit)
            }
        }
        else {
            for (var i = 0; i < zoneMatrix.length; ++i) {
                furthest.push(limit)
            }
        }

        var list = []
        for (var i = 0; i < indexed.length; ++i) {
            var newPosition = [ indexed[i][1][0], indexed[i][1][1] ]
            if (direction[0] != 0) {
                newPosition[0] = furthest[newPosition[1]]
                furthest[newPosition[1]] -= Math.sign(direction[0])
            }
            else {
                newPosition[1] = furthest[newPosition[0]]
                furthest[newPosition[0]] -= Math.sign(direction[1])
            }

            // console.log(indexed[i][1][0] + ", " + indexed[i][1][1] + " -> " + newPosition[0] + ", " + newPosition[1] + " (dir: " + direction[0] + ", " + direction[1] + ")")

            list.push([indexed[i][0], newPosition])
        }

        list.sort(function(a, b) {
            if (a[0] < b[0]) {
                return -1
            }
            else {
                return 1
            }
        })

        var result = []
        for (var i = 0; i < list.length; ++i) {
            result.push(list[i][1])
        }

        return result
    }

    /**
     * Finds coordinates in zone matrix where player will find itselt after rotation.
     * Inputs:
     *  - center: zone matrix coords of cetner of rotation
     *  - direction: positive if clockwise, negative if counter-clockwise
     *  - position: zone matrix coords of player position
     * Output:
     *  - zone matrix coords of new player position
    */
    function findZoneAfterRotation(center, direction, position) {
        if (center[0] == position[0] &&
            center[1] == position[1]) {
            return [position[0], position[1]]
        }

        var offset = [
            position[0] - center[0],
            position[1] - center[1]
        ]

        if (offset[0] == 0) {
            if (offset[1] > 0) {
                if (direction > 0.0) {
                    return [ position[0] - 1, position[1] ]
                }
                else {
                    return [ position[0] + 1, position[1] ]
                }
            }
            else {
                if (direction > 0.0) {
                    return [ position[0] + 1, position[1] ]
                }
                else {
                    return [ position[0] - 1, position[1] ]
                }
            }
        }
        else if (offset[1] == 0) {
            if (offset[0] > 0) {
                if (direction > 0.0) {
                    return [ position[0], position[1] + 1 ]
                }
                else {
                    return [ position[0], position[1] - 1 ]
                }
            }
            else {
                if (direction > 0.0) {
                    return [ position[0], position[1] - 1 ]
                }
                else {
                    return [ position[0], position[1] + 1 ]
                }
            }
        }
        else if (offset[0] > 0) {
            if (offset[1] > 0) {
                if (direction > 0.0) {
                    return [ position[0] - 1, position[1] + 1 ]
                }
                else {
                    return [ position[0] + 1, position[1] - 1 ]
                }
            }
            else {
                if (direction > 0.0) {
                    return [ position[0] + 1, position[1] + 1 ]
                }
                else {
                    return [ position[0] - 1, position[1] - 1 ]
                }
            }
        }
        else {                    
            if (offset[1] > 0) {
                if (direction > 0.0) {
                    return [ position[0] - 1, position[1] - 1 ]
                }
                else {
                    return [ position[0] + 1, position[1] + 1 ]
                }
            }
            else {
                if (direction > 0.0) {
                    return [ position[0] + 1, position[1] - 1 ]
                }
                else {
                    return [ position[0] - 1, position[1] + 1 ]
                }
            }
        }
    }

    function computePositionHash(positions) {
        var hash = ""
        for (var i = 0; i < positions.length; ++i) {
            hash += String(positions[i][0]) + String(positions[i][1])
        }

        return hash
    }

    function findMimimumMoves(zoneMatrix, positions, targets, limit) {
        var memo = []
        var rotations = [-1, 1]
        var translations = [
            [-1,  0],
            [ 1,  0],
            [ 0, -1],
            [ 0,  1]
        ]

        var initialPositions = []
        for (var i = 0; i < positions.length; ++i) {
            memo[computePositionHash(positions)] = true
            initialPositions.push(positions[i])
        }

        var tree = [ [initialPositions] ]
        for (var d = 0; d < limit; ++d) {
            // console.log("Depth: " + d)

            tree.push([])

            // compute possible next positions for all nodes at depth d
            for (var n = 0; n < tree[d].length; ++n) {
                var current = tree[d][n]
                var future = []

                // for (var i = 0; i < current.length; ++i) {
                //     console.log("Player " + i + " current position: " + current[i][0] + ",  " + current[i][1])
                // }

                // store rotations
                for (var i = 0; i < rotations.length; ++i) {
                    for (var j = 0; j < current.length; ++j) {
                        var next = []
                        for (var k = 0; k < current.length; ++k) {
                            next.push(findZoneAfterRotation(current[j], rotations[i], current[k]))
                        }

                        for (var t = 0; t < next.length; ++t) {
                            // console.log(current[t][0] + ", " + current[t][1] + " -> "  + next[t][0] + ", " + next[t][1] + " (rot: " + rotations[i] + ")")
                        }

                        var hash = computePositionHash(next)
                        if (!(hash in memo)) {
                            memo[hash] = true
                            future.push(next)
                        }
                    }
                }

                // store translations
                for (var i = 0; i < translations.length; ++i) {
                    var next = findZonesAfterTranslation(zoneMatrix, translations[i], current)
                    var hash = computePositionHash(next)
                    if (!(hash in memo)) {
                        future.push(next)
                    }
                }

                // filter for goal/validity
                var valid = []
                for (var i = 0; i < future.length; ++i) {
                    var accept = true
                    var found = true

                    // console.log("Future positions " + i + ": ")
                    for (var j = 0; j < future[i].length; ++j) {
                        // console.log("Player " + j + ": " + future[i][j][0] + ", " + future[i][j][1])

                        if (future[i][j][0] >= 0 && future[i][j][0] < zoneMatrix.length &&
                            future[i][j][1] >= 0 && future[i][j][1] < zoneMatrix[0].length) {
                            if (future[i][j][0] != targets[j][0] || future[i][j][1] != targets[j][1]) {
                                found = false
                            }
                        }
                        else {
                            accept = found = false
                        }
                    }

                    if (found) {
                        // console.log("Found!")
                        return d + 1
                    }
                    else if (accept) {
                        // console.log("Accepted")
                        valid.push(future[i])
                    }
                    // else {
                    //     console.log("Rejected")
                    // }
                }

                for (var i = 0; i < valid.length; ++i) {
                    tree[d + 1].push(valid[i])
                }
            }
        }

        return limit + 1
    }
}
