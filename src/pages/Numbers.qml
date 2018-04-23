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
    property var ledColors: ["#0000FF", "#00FF00", "#FFFF00", "#FF00FF"]
    property int mobilePlayerIndex: -1
    property int leadingPlayerIndex: -1
    property int animationProgress: 0

    property var gameTransitions: {
        "IDLE": [
            "INIT"
        ],
        "INIT": [
            "RUNNING"
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
            "READY"
        ],
        "READY": [
            "FOLLOWING", 
            "LEADING", 
            "STATIC", 
            "MOVING", 
            "CELEBRATING",
            "IDLE"
        ],
        "FOLLOWING": [
            "READY",
            "IDLE"
        ],
        "LEADING": [
            "READY", 
            "IDLE"
        ],
        "STATIC": [
            "READY", 
            "IDLE"
        ],
        "MOVING": [
            "OUT", 
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

    Timer {
        id: gameTimer
        interval: config.gameLength * 1e3
        onTriggered: endGame()
    }

    Timer {
        id: updateTimer
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
                endGame()
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

            if (animationProgress < count) {
                animationTimer.restart()
            }
            else {
             chooseNewTargetZones()
            }

            for (var i = 0; i < players.length; ++i) {
                if (animationProgress >= count) {
                    changePlayerState(players[i], "READY");
                }
                else {
                    players[i].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, ledColors[animationProgress % ledColors.length], 0)
                }
            }
        }
    }

    function randomInt(min, max) {
        min = Math.ceil(min)
        max = Math.floor(max)
        return Math.floor(Math.random() * (max - min)) + min
    }

    function chooseNewTargetZones() {
        var occupiedZones = []

        for (var i = 0; i < players.length; ++i) {
            var oldTargetZone = players[i].targetZone
            var neighbors = map.data["neighborNumbers"][oldTargetZone-1]

            players[i].targetZone = neighbors[randomInt(0, neighbors.length)]
            // while(find(occupiedZones, players[i].targetZone) != -1) {
            //     players[i].targetZone = neighbors[randomInt(0, neighbors.length)]
            // }
            
            console.log("Player " + i + " changed target zone from " + oldTargetZone + " to " + players[i].targetZone)

            applyEffectToLeds(players[i], players[i].targetZone, CelluloBluetoothEnums.VisualEffectConstSingle, players[i].ledColor)
        }
    }

    function find(list, element) {
        for (var i = 0; i < list.length; ++i)
            if (list[i] === element)
                return i

        return -1
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

    function endGame() {
        for (var i = 0; i < players.length; ++i) {
            changePlayerState(players[i], "IDLE")
        }

        changeGameState("IDLE")
    }

    function changeGameState(newState) {
        if (gameState == newState)
            return

        console.assert(find(gameTransitions[gameState], newState) != -1)
        console.log("Game state changed from " + gameState + " to " + newState)

        if (newState == "INIT") {
            zoneEngine.active = true
        }
        else if (newState == "RUNNING") {
            updateTimer.start()
        }
        else if (newState == "IDLE") {
            zoneEngine.active = false
            updateTimer.stop()
            updateTimer.startTime = 0

        }

        gameState = newState
    }

    function changePlayerState(player, newState) {
        if (player.state == newState)
            return

        console.log("Player " + player.number + " state changed from " + player.state + " to " + newState)
        console.assert(find(playerTransitions[player.state], newState) != -1)

        switch (player.state) {
            case "IDLE":
            if (newState == "INIT") {
                player.lastPosition = Qt.vector2d(
                    map.initialPositions[player.number].x,
                    map.initialPositions[player.number].y
                )
                player.currentPosition = Qt.vector2d(
                    player.x,
                    player.y
                )
                player.lastPoseDelta = Qt.vector2d(
                    map.initialPositions[player.number].x - map.initialPositions[0].x, 
                    map.initialPositions[player.number].y - map.initialPositions[0].y
                )
                player.currentPoseDelta = Qt.vector2d(
                    player.lastPoseDelta.x, 
                    player.lastPoseDelta.y
                )

                console.log("Player " + player.number + ": setting goal to " + player.lastPosition.x + ", " + player.lastPosition.y + ", " + config.linearVelocity)

                player.setGoalPosition(
                    player.lastPosition.x, 
                    player.lastPosition.y, 
                    config.linearVelocity
                )

                player.setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, "#FFFFFF", 10)
            }
            break
        
            case "INIT":
            if (newState == "IDLE") {
                player.setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, "#000000", 0)
            }
            else if (newState == "READY") {
                var initializing = findPlayersInState("INIT")
                if (initializing.length == 1) {
                    chooseNewTargetZones()
                    changeGameState("RUNNING")
                }
            }
            break
        
            case "READY":
            if (newState == "IDLE") {
                player.setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, "#000000", 0)
            }
            else if (newState == "STATIC") {
                player.setVisualEffect(CelluloBluetoothEnums.VisualEffectWaiting, player.ledColor, 0)

                var staticPlayers = findPlayersInState("STATIC")
                if (staticPlayers.length == (players.length - 2)) {
                    var readyPlayers = findPlayersInState("READY")
                    for (var i = 0; i < readyPlayers.length; ++i) {
                        if (readyPlayers[i] != player)
                            changePlayerState(readyPlayers[i], "MOVING")
                    }
                }
            }
            else if (newState == "MOVING") {
                player.blinkPeriod = 40
                player.setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, player.ledColor, player.blinkPeriod)
            }
            else if (newState == "CELEBRATING") {
                animationProgress = 0
                animationTimer.restart()
            }
            break

            case "FOLLOWING":
            if (newState == "READY") {
                var followers = findPlayersInState("FOLLOWING")
                if (followers.length == 1) {
                    var leader = findPlayersInState("LEADING")
                    console.assert(leader.length == 1)
                    changePlayerState(leader[0], "READY")
                }
            }
        
            case "STATIC":
            if (newState == "IDLE") {
                player.setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, "#000000", 0)
            }
            else if (newState == "READY") {
                var mover = findPlayersInState("MOVING")
                if (mover.length > 0) {
                    changePlayerState(mover[0], "READY")
                }
            }
            break
            
            case "MOVING":
            if (newState == "IDLE") {
                player.setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, "#000000", 0)
            }
            else if (newState == "OUT") {
                player.blinkPeriod = 5
                player.setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, "#FF0000", player.blinkPeriod)
                player.simpleVibrate(300, 300, 6.28, 200, 300)
                player.setGoalPosition(player.lastPosition.x, player.lastPosition.y, config.linearVelocity)
            }
            else if (newState == "READY") {
                // modify pose
                player.lastPosition = player.currentPosition
                for (var i = 0; i < players.length; ++i)
                    players[i].lastPoseDelta = players[i].currentPosition.minus(players[0].currentPosition)
            }
            break
        
            case "OUT":
            if (newState == "IDLE") {
                player.setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, "#000000", 0)
            }
            break
        }

        player.state = newState

        if (player.state == "READY") {
            player.blinkPeriod = 0
            applyEffectToLeds(player, player.targetZone, CelluloBluetoothEnums.VisualEffectConstSingle, player.ledColor)

            checkZones()
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

                console.log("Player " + player.number + " current zones: " + JSON.stringify(player.currentZones))
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
                if (player.kidnapped == false) {
                    if (player.state == "READY")
                        changePlayerState(player, "STATIC")
                    else if (player.state == "STATIC")
                        changePlayerState(player, "READY")
                }
            }
        }
    }

    function trackingGoalReached(player) {
        return function() {
            player.clearTracking()

            if (player.state == "INIT") {
                console.log("Player " + player.number + " position initialized.")
                changePlayerState(player, "READY")
            }
            else {
                player.lastPosition = player.currentPosition

                if (player.state == "FOLLOWING") {
                    changePlayerState(player, "READY")
                }
                else if (player.state == "OUT") {
                    changePlayerState(player, "READY")
                }
            }
        }
    }

    function poseChanged(player) {
        return function() {
            if (gameState != "IDLE") {
                player.currentPosition = Qt.vector2d(player.x, player.y)
                player.currentPoseDelta = player.currentPosition.minus(players[0].currentPosition)
            }

            if (gameState == "RUNNING") {
                if (player.state == "READY") {
                    var staticPlayers = findPlayersInState("STATIC")
                    if (staticPlayers.length > 0) {
                        if (staticPlayers.length == players.length - 1) {
                            changePlayerState(player, "MOVING")
                        }
                        else {
                            player.setGoalPosition(player.lastPosition.x, player.lastPosition.y, linearVelocity)
                        }
                    }
                    else {
                        var positionDelta = player.currentPosition.minus(player.lastPosition)
                        var absoluteDelta = Math.sqrt(positionDelta.dotProduct(positionDelta))

                        // assume leader position after moving far enough
                        if (absoluteDelta > config.leadPoseDelta) {
                            changePlayerState(player, "LEADING")
                        }
                    }
                }
                else if (player.state == "LEADING") {
                    // instruct others to follow
                    for (var i = 0; i < players.length; ++i) {
                        if (i != player.number) {
                            changePlayerState(players[i], "FOLLOWING")
                            var goalPosition = player.currentPosition.minus(player.lastPoseDelta).plus(players[i].lastPoseDelta)
                            players[i].setGoalPosition(goalPosition.x, goalPosition.y, config.linearVelocity)
                        }
                    }

                    player.lastPosition = player.currentPosition
                }
                else if (player.state == "STATIC") {
                    player.setGoalPosition(player.lastPosition.x, player.lastPosition.y, config.linearVelocity)
                }
                else if (player.state == "MOVING") {
                    // limit free movement
                    var positionDelta = player.currentPosition.minus(player.lastPosition)
                    var absoluteDelta = Math.sqrt(positionDelta.dotProduct(positionDelta))

                    if (absoluteDelta > config.maxMoveDistance) {
                        changePlayerState(player, "OUT")
                    }
                    else {
                        var blinkPeriod = player.blinkPeriod
                        if (absoluteDelta > 0.9 * config.maxMoveDistance)
                            blinkPeriod = 10
                        else if (absoluteDelta > 0.7 * config.maxMoveDistance)
                            blinkPeriod = 20
                        else if (absoluteDelta > 0.5 * config.maxMoveDistance)
                            blinkPeriod = 40

                        if (blinkPeriod != player.blinkPeriod) {
                            player.blinkPeriod = blinkPeriod
                            player.setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, player.ledColor, player.blinkPeriod)
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
            return
        }
        else if (players.length > map.maxPlayers) {
            toast.show("Maximum number of players exceeded (maximum: " + map.maxPlayers + ", current: " + players.length + ")")
            return
        }

        console.log("Starting game with " + players.length + " players")

        zoneEngine.clearZones()
        zoneEngine.addNewZones(map.zones)

        changeGameState("INIT")

        for (var i = 0; i < players.length; ++i) {
            players[i].zoneValueChanged.connect(zoneValueChanged(players[i]))
            players[i].kidnappedChanged.connect(kidnappedChanged(players[i]))
            players[i].trackingGoalReached.connect(trackingGoalReached(players[i]))
            players[i].poseChanged.connect(poseChanged(players[i]))
            players[i].ledColor = ledColors[i]
            players[i].targetZone = 6 - i
            players[i].currentZones = []

            changePlayerState(players[i], "INIT")

            zoneEngine.addNewClient(players[i])
        }
    }
}
