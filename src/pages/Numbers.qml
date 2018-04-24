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
            "READY",
            "IDLE"
        ],
        "READY": [
            "FOLLOWING",
            "MOVING",
            "ROTATING",
            "CELEBRATING",
            "IDLE"
        ],
        "FOLLOWING": [
            "READY",
            "IDLE"
        ],
        "MOVING": [
            "READY", 
            "IDLE"
        ],
        "ROTATING": [
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

    function randomInt(min, max) {
        min = Math.ceil(min)
        max = Math.floor(max)
        return Math.floor(Math.random() * (max - min)) + min
    }

    function find(list, element) {
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

    function findPlayersInState(state) {
        var found = []
        for (var i = 0; i < players.length; ++i)
            if (players[i].state == state)
                found.push(players[i])

        return found
    }

    function checkZones() {
        var targetReached = true
        for (var i = 0; i < players.length; ++i) {
            if (players[i].state != "READY") {
                targetReached = false
                break
            }
            if (find(players[i].currentZones, players[i].targetZone) == -1) {
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
                players[i].targetZone = 6 - i
                players[i].currentZones = []

                changePlayerState(players[i], "INIT")

                zoneEngine.addNewClient(players[i])
            }
        }
        else if (newState == "RUNNING") {
            gameTimer.start()
        }
        else if (newState == "IDLE") {
            zoneEngine.active = false
            gameTimer.stop()
            gameTimer.startTime = 0
        }

        gameState = newState
    }

    function updatePose() {
        for (var i = 0; i < players.length; ++i) {
            if (currentAxis) {
                players[i].lastPoseDelta = players[i].x - players[0].x
            }
            else {
                players[i].lastPoseDelta = players[i].y - players[0].y
            }
            players[i].lastPosition = Qt.vector3d(players[i].x, players[i].y, players[i].theta)
        }
    }

    function changePlayerState(player, newState) {
        if (player.state == newState)
            return

        console.log("Player " + player.number + " state changed from " + player.state + " to " + newState)
        console.assert(find(playerTransitions[player.state], newState) != -1)

        switch (player.state) {
            case "IDLE":
            if (newState == "INIT") {
                if (currentAxis) {
                    player.lastPoseDelta = map.initialPositions[player.number].x - map.initialPositions[0].x
                }
                else {
                    player.lastPoseDelta = map.initialPositions[player.number].y - map.initialPositions[0].y
                }

                player.currentPoseDelta = player.lastPoseDelta

                player.setGoalPosition(
                    map.initialPositions[player.number].x, 
                    map.initialPositions[player.number].y, 
                    config.linearVelocity
                )

                player.setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, "#FFFFFF", 10)
            }
            break
        
            case "INIT":
            if (newState == "READY") {
                var initializing = findPlayersInState("INIT")
                if (initializing.length == 1) {
                    chooseNewTargetZones()
                    changeGameState("RUNNING")
                }
            }
            break
        
            case "READY":
            if (newState == "MOVING" || newState == "ROTATING") {
                for (var i = 0; i < players.length; ++i) {
                    if (i != player.number) {
                        changePlayerState(players[i], "FOLLOWING")
                    }
                }
            }
            else if (newState == "CELEBRATING") {
                animationProgress = 0
                animationTimer.restart()
            }
            break

            case "MOVING":
            if (newState == "READY") {
                updatePose()
            }
            break

            case "ROTATING":
            if (newState == "READY") {
                updatePose()
            }
            break

            case "FOLLOWING":
            if (newState == "READY") {
                var followers = findPlayersInState("FOLLOWING")
                if (followers.length == 1) {
                    var leader = findPlayersInState("ROTATING")[0]
                    if (leader == null) {
                        leader = findPlayersInState("MOVING")[0]
                    }
                    console.assert(leader != null)
                    changePlayerState(leader, "READY")
                }
            }
        }

        player.state = newState

        if (player.state == "READY") {
            applyEffectToLeds(player, player.targetZone, CelluloBluetoothEnums.VisualEffectConstSingle, player.ledColor)
        }
        else if (player.state == "IDLE") {
            player.clearTracking()
            player.setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, "#000000", 0)
        }
    }

    function zoneValueChanged(player) {
        return function(zone, value) {
            var zoneNumber = map.data["zoneNumbers"][zone.name]

            if (value == 1) {
                console.log("Player " + player.number + " entered zone " + zone.name)

                if (find(player.currentZones, zoneNumber) == -1) {
                    player.currentZones.push(zoneNumber)
                }
            }
            else {
                console.log("Player " + player.number + " left zone " + zone.name)

                var newCurrentZones = []
                for (var i = 0; i < player.currentZones.length; ++i) {
                    if (player.currentZones[i] != zoneNumber) {
                        newCurrentZones.push(player.currentZones[i])
                    }
                }
                player.currentZones = newCurrentZones
            }
        }
    }

    function kidnappedChanged(player) {
        return function() {
            if (gameState == "RUNNING") {
                if (player.state == "READY" && player.kidnapped == false) {
                    playersWantingToChangeAxis += 1
                    console.log("Players wanting to change axis: " + playersWantingToChangeAxis)
                    if (playersWantingToChangeAxis == players.length) {
                        console.log("Changing axis from " + currentAxis + " to " + !currentAxis)
                        playersWantingToChangeAxis = 0
                        axisChangeTimer.stop()
                        currentAxis = !currentAxis

                        for (var i = 0; i < players.length; ++i) {
                            if (currentAxis) {
                                players[i].ledColor = horizontalColor
                                players[i].lastPoseDelta = players[i].x - players[0].x
                            }
                            else {
                                players[i].ledColor = verticalColor
                                players[i].lastPoseDelta = players[i].y - players[0].y
                            }

                            applyEffectToLeds(players[i], players[i].targetZone, CelluloBluetoothEnums.VisualEffectConstSingle, players[i].ledColor)
                        }
                    }
                    else {
                        axisChangeTimer.restart()
                    }
                }
            }
        }
    }

    function trackingGoalReached(player) {
        return function() {
            player.clearTracking()

            player.lastPosition = Qt.vector3d(player.x, player.y, player.theta)

            if (player.state == "INIT") {
                console.log("Player " + player.number + " position initialized.")
                changePlayerState(player, "READY")
            }
            else {
                if (player.state == "FOLLOWING") {
                    changePlayerState(player, "READY")
                }
            }
        }
    }

    function poseChanged(player) {
        return function() {
            if (gameState != "IDLE") {
                if (currentAxis) {
                    player.currentPoseDelta = player.x - players[0].x
                }
                else {
                    player.currentPoseDelta = player.y - players[0].y
                }
            }

            if (gameState == "RUNNING") {
                if (player.state == "READY") {
                    checkZones()

                    // first check for rotation
                    var delta = player.lastPosition.z - player.theta
                    if (Math.abs(delta) > config.rotationDelta) {
                        player.previousTheta = player.theta
                        changePlayerState(player, "ROTATING")
                    }

                    // now check for translation
                    delta = currentAxis ? player.lastPosition.x - player.x : player.lastPosition.y - player.y
                    if (Math.abs(delta) > config.translationDelta) {
                        changePlayerState(player, "MOVING")
                    }
                }
                else if (player.state == "ROTATING") {
                    // instruct others to follow
                    for (var i = 0; i < players.length; ++i) {
                        if (i != player.number) {
                            changePlayerState(players[i], "FOLLOWING")

                            var offset = Qt.vector2d(
                                players[i].lastPosition.x - player.lastPosition.x, 
                                players[i].lastPosition.y - player.lastPosition.y
                            )

                            var radius = Math.sqrt(offset.dotProduct(offset))
                            var angle = Math.atan2(-offset.x, offset.y)

                            // console.log("Offset: " + offset.x + ", " + offset.y)

                            // prevent issue when player.theta wraps around
                            var angleDelta = player.theta - player.previousTheta
                            if (angleDelta > 180.0) {
                                angleDelta = player.theta - player.lastPosition.z - 360.0
                            }
                            else if (angleDelta < -180.0) {
                                angleDelta = player.theta - player.lastPosition.z + 360.0
                            }
                            else {
                                angleDelta = player.theta - player.lastPosition.z
                            }

                            angleDelta *= Math.PI / 180.0
                            player.previousTheta = player.theta


                            var newAngle = angle + angleDelta
                            var newOffset = Qt.vector2d(-radius * Math.sin(newAngle), radius * Math.cos(newAngle))

                            // console.log("Angle: " + angle + ", angle delta: " + angleDelta + ", new angle: " + newAngle)
                            // console.log("New offset: " + newOffset.x + ", " + newOffset.y)

                            players[i].setGoalPosition(player.x + newOffset.x, player.y + newOffset.y,config.linearVelocity)
                        }
                    }
                }
                else if (player.state == "MOVING") {
                    // instruct others to follow
                    for (var i = 0; i < players.length; ++i) {
                        if (i != player.number) {
                            changePlayerState(players[i], "FOLLOWING")

                            if (currentAxis) {
                                var goalPosition = player.x - player.lastPoseDelta + players[i].lastPoseDelta
                                players[i].setGoalPosition(goalPosition, players[i].y, config.linearVelocity)
                            }
                            else {
                                var goalPosition = player.y - player.lastPoseDelta + players[i].lastPoseDelta
                                players[i].setGoalPosition(players[i].x, goalPosition, config.linearVelocity)
                            }
                        }
                    }
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
