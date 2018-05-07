import QtQuick 2.7
import QtQuick.Window 2.2
import QtQuick.Controls 2.3
import QtQml.Models 2.2
import QtQuick.Dialogs 1.3
import QtQuick.Layouts 1.3

import Cellulo 1.0
import QMLCache 1.0
import QMLBluetoothExtras 1.0
import QMLRos 1.0
import QMLRosRecorder 1.0
import QMLFileIo 1.0

Page {
    id: root
    title: qsTr("Numbers")

    property var config
    property var map
    property var players
    property real timeLeft
    property bool mapChanged: false

    property string gameState: "IDLE"
    property int movesRequired: 0
    property int movesRemaining: 0
    property int targetZonesIndex: 0
    property int score: 0
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
        ],        
        "CHANGING": [
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

    RosNode {
        id: rosNode
    }

    RosRecorder {
        id: rosRecorder
    }

    QMLFileIo {
        id: fileIo
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
                height: 0.20 * parent.height
                font.pixelSize: 0.5 * height
            }
            
            Text {
                id: movesRemainingText
                anchors.horizontalCenter: parent.horizontalCenter
                verticalAlignment: Text.AlignVCenter
                height: 0.25 * parent.height
                text: "Moves left: " + String(movesRemaining)
                font.pixelSize: 0.5 * height
            }
            
            Text {
                id: movesRequiredText
                anchors.horizontalCenter: parent.horizontalCenter
                verticalAlignment: Text.AlignVCenter
                height: 0.25 * parent.height
                text: "Best solution: " + String(movesRequired)
                font.pixelSize: 0.5 * height
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                verticalAlignment: Text.AlignVCenter
                height: 0.3 * parent.height
                text: "Score: " + score
                font.pixelSize: 0.5 * height
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

            timeLeft = config.gameLength - 1e-3 * (new Date().getTime() - startTime)

            if (timeLeft <= 0) {
                timeRemainingText.text = "Game Over!"
                stop()
            } else {
                publishGameInfo("time_remaining", timeLeft)
                timeRemainingText.text = "Time left: " + timeLeft.toFixed(2)
            }
        }
    }

    Timer {
        id: celebrationTimer
        interval: 5e2

        property int count: 6
        onTriggered: {
            animationProgress += 1

            if (animationProgress > count) {
                animationProgress = 0
                loadNextTargetZones()

                for (var i = 0; i < players.length; ++i) {
                    changePlayerState(players[i], "MOVING")
                }

                return
            }
            else {
                celebrationTimer.restart()

                for (var i = 0; i < players.length; ++i) {
                    var colorIndex = animationProgress % animationColors.length
                    players[i].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, animationColors[colorIndex], 0)
                }
            }
        }
    }

    Timer {
        id: changeTimer
        interval: 3e3

        onTriggered: {
            loadNextTargetZones()

            for (var i = 0; i < players.length; ++i) {
                changePlayerState(players[i], "MOVING")
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
        // fileIo.setPath("/home/florian/targets.json")
        // fileIo.write(JSON.stringify(generateTargetZoneList([4, 3], 100)))

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

        rosRecorder.stopRecording(config.bagName)
        
        timeRemainingText.text = null
        startStopButton.text = "Start game"
    }

    function publishPlayerInfo(player, subject, value) {
        if (config.recordSession && rosNode.status == "Running") {
            rosNode.publish("siamese_twins/player" + player.number + "/" + subject, player.macAddr, value)
        }
    }

    function publishGameInfo(subject, value) {
        if (config.recordSession && rosNode.status == "Running") {
            rosNode.publish("siamese_twins/" + subject, "GAME_INFO", value)
        }
    }

    function initializeRos() {
        if (rosNode.status == "Idle") {
            rosNode.startNode()
        }

        if (rosRecorder.status == "Idle") {
            rosRecorder.startNode()
            rosRecorder.topicsToRecord = [
                "/audio/audio",
                "/usb_cam/image_raw/compressed",
                "/siamese_twins/state",
                "/siamese_twins/score",
                "/siamese_twins/moves_required",
                "/siamese_twins/moves_remaining",
                "/siamese_twins/time_remaining",
                "/siamese_twins/player0/state",
                "/siamese_twins/player0/pose",
                "/siamese_twins/player0/kidnapped",
                "/siamese_twins/player0/target_zone",
                "/siamese_twins/player0/current_zone",
                "/siamese_twins/player0/next_zone",
                "/siamese_twins/player0/translation_attempted",
                "/siamese_twins/player0/translation_succeeded",
                "/siamese_twins/player0/translation_failed",
                "/siamese_twins/player0/rotation_attempted",
                "/siamese_twins/player0/rotation_succeeded",
                "/siamese_twins/player0/rotation_failed",
                "/siamese_twins/player1/state",
                "/siamese_twins/player1/pose",
                "/siamese_twins/player1/kidnapped",
                "/siamese_twins/player1/target_zone",
                "/siamese_twins/player1/current_zone",
                "/siamese_twins/player1/next_zone",
                "/siamese_twins/player1/translation_attempted",
                "/siamese_twins/player1/translation_succeeded",
                "/siamese_twins/player1/translation_failed",
                "/siamese_twins/player1/rotation_attempted",
                "/siamese_twins/player1/rotation_succeeded",
                "/siamese_twins/player1/rotation_failed"
            ]
        }

        rosRecorder.startRecording(config.bagName)

        publishGameInfo("state", gameState)
        publishGameInfo("score", score)
        publishGameInfo("moves_required", movesRequired)
        publishGameInfo("moves_remaining", movesRemaining)
        publishGameInfo("time_remaining", timeLeft)

        for (var i = 0; i < players.length; ++i) {
            var player = players[i]
            publishPlayerInfo(player, "state", player.state)
            publishPlayerInfo(player, "pose", Qt.vector3d(player.x, player.y, player.theta))
            publishPlayerInfo(player, "kidnapped", player.kidnapped)
            publishPlayerInfo(player, "target_zone", player.targetZone)
            publishPlayerInfo(player, "current_zone", map.data.zoneMatrix[player.currentZone[0]][player.currentZone[1]])
            publishPlayerInfo(player, "next_zone", map.data.zoneMatrix[player.nextZone[0]][player.nextZone[1]])
        }
    }

    function changeGameState(newState) {
        if (gameState == newState)
            return

        console.assert(find(gameTransitions[gameState], newState) != -1)
        console.log("Game state changed from " + gameState + " to " + newState)

        publishGameInfo("state", gameState)

        if (newState == "INIT") {
            targetZonesIndex = 0
            score = 0

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

                zoneEngine.addNewClient(players[i])

                changePlayerState(players[i], "INIT")
            }
        }
        else if (newState == "RUNNING") {
            gameTimer.start()

            if (config.recordSession) {
                initializeRos()
            }
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

        publishPlayerInfo(player, "state", player.state)

        switch (player.state) {
            case "IDLE":
            player.clearTracking()
            player.setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, "#000000", 0)
            player.simpleVibrate(0, 0, 0, 0, 0)
            break

            case "INIT":
            var initialZone = map.data.initialZones[player.number]
            player.nextZone = map.data.zoneMatrixIndices[initialZone]
            player.targetZone = map.data.zoneMatrix[player.nextZone[0]][player.nextZone[1]]
            player.setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, player.ledColor, 10)
            player.simpleVibrate(0, 0, 0, 0, 0)
            changePlayerState(player, "MOVING")
            break
        
            case "READY":
            if (gameState == "INIT" && areAllPlayersInState("READY")) {
                loadNextTargetZones()
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
            celebrationTimer.restart()
            break
        
            case "CHANGING":
            player.setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, player.ledColor, 10)
            changeTimer.restart()
            break

            case "MOVING":
            player.setCasualBackdriveAssistEnabled(false)
            moveToNextZone(player)

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
            if (areAllPlayersInTargetZone()) {
                if (movesRemainingText.color == "#000000") {
                    score += 1
                    for (var i = 0; i < players.length; ++i) {
                        changePlayerState(players[i], "CELEBRATING")
                    }

                    publishGameInfo("score", score)
                }
                else {
                    for (var i = 0; i < players.length; ++i) {
                        changePlayerState(players[i], "CHANGING")
                    }
                }
            }
            else {
                movesRequired = findMimimumMoves(8)
                console.log("Minimum moves: " + movesRequired)

                publishGameInfo("moves_required", movesRequired)

                if (movesRemaining <= 0) {
                    movesRemainingText.color = "#FF0000"
                }
            }
        }
    }

    function randomInt(min, max) {
        min = Math.ceil(min)
        max = Math.floor(max)
        return Math.floor(Math.random() * (max - min)) + min
    }

    function find(list, element) {
        console.assert(list != undefined, "List is undefined!")
        console.assert(element != undefined, "Element is undefined!")

        for (var i = 0; i < list.length; ++i)
            if (list[i] === element)
                return i

        return -1
    }

    function areArraysEqual(a, b) {
        console.assert(a != undefined && b != undefined, "Cannot compare for equality with undefined!")
        for (var i = 0; i < a.length; ++i) {
            if (a[i] != b[i]) {
                return false
            }
        }

        return true
    }

    function generateTargetZoneList(currentZones, count) {
        var i = 0
        var targetZones = []

        for (var j = 0; j < count; ++j) {
            targetZones.push([])
            for (var i = 0; i < currentZones.length; ++i) {
                var choice
                do {
                    choice = randomInt(1, map.data.logicalZoneCount + 1)
                } while (choice == currentZones[i] ||
                         find(targetZones[j], choice) != -1)

                targetZones[j].push(choice)
            }

            currentZones = targetZones[j]
        }

        return targetZones
    }

    function loadNextTargetZones() {
        var positions = []
        var targets = []

        for (var i = 0; i < players.length; ++i) {
            players[i].targetZone = map.data.targetZones[targetZonesIndex][i]
            displayTargetZoneWithLeds(players[i], CelluloBluetoothEnums.VisualEffectConstSingle, players[i].ledColor)
            publishPlayerInfo(players[i], "target_zone", players[i].targetZone)

            console.assert(players[i].currentZone != undefined, "Cannot compute moves remaining for players with unknown current zones!")
        }

        targetZonesIndex += 1

        movesRequired = movesRemaining = findMimimumMoves(8)
        movesRemainingText.color = "#000000"
        console.log("Minimum moves: " + movesRequired)

        publishGameInfo("moves_required", movesRequired)
        publishGameInfo("moves_remaining", movesRemaining)
    }

    function chooseNewTargetZones() {
        var newTargetZones = []

        for (var i = 0; i < players.length; ++i) {
            var choice
            do {
                choice = randomInt(1, map.data.logicalZoneCount + 1)
            } while (choice == players[i].targetZone ||
                     find(newTargetZones, choice) != -1)

            newTargetZones.push(choice)
        }

        for (var i = 0; i < players.length; ++i) {
            console.log("Player " + i + " changed target zone from " + players[i].targetZone + " to " + newTargetZones[i])
            players[i].targetZone = newTargetZones[i]
            displayTargetZoneWithLeds(players[i], CelluloBluetoothEnums.VisualEffectConstSingle, players[i].ledColor)
            publishPlayerInfo(players[i], "target_zone", players[i].targetZone)

            console.assert(players[i].currentZone != undefined, "Cannot compute moves remaining for players with unknown current zones!")
        }

        movesRequired = movesRemaining = findMimimumMoves(8)
        movesRemainingText.color = "#000000"
        console.log("Minimum moves: " + movesRequired)

        publishGameInfo("moves_required", movesRequired)
        publishGameInfo("moves_remaining", movesRemaining)
    }

    function areAllPlayersInTargetZone() {
        for (var i = 0; i < players.length; ++i) {
            if (players[i].currentZone == undefined) {
                return false
            }
            if (map.data.zoneMatrix[players[i].currentZone[0]][players[i].currentZone[1]] != players[i].targetZone) {
                return false
            }
        }

        return true
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

    function moveToNextZone(player) {
        var zoneName = map.data.zoneNameMatrix[player.nextZone[0]][player.nextZone[1]]
        var zone = map.zones[map.data.zoneJsonIndex[zoneName]]
        player.setGoalPosition(
            zone.x,
            zone.y,
            config.linearVelocity
        )
    }

    function zoneValueChanged(player) {
        return function(zone, value) {
            var zoneIndices = map.data.zoneMatrixIndices[zone.name]
            if (value == 1) {
                player.currentZone = zoneIndices
                publishPlayerInfo(player, "current_zone", map.data.zoneMatrix[player.currentZone[0]][player.currentZone[1]])
            }
            else if (player.currentZone != undefined) {
                if (areArraysEqual(zoneIndices, player.currentZone)) {
                    player.currentZone = undefined
                    publishPlayerInfo(player, "current_zone", 0)
                }
            }

            console.log("Player " + player.number + (value ? " entered " : " left ") + zone.name)
        }
    }

    function kidnappedChanged(player) {
        return function() {
            publishPlayerInfo(player, "kidnapped", player.kidnapped)

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

            player.currentZone = player.nextZone;
            changePlayerState(player, "READY")
        }
    }

    function poseChanged(player) {
        return function() {
            if (gameState == "RUNNING") {
                publishPlayerInfo(player, "pose", Qt.vector3d(player.x, player.y, player.theta))

                if (player.state == "READY") {
                    if (!areArraysEqual(player.currentZone, player.nextZone)) {
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
                        translate(player, [Math.sign(translation.x), 0])

                        if (movesRemaining > 0) {
                            movesRemaining -= 1
                            publishGameInfo("moves_remaining", movesRemaining)
                        }
                    }
                    else if (Math.abs(translation.y) > config.translationDelta) {
                        translate(player, [0, Math.sign(translation.y)])

                        if (movesRemaining > 0) {
                            movesRemaining -= 1
                            publishGameInfo("moves_remaining", movesRemaining)
                        }
                    }
                    else if (Math.abs(rotation) > config.rotationDelta) {
                        rotate(player, Math.sign(rotation))

                        if (movesRemaining > 0) {
                            movesRemaining -= 1
                            publishGameInfo("moves_remaining", movesRemaining)
                        }
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
                    var zoneName = map.data.zoneNameMatrix[player.nextZone[0]][player.nextZone[1]]
                    var zone = map.zones[map.data.zoneJsonIndex[zoneName]]
                    var distanceToCenter = Qt.vector2d(player.x - zone.x, player.y - zone.y)
                    if (distanceToCenter.dotProduct(distanceToCenter) < 15.0) {
                        trackingGoalReached(player)
                    }
                }
            }
        }
    }

    function translate(player, delta) {
        console.log("Trying to translate with delta = [" + delta[0] + ", " + delta[1] + "]")

        publishPlayerInfo(player, "translation_attempted", Qt.vector2d(delta[0], delta[1]))

        var blockers = []
        var newZones = []

        var positions = []
        for (var i = 0; i < players.length; ++i) {
            positions.push(players[i].currentZone)
        }

        var newPositions = findZonesAfterTranslation(map.data.zoneMatrix, delta, positions)
        for (var i = 0; i < newPositions.length; ++i) {
            if (newPositions[i][0] < 0 || newPositions[i][0] > map.data.zoneMatrix.length - 1 ||
                newPositions[i][1] < 0 || newPositions[i][1] > map.data.zoneMatrix[0].length - 1) {
                blockers.push(sorted[i])
            }
        }

        if (blockers.length == 0) {
            publishPlayerInfo(player, "translation_succeeded", Qt.vector2d(delta[0], delta[1]))

            for (var i = 0; i < players.length; ++i) {
                players[i].nextZone = newPositions[i]
                changePlayerState(players[i], "MOVING")
            }
        }
        else {
            publishPlayerInfo(player, "translation_failed", Qt.vector2d(delta[0], delta[1]))

            changePlayerState(player, "CANCELLING")
            for (var i = 0; i < blockers.length; ++i) {
                changePlayerState(blockers[i], "BLOCKING")
            }
        }
    }

    function rotate(player, delta) {
        console.log("Trying to rotate around player " + player.number + " with delta = " + delta)

        publishPlayerInfo(player, "rotation_attempted", delta)

        var blockers = []
        var newZoneIndices = []

        for (var i = 0; i < players.length; ++i) {
            newZoneIndices.push(findZoneAfterRotation(player.currentZone, delta, players[i].currentZone))

            if (newZoneIndices[i][0] < 0 || newZoneIndices[i][0] > map.data.zoneMatrix.length - 1 ||
                newZoneIndices[i][1] < 0 || newZoneIndices[i][1] > map.data.zoneMatrix[0].length - 1) {
                blockers.push(players[i])
            }
        }

        if (blockers.length == 0) {
            publishPlayerInfo(player, "rotation_succeeded", delta)

            for (var i = 0; i < players.length; ++i) {
                players[i].nextZone = newZoneIndices[i]
                changePlayerState(players[i], "MOVING")
            }
        }
        else {
            publishPlayerInfo(player, "rotation_failed", delta)

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
        for (var i = 0; i < players.length; ++i) {
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

    function findMimimumMoves(limit) {
        var zoneMatrix = map.data.zoneMatrix
        var positions = []
        var targets = []

        for (var i = 0; i < players.length; ++i) {
            positions.push(players[i].currentZone)
            targets.push(players[i].targetZone)
        }

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

        var tree = [ [ [initialPositions, -1] ] ]
        for (var d = 0; d < limit; ++d) {
            tree.push([])

            // compute possible next positions for all nodes at depth d
            for (var n = 0; n < tree[d].length; ++n) {
                var current = tree[d][n][0]
                var future = []

                // store rotations
                for (var i = 0; i < rotations.length; ++i) {
                    for (var j = 0; j < players.length; ++j) {
                        var next = []
                        for (var k = 0; k < players.length; ++k) {
                            next.push(findZoneAfterRotation(current[j], rotations[i], current[k]))    
                        }

                        next.push("rot([" + current[j][0] + "," + current[j][1] + "], " + rotations[i] + ")")

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
                    next.push("trans(" + String(translations[i][0]) + ", " + String(translations[i][1]) + ")")
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

                    for (var j = 0; j < players.length; ++j) {
                        if (future[i][j][0] >= 0 && future[i][j][0] < zoneMatrix.length &&
                            future[i][j][1] >= 0 && future[i][j][1] < zoneMatrix[0].length) {
                            if (zoneMatrix[future[i][j][0]][future[i][j][1]] != targets[j]) {
                                found = false
                            }
                        }
                        else {
                            accept = found = false
                        }
                    }
                    if (found) {
                        var path = [ [future[i], n] ]
                        var index = n
                        for (var level = d; level > 0; --level) {
                            path.push(tree[level][index])
                            index = tree[level][index][1]
                        }

                        console.log("Path to goal:")
                        for (var step = path.length - 1; step >= 0; --step) {
                            console.log(path.length - step)

                            for (var p = 0; p < players.length; ++p) {
                                console.log("[" + path[step][0][p][0] + ", " + path[step][0][p][1] + "]")
                            }

                            console.log("Op: " + path[step][0][players.length])
                        }
                        return d + 1
                    }
                    else if (accept) {
                        valid.push(future[i])
                    }
                }

                for (var i = 0; i < valid.length; ++i) {
                    tree[d + 1].push([valid[i], n])
                }
            }
        }

        return limit + 1
    }
}
