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

    property string gameState: "IDLE"
    property int score
    property var horizontalColor: "#0000FF"
    property var verticalColor: "#00FF00"
    property var animationColors: ["#0000FF", "#00FF00", "#FFFF00", "#FF00FF"]
    property bool currentAxis: true // true: horizontal, false: vertical
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
            "IDLE"
        ],
        "CANCELLING": [
            "READY", 
            "IDLE"
        ],
        "BLOCKING": [
            "READY", 
            "IDLE"
        ],        
        "CELEBRATING": [
            "READY"
        ],
        "OUT": [
            "READY", 
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
                anchors.horizontalCenter: parent.horizontalCenter
                verticalAlignment: Text.AlignVCenter
                height: 0.666 * parent.height
                text: "Score: " + score
                font.pixelSize: 0.2 * parent.height
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

        property int count: 8
        onTriggered: {
            animationProgress += 1

            if (animationProgress > count) {
                animationProgress = 0
                chooseNewTargetZones()

                for (var i = 0; i < players.length; ++i) {
                    changePlayerState(players[i], "READY")
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
        id: axisChangeTimer
        interval: 7e2

        onTriggered: {
            console.log("Axis change timeout triggered")
            playersWantingToChangeAxis = 0
        }
    }

    Timer {
        id: blockingTimer
        interval: 1e3

        onTriggered: {
            console.log("Blocking timeout triggered")
            var blockers = findPlayersInState("BLOCKING")
            for (var i = 0; i < blockers.length; ++i) {
                changePlayerState(blockers[i], "READY")
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
        var occupiedZones = []
        var remainingPlayers = []

        for (var i = 0; i < players.length; ++i) {
            if (find(map.data.cornerZones, players[i].targetZone) != -1) {
                var oldTargetZone = players[i].targetZone
                var neighbors = map.data["neighborNumbers"][oldTargetZone - 1]

                do {
                    players[i].targetZone = neighbors[randomInt(0, neighbors.length)]
                } while (find(occupiedZones, players[i].targetZone) != -1)

                occupiedZones.push([players[i].targetZone])
                console.log("Player " + i + " changed target zone from " + oldTargetZone + " to " + players[i].targetZone)
            }
            else {
                remainingPlayers.push(players[i])
            }
        }

        for (var i = 0; i < remainingPlayers.length; ++i) {
            var oldTargetZone = remainingPlayers[i].targetZone
            var neighbors = map.data["neighborNumbers"][oldTargetZone-1]

            do {
                remainingPlayers[i].targetZone = neighbors[randomInt(0, neighbors.length)]
            } while (find(occupiedZones, remainingPlayers[i].targetZone) != -1)

            occupiedZones.push([remainingPlayers[i].targetZone])
            console.log("Player " + remainingPlayers[i].number + " changed target zone from " + oldTargetZone + " to " + remainingPlayers[i].targetZone)
        }

        for (var i = 0; i < players.length; ++i) {
            applyEffectToLeds(players[i], players[i].targetZone, CelluloBluetoothEnums.VisualEffectConstSingle, players[i].ledColor)
        }
    }

    function applyEffectToLeds(player, ledCount, effect, color) {
        for (var i = 0; i < ledCount; ++i) {
            player.setVisualEffect(effect, color, i)
        }
        for (var i = ledCount; i < 6; ++i) {
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

    function checkZones() {
        var targetReached = true
        for (var i = 0; i < players.length; ++i) {
            if (players[i].currentZone != players[i].targetZone) {
                targetReached = false
                break
            }
        }

        if (targetReached) {
            score += 1
            for (var i = 0; i < players.length; ++i) {
                changePlayerState(players[i], "CELEBRATING")
            }
        }
    }

    function changeGameState(newState) {
        if (gameState == newState)
            return

        console.assert(find(gameTransitions[gameState], newState) != -1)
        console.log("Game state changed from " + gameState + " to " + newState)

        if (newState == "INIT") {
            currentAxis = true

            zoneEngine.clearZones()
            zoneEngine.addNewZones(map.zones)
            zoneEngine.active = true

            for (var i = 0; i < players.length; ++i) {
                players[i].zoneValueChanged.connect(zoneValueChanged(players[i]))
                players[i].kidnappedChanged.connect(kidnappedChanged(players[i]))
                players[i].trackingGoalReached.connect(trackingGoalReached(players[i]))
                players[i].poseChanged.connect(poseChanged(players[i]))
                players[i].ledColor = currentAxis ? horizontalColor : verticalColor

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
            player.setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, "#FFFFFF", 10)
            player.simpleVibrate(0, 0, 0, 0, 0)
            changePlayerState(player, "MOVING")
            break
        
            case "READY":
            if (gameState == "INIT") {
                var initializing = findPlayersInState("MOVING")
                if (initializing.length == 0) {
                    chooseNewTargetZones()
                    changeGameState("RUNNING")
                }
            }

            if (areAllPlayersInState("READY"))
                checkZones()

            player.lastPosition = Qt.vector3d(player.x, player.y, player.theta)
            applyEffectToLeds(player, player.targetZone, CelluloBluetoothEnums.VisualEffectConstSingle, player.ledColor)
            player.setCasualBackdriveAssistEnabled(true)
            player.simpleVibrate(0, 0, 0, 0, 0);
            break
        
            case "CELEBRATING":
            animationProgress = 0
            animationTimer.restart()
            break

            case "MOVING":
            player.setCasualBackdriveAssistEnabled(false)
            moveToZone(player, player.nextZone)
            applyEffectToLeds(player, player.targetZone, CelluloBluetoothEnums.VisualEffectAlertSingle, player.ledColor)
            break

            case "CANCELLING":
            player.setCasualBackdriveAssistEnabled(false)
            moveToZone(player, player.nextZone)
            break

            case "BLOCKING":
            player.setCasualBackdriveAssistEnabled(false)
            player.setVisualEffect(CelluloBluetoothEnums.VisualEffectAlertAll, "#FF0000", 0)
            player.simpleVibrate(config.linearVelocity, config.linearVelocity, config.angularVelocity, 50, 0);
            blockingTimer.start()
            break
        }
    }

    function moveToZone(player, zoneNumber) {
        player.setGoalPosition(
            map.zones[zoneNumber - 1].x,
            map.zones[zoneNumber - 1].y,
            config.linearVelocity
        )
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
            if (i == player.number) {
                newZones.push(player.currentZone)
                continue
            }

            var zone = players[i].currentZone
            var playerZoneIndices = zoneIndices[zone - 1]
            var newZoneIndices = []
            
            console.log("Player " + i + " zone is " + zone + ", indices are " + playerZoneIndices[0] + ", " + playerZoneIndices[1])

            var offset = [
                playerZoneIndices[0] - moverZoneIndices[0], 
                playerZoneIndices[1] - moverZoneIndices[1]
            ]

            console.log("Player " + i + " offset is " + offset[0] + ", " + offset[1])

            if (offset[0] == 0) {
                if (offset[1] > 0) {
                    if (delta > 0.0) {
                        newZoneIndices = [ playerZoneIndices[0] - 1, playerZoneIndices[1] ]
                    }
                    else {
                        newZoneIndices = [ playerZoneIndices[0] + 1, playerZoneIndices[1] ]
                    }
                }
                else {
                    if (delta > 0.0) {
                        newZoneIndices = [ playerZoneIndices[0] + 1, playerZoneIndices[1] ]
                    }
                    else {
                        newZoneIndices = [ playerZoneIndices[0] - 1, playerZoneIndices[1] ]
                    }
                }
            }
            else if (offset[1] == 0) {
                if (offset[0] > 0) {
                    if (delta > 0.0) {
                        newZoneIndices = [ playerZoneIndices[0], playerZoneIndices[1] + 1 ]
                    }
                    else {
                        newZoneIndices = [ playerZoneIndices[0], playerZoneIndices[1] - 1 ]
                    }
                }
                else {
                    if (delta > 0.0) {
                        newZoneIndices = [ playerZoneIndices[0], playerZoneIndices[1] - 1 ]
                    }
                    else {
                        newZoneIndices = [ playerZoneIndices[0], playerZoneIndices[1] + 1 ]
                    }
                }
            }
            else {
                if (offset[0] > 0) {
                    if (offset[1] > 0) {
                        if (delta > 0.0) {
                            newZoneIndices = [ playerZoneIndices[0] - 1, playerZoneIndices[1] + 1 ]
                        }
                        else {
                            newZoneIndices = [ playerZoneIndices[0] + 1, playerZoneIndices[1] - 1 ]
                        }
                    }
                    else {
                        if (delta > 0.0) {
                            newZoneIndices = [ playerZoneIndices[0] + 1, playerZoneIndices[1] + 1 ]
                        }
                        else {
                            newZoneIndices = [ playerZoneIndices[0] - 1, playerZoneIndices[1] - 1 ]
                        }
                    }
                }
                else {                    
                    if (offset[1] > 0) {
                        if (delta > 0.0) {
                            newZoneIndices = [ playerZoneIndices[0] - 1, playerZoneIndices[1] - 1 ]
                        }
                        else {
                            newZoneIndices = [ playerZoneIndices[0] + 1, playerZoneIndices[1] + 1 ]
                        }
                    }
                    else {
                        if (delta > 0.0) {
                            newZoneIndices = [ playerZoneIndices[0] + 1, playerZoneIndices[1] - 1 ]
                        }
                        else {
                            newZoneIndices = [ playerZoneIndices[0] - 1, playerZoneIndices[1] + 1 ]
                        }
                    }
                }
            }

            if (newZoneIndices[0] < 0 || newZoneIndices[0] > zoneMatrix.length - 1 ||
                newZoneIndices[1] < 0 || newZoneIndices[1] > zoneMatrix[0].length - 1) {
                console.log("Player " + i + " cannot move from zone " + zone + " to indices " + newZoneIndices[0] + ", " + newZoneIndices[1])
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

    function translate(player, delta) {
        console.log("Trying to translate with delta = [" + delta[0] + ", " + delta[1] + "]")

        var zoneMatrix = map.data["zoneMatrix"]
        var zoneIndices = map.data["zoneIndices"]
        var blockers = []
        var newZones = []

        var sorted = []
        for (var i = 0; i < players.length; ++i) {
            sorted.push(players[i])
        }

        sorted.sort(function (a, b) {
            if (delta[0] > 0) {
                return (zoneIndices[a.currentZone - 1][0] > zoneIndices[b.currentZone - 1][0]) ? -1 : 1
            }
            else if (delta[0] < 0) {
                return (zoneIndices[a.currentZone - 1][0] < zoneIndices[b.currentZone - 1][0]) ? -1 : 1
            }
            else if (delta[1] > 0) {
                return (zoneIndices[a.currentZone - 1][1] > zoneIndices[b.currentZone - 1][1]) ? -1 : 1
            }
            else if (delta[1] < 0) {
                return (zoneIndices[a.currentZone - 1][1] < zoneIndices[b.currentZone - 1][1]) ? -1 : 1
            }

            return 0
        })


        for (var i = 0; i < sorted.length; ++i) {
            var playerZoneIndices = zoneIndices[sorted[i].currentZone - 1]
            var newZoneIndices = []

            var j = 0
            if (delta[0] > 0) {
                do {
                    newZoneIndices = [ zoneMatrix.length - 1 - j, playerZoneIndices[1]]
                    j += 1
                } while (find(newZones, zoneMatrix[newZoneIndices[0]][newZoneIndices[1]]) != -1 &&
                         j < zoneMatrix.length)
            }
            else if (delta[0] < 0) {
                do {
                    newZoneIndices = [ 0 + j, playerZoneIndices[1]]
                    j += 1
                } while (find(newZones, zoneMatrix[newZoneIndices[0]][newZoneIndices[1]]) != -1 &&
                         j < zoneMatrix.length)
            }
            else if (delta[1] > 0) {
                do {
                    newZoneIndices = [ playerZoneIndices[0], zoneMatrix[0].length - 1 - j]
                    j += 1
                } while (find(newZones, zoneMatrix[newZoneIndices[0]][newZoneIndices[1]]) != -1 &&
                         j < zoneMatrix.length)
            }
            else if (delta[1] < 0) {
                do {
                    newZoneIndices = [ playerZoneIndices[0], 0 + j]
                    j += 1
                } while (find(newZones, zoneMatrix[newZoneIndices[0]][newZoneIndices[1]]) != -1 &&
                         j < zoneMatrix.length)
            }

            if (newZoneIndices[0] < 0 || newZoneIndices[0] > zoneMatrix.length - 1 ||
                newZoneIndices[1] < 0 || newZoneIndices[1] > zoneMatrix[0].length - 1) {
                console.log("Player " + sorted[i].number + " cannot move from zone " + sorted[i].currentZone + " to zone " + zoneMatrix[newZoneIndices[0]][newZoneIndices[1]])
                blockers.push(sorted[i])
            }
            else {
                console.log("Player " + sorted[i].number + " will move from zone " + sorted[i].currentZone + " to zone " + zoneMatrix[newZoneIndices[0]][newZoneIndices[1]])
                newZones.push(zoneMatrix[newZoneIndices[0]][newZoneIndices[1]])
            }
        }

        var translationPossible = (blockers.length == 0)

        if (translationPossible) {
            for (var i = 0; i < sorted.length; ++i) {
                console.log("Translating player " + sorted.number + " from zone " + sorted[i].currentZone + " to zone " + newZones[i])

                sorted[i].nextZone = newZones[i]
                changePlayerState(sorted[i], "MOVING")
            }
        }
        else {
            changePlayerState(player, "CANCELLING")
            for (var i = 0; i < blockers.length; ++i) {
                changePlayerState(blockers[i], "BLOCKING")
            }
        }
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
        }
    }

    function kidnappedChanged(player) {
        return function() {
            if (gameState == "RUNNING") {
            //     if (player.state == "READY" && player.kidnapped == false) {
            //         playersWantingToChangeAxis += 1
            //         console.log("Players wanting to change axis: " + playersWantingToChangeAxis)
            //         if (playersWantingToChangeAxis == players.length) {
            //             console.log("Changing axis from " + currentAxis + " to " + !currentAxis)
            //             playersWantingToChangeAxis = 0
            //             axisChangeTimer.stop()
            //             currentAxis = !currentAxis

            //             for (var i = 0; i < players.length; ++i) {
            //                 if (currentAxis) {
            //                     players[i].ledColor = horizontalColor
            //                     players[i].lastPoseDelta = players[i].x - players[0].x
            //                 }
            //                 else {
            //                     players[i].ledColor = verticalColor
            //                     players[i].lastPoseDelta = players[i].y - players[0].y
            //                 }

            //                 applyEffectToLeds(players[i], players[i].targetZone, CelluloBluetoothEnums.VisualEffectConstSingle, players[i].ledColor)
            //             }
            //         }
            //         else {
            //             axisChangeTimer.restart()
            //         }
            //     }
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
                    var zone = map.zones[player.nextZone - 1]

                    if (player.currentZone != player.nextZone) {
                        console.log("Player " + player.number + " currentZone: " + player.currentZone + ", nextZone: " + player.nextZone)
                        changePlayerState(player, "MOVING")
                        return
                    }

                    if (!areAllPlayersInState("READY")) {
                        return
                    }

                    // first check for rotation
                    // prevent issue when player.theta wraps around
                    var delta = player.theta - player.lastPosition.z
                    if (delta > 180.0) {
                        delta -= 360.0
                    }
                    else if (delta < -180.0) {
                        delta += 360.0
                    }

                    if (Math.abs(delta) > config.rotationDelta) {
                        player.lastPosition = Qt.vector3d(player.x, player.y, player.theta)
                        rotate(player, delta)
                    }

                    // now check for translation
                    delta = Qt.vector2d(player.x - player.lastPosition.x, player.y - player.lastPosition.y)
                    if (Math.abs(delta.x) > config.translationDelta) {
                        player.lastPosition = Qt.vector3d(player.x, player.y, player.theta)
                        translate(player, [Math.sign(delta.x), null])
                    }
                    else if (Math.abs(delta.y) > config.translationDelta) {
                        player.lastPosition = Qt.vector3d(player.x, player.y, player.theta)
                        translate(player, [null, Math.sign(delta.y)])
                    }
                }
                else if (player.state == "MOVING") {
                    var zone = map.zones[player.nextZone - 1]
                    var distanceToCenter = Qt.vector2d(player.x - zone.x, player.y - zone.y)
                    if (distanceToCenter.dotProduct(distanceToCenter) < 5.0) {
                        trackingGoalReached(player)
                    }
                    
                    player.lastPosition = Qt.vector3d(player.x, player.y, player.theta)
                }
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
}
