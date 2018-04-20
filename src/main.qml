import QtQuick 2.7
import QtQuick.Window 2.2
import QtQuick.Controls 2.3
import QtQml.Models 2.2
import QtQuick.Dialogs 1.3

import Cellulo 1.0
import QMLCache 1.0
import QMLBluetoothExtras 1.0
import QMLRos 1.0

import ch.epfl.chili.fileio 1.0

import "./pages"

ApplicationWindow {
    id: root
    visible: true

    property bool mobile: Qt.platform.os === "android"
    width: mobile ? Screen.width : 1080
    height: mobile ? Screen.height : 720

    property bool userClosing: false

    title: "SiameseTwins"

    // // will be loaded from config file
    // property real mapPhysicalWidth;
    // property real mapPhysicalHeight;
    // property real linearVelocity;
    // property int maxPlayerCount;
    // property real maxMoveDistance;
    // property var gameData;

    // // shared game state
    // property string gameState: "IDLE"
    // property int playerCount: 2
    // property var players: []
    // property var playerStates: ["IDLE", "IDLE", "IDLE", "IDLE"]
    // property var currentZones: [6, 5, 4]
    // property var targetZones: []
    // property var ledColors: ["#0000FF", "#00FF00", "#FFFF00", "#FF00FF"]
    // property var initialPositions: []
    // property var lastPositions: []
    // property var currentPositions: []
    // property var lastPoseDeltas: []
    // property var currentPoseDeltas: []
    // property int mobilePlayerIndex: -1
    // property int leadingPlayerIndex: -1

    // property var gameTransitions: {
    //     "IDLE": [
    //         "INIT"
    //     ],
    //     "INIT": [
    //         "RUNNING"
    //     ],
    //     "RUNNING": [
    //         "IDLE"
    //     ]
    // }

    // property var playerTransitions: {
    //     "IDLE": [
    //         "INIT"
    //     ],
    //     "INIT": [
    //         "READY"
    //     ],
    //     "READY": [
    //         "FOLLOWING", 
    //         "LEADING", 
    //         "STATIC", 
    //         "MOVING", 
    //         "IDLE"
    //     ],
    //     "FOLLOWING": [
    //         "READY",
    //         "IDLE"
    //     ],
    //     "LEADING": [
    //         "READY", 
    //         "IDLE"
    //     ],
    //     "STATIC": [
    //         "READY", 
    //         "IDLE"
    //     ],
    //     "MOVING": [
    //         "OUT", 
    //         "READY", 
    //         "IDLE"
    //     ],
    //     "OUT": [
    //         "READY", 
    //         "IDLE"
    //     ]
    // }

    // ToastManager {
    //     id: toast
    // }    

    // FileIo {
    //     id: fileIo
    //     visible: false
    // }

    // CelluloZoneEngine {
    //     id: zoneEngine

    //     active: gameState == "RUNNING"
    // }

    // CelluloBluetoothScanner {
    //     id: scanner
    //     onRobotDiscovered: {
    //         var newAddresses = robotRepeater.addresses;
    //         if(newAddresses.indexOf(macAddr) < 0){
    //             toast.show(macAddr + " discovered.");
    //             newAddresses.push(macAddr);
    //             newAddresses.sort();
    //         }
    //         robotRepeater.addresses = newAddresses;
    //         QMLCache.write("addresses", robotRepeater.addresses.join(','));
    //     }
    // }

    // function randomInt(min, max) {
    //   min = Math.ceil(min);
    //   max = Math.floor(max);
    //   return Math.floor(Math.random() * (max - min)) + min;
    // }

    // function chooseNewTargetZones() {
    //     for (var i = 0; i < playerCount; ++i) {
    //         var neighbors = gameData["neighborNumbers"][currentZones[i]-1];
    //         targetZones[i] = neighbors[randomInt(0, neighbors.length)];
    //         applyEffectToLeds(players[i], targetZones[i], CelluloBluetoothEnums.VisualEffectConstSingle, ledColors[i]);
    //     }
    // }

    // function contains(list, element) {
    //     for (var i = 0; i < list.length; ++i)
    //         if (list[i] === element)
    //             return true;

    //     return false;
    // }

    // function applyEffectToLeds(player, ledCount, effect, color) {
    //     console.log("Player " + player.number + " chose number " + ledCount);
    //     for (var i = 0; i < ledCount; ++i) {
    //         player.setVisualEffect(effect, color, i);
    //     }
    //     for (var i = ledCount; i < 6; ++i) {
    //         player.setVisualEffect(effect, "#000000", i);
    //     }
    // }

    // function respondToZoneChange(robot, zone, value) {
    //     if (value == 1) {
    //         console.log("Player " + robot.number + " entered zone " + zone.name);
    //         currentZones[robot.number] = gameData["zoneNumbers"][zone.name];

    //         var allPlayersInTargetZone = true;
    //         for (var i = 0; i < playerCount; ++i) {
    //             if (currentZones[i] != targetZones[i])
    //                 allPlayersInTargetZone = false;
    //         }

    //         if (allPlayersInTargetZone) {
    //             chooseNewTargetZones();
    //         }
    //     }
    //     else {
    //         currentZones[robot.number] = null;
    //         console.log("Player " + robot.number + " left zone " + zone.name);
    //     }
    // }

    // function loadMap(name) {
    //     console.log("Loading map " + name + "...");

    //     fileIo.path = ":/assets/" + name + "-config.json";
    //     var config = JSON.parse(fileIo.readAll());

    //     mapPhysicalWidth = config["physicalWidth"];
    //     mapPhysicalHeight = config["physicalHeight"];
    //     linearVelocity = config["linearVelocity"];
    //     maxPlayerCount = config["maxPlayerCount"];
    //     maxMoveDistance = config["maxMoveDistance"];
    //     gameData = config["data"];

    //     var positions = config["initialPositions"];
    //     initialPositions = [];
    //     for (var i = 0; i < positions.length; ++i) {
    //         initialPositions.push(Qt.vector2d(positions[i][0], positions[i][1]));
    //         console.log("Initial position " + i + ": " + initialPositions[i].x + ", " + initialPositions[i].y);
    //     }

    //     if (playerCount > maxPlayerCount) playerCount = maxPlayerCount;

    //     zoneEngine.clearZones();
    //     var zones = CelluloZoneJsonHandler.loadZonesQML(":/assets/" + name + "-zones.json");
    //     zoneEngine.addNewZones(zones);

    //     // for (var i = 0; i < zones.length; ++i) {
    //     //     zones[i].createPaintedItem(zonesPaintedItem, "#80FF0000", mapPhysicalWidth, mapPhysicalHeight);
    //     // }
    // }

    // function findPlayersInState(state) {
    //     var found = [];
    //     for (var i = 0; i < playerCount; ++i)
    //         if (playerStates[i] == state)
    //             found.push(i);

    //     return found;
    // }

    // function changeGameState(newState) {
    //     if (gameState == newState)
    //         return;

    //     console.assert(contains(gameTransitions[gameState], newState));
    //     console.log("Game state changed from " + gameState + " to " + newState);

    //     if (newState == "INIT") {
    //         for (var i = 0; i < playerCount; ++i)
    //             changePlayerState(i, "INIT");
    //     }

    //     gameState = newState;
    // }

    // function changePlayerState(index, newState) {
    //     if (playerStates[index] == newState)
    //         return;

    //     console.assert(contains(playerTransitions[playerStates[index]], newState));
    //     console.log("Player " + index + " state changed from " + playerStates[index] + " to " + newState);

    //     switch (playerStates[index]) {
    //         case "IDLE":
    //         if (newState == "INIT") {
    //             players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, "#FFFFFF", 10);
    //         }
    //         break;
        
    //         case "INIT":
    //         if (newState == "IDLE") {
    //             players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, "#000000", 0);
    //         }
    //         else {
    //             applyEffectToLeds(players[index], targetZones[index], CelluloBluetoothEnums.VisualEffectConstSingle, ledColors[index]);
    //             // players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, ledColors[index], 0);

    //             var initializing = findPlayersInState("INIT");
    //             if (initializing.length == 1) {
    //                 changeGameState("RUNNING");
    //             }
    //         }
    //         break;
        
    //         case "READY":
    //         if (newState == "IDLE") {
    //             players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, "#000000", 0);
    //         }
    //         else if (newState == "STATIC") {
    //             players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectWaiting, ledColors[index], 0);

    //             var staticPlayers = findPlayersInState("STATIC");
    //             if (staticPlayers.length == (playerCount - 2)) {
    //                 var readyPlayers = findPlayersInState("READY");
    //                 for (var i = 0; i < readyPlayers.length; ++i) {
    //                     if (readyPlayers[i] != index)
    //                         changePlayerState(readyPlayers[i], "MOVING");
    //                 }
    //             }
    //         }
    //         else if (newState == "MOVING") {
    //             players[index].blinkPeriod = 40;
    //             players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, ledColors[index], players[index].blinkPeriod);
    //         }
    //         break;
        
    //         case "STATIC":
    //         if (newState == "IDLE") {
    //             players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, "#000000", 0);
    //         }
    //         else if (newState == "READY") {
    //             applyEffectToLeds(players[index], targetZones[index], CelluloBluetoothEnums.VisualEffectConstSingle, ledColors[index]);
    //             // players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, ledColors[index], 0);

    //             var mover = findPlayersInState("MOVING");
    //             if (mover.length > 0) {
    //                 changePlayerState(mover[0], "READY");
    //             }
    //         }
    //         break;
            
    //         case "MOVING":
    //         if (newState == "IDLE") {
    //             players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, "#000000", 0);
    //         }
    //         else if (newState == "OUT") {
    //             players[index].blinkPeriod = 5;
    //             players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, "#FF0000", players[index].blinkPeriod);
    //             players[index].simpleVibrate(300, 300, 6.28, 200, 300);
    //             players[index].setGoalPosition(lastPositions[index].x, lastPositions[index].y, linearVelocity);
    //         }
    //         else {
    //             applyEffectToLeds(players[index], targetZones[index], CelluloBluetoothEnums.VisualEffectConstSingle, ledColors[index]);
    //             // players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, ledColors[index], 0);
    //             players[index].blinkPeriod = 0;

    //             // modify pose
    //             lastPositions[index] = currentPositions[index];
    //             for (var i = 0; i < playerCount; ++i)
    //                 lastPoseDeltas[i] = currentPositions[i].minus(currentPositions[0]);
    //         }
    //         break;
        
    //         case "OUT":
    //         if (newState == "IDLE") {
    //             players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, "#000000", 0);
    //         }
    //         else if (newState == "READY") {
    //             applyEffectToLeds(players[index], targetZones[index], CelluloBluetoothEnums.VisualEffectConstSingle, ledColors[index]);
    //             // players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, ledColors[index], 0);
    //             players[index].blinkPeriod = 0;
    //         }
    //         break;
    //     }

    //     var newPlayerStates = playerStates;
    //     newPlayerStates[index] = newState;
    //     playerStates = newPlayerStates;
    // }

    // Column {
    //     id: robotLayout
    //     spacing: 8

    //     Repeater {
    //         id: robotRepeater
    //         visible: true
    //         model: playerCount

    //         property var addresses: QMLCache.read("addresses").split(",")

    //         delegate: Column {
    //             padding: 8
    //             spacing: 8

    //             Row {
    //                 spacing: 5
    //                 Label {
    //                     id: playerLabel
    //                     text: "Player " + (index + 1)
    //                     font.bold: true
    //                     font.pointSize: 14
    //                     color: ledColors[index]
    //                 }
    //                 MacAddrSelector {
    //                     id: macAddrSelector
    //                     addresses: robotRepeater.addresses
    //                     onConnectRequested: {
    //                         robot.localAdapterMacAddr = selectedLocalAdapterAddress;
    //                         robot.macAddr = selectedAddress;
    //                     }
    //                     onDisconnectRequested: robot.disconnectFromServer()
    //                     connectionStatus: robot.connectionStatus
    //                 }
    //             }

    //             CelluloRobot {
    //                 id: robot
    //                 property string type: "cellulo"
    //                 property int number: index
    //                 property real blinkPeriod: 0

    //                 onMacAddrChanged: QMLCache.write("Robot" + (index) + "MacAddr", macAddr)

    //                 onKidnappedChanged: {
    //                     // rosNode.publishKidnapped(robot.macAddr, robot.kidnapped)
    //                     if (gameState == "RUNNING") {
    //                         if (robot.kidnapped == false) {
    //                             if (playerStates[index] == "READY")
    //                                 changePlayerState(index, "STATIC");
    //                             else if (playerStates[index] == "STATIC")
    //                                 changePlayerState(index, "READY");
    //                         }
    //                     }
    //                 }

    //                 onLongTouch: {
    //                     // rosNode.publishLongTouch(robot.macAddr, key)
    //                 }

    //                 onTouchBegan: {
    //                     // rosNode.publishTouchStart(robot.macAddr, key)
    //                 }

    //                 onTouchReleased:  {
    //                     // rosNode.publishTouchEnd(robot.macAddr, key)
    //                 }

    //                 onZoneValueChanged: respondToZoneChange(robot, zone, value)

    //                 onTrackingGoalReached: {
    //                     players[index].clearTracking();

    //                     if (playerStates[index] == "INIT") {
    //                         console.log("Player " + index + " position initialized.");
    //                         changePlayerState(index, "READY");
    //                         chooseNewTargetZones();
    //                     }
    //                     else {
    //                         lastPositions[index] = currentPositions[index];

    //                         if (playerStates[index] == "FOLLOWING") {
    //                             changePlayerState(index, "READY");
    //                             var followers = findPlayersInState("FOLLOWING");
    //                             if (followers.length == 0) {
    //                                 var leader = findPlayersInState("LEADING");
    //                                 console.assert(leader.length == 1);
    //                                 changePlayerState(leader, "READY");
    //                             }
    //                         }
    //                         else if (playerStates[index] == "OUT") {
    //                             changePlayerState(index, "READY");
    //                         }
    //                     }
    //                 }

    //                 onPoseChanged: {
    //                     if (gameState != "IDLE") {
    //                         currentPositions[index] = Qt.vector2d(players[index].x, players[index].y);
    //                         currentPoseDeltas[index] = currentPositions[index].minus(currentPositions[0]);
    //                     }

    //                     if (gameState == "RUNNING") {
    //                         if (playerStates[index] == "INIT") {
    //                             players[index].setGoalPosition(initialPositions[index].x, initialPositions[index].y);
    //                         }
    //                         else if (playerStates[index] == "READY") {
    //                             var staticPlayers = findPlayersInState("STATIC");
    //                             if (staticPlayers.length > 0) {
    //                                 if (staticPlayers.length == playerCount - 1) {
    //                                     changePlayerState(index, "MOVING");
    //                                 }
    //                                 else {
    //                                     players[index].setGoalPosition(lastPositions[index].x, lastPositions[index].y, linearVelocity);
    //                                 }
    //                             }
    //                             else {
    //                                 var positionDelta = currentPositions[index].minus(lastPositions[index]);
    //                                 var absoluteDelta = Math.sqrt(positionDelta.dotProduct(positionDelta));

    //                                 // assume leader position after moving far enough
    //                                 if (absoluteDelta > 30.0) {
    //                                     changePlayerState(index, "LEADING");
    //                                 }
    //                             }
    //                         }
    //                         else if (playerStates[index] == "LEADING") {
    //                             // instruct others to follow
    //                             for (var i = 0; i < playerCount; ++i) {
    //                                 if (i != index) {
    //                                     changePlayerState(i, "FOLLOWING");
    //                                     var goalPosition = currentPositions[index].minus(lastPoseDeltas[index]).plus(lastPoseDeltas[i]);
    //                                     players[i].setGoalPosition(goalPosition.x, goalPosition.y, linearVelocity);
    //                                 }
    //                             }

    //                             lastPositions[index] = currentPositions[index];
    //                         }
    //                         else if (playerStates[index] == "STATIC") {
    //                             players[index].setGoalPosition(lastPositions[index].x, lastPositions[index].y, linearVelocity);
    //                         }
    //                         else if (playerStates[index] == "MOVING") {
    //                             // limit free movement
    //                             var positionDelta = currentPositions[index].minus(lastPositions[index]);
    //                             var absoluteDelta = Math.sqrt(positionDelta.dotProduct(positionDelta));

    //                             if (absoluteDelta > maxMoveDistance) {
    //                                 changePlayerState(index, "OUT");
    //                             }
    //                             else {
    //                                 var blinkPeriod = players[index].blinkPeriod;
    //                                 if (absoluteDelta > 0.9 * maxMoveDistance)
    //                                     blinkPeriod = 10;
    //                                 else if (absoluteDelta > 0.7 * maxMoveDistance)
    //                                     blinkPeriod = 20;
    //                                 else if (absoluteDelta > 0.5 * maxMoveDistance)
    //                                     blinkPeriod = 40;

    //                                 if (blinkPeriod != players[index].blinkPeriod) {
    //                                     players[index].blinkPeriod = blinkPeriod;
    //                                     players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, ledColors[index], players[index].blinkPeriod);
    //                                 }
    //                             }
    //                         }
    //                     }

    //                     // rosNode.publishPose(robot.macAddr, robot.x, robot.y, robot.theta)
    //                 }

    //                 // RosNode {
    //                 //     id: rosNode
    //                 // }
    //             }
    //         }

    //         onItemAdded: {
    //             for (var i = 0; i < item.children.length; ++i) {
    //                 var child = item.children[i];
    //                 if (child.type == "cellulo")
    //                     players[child.number] = child;
    //             }
    //         }
    //     }

    //     Row {
    //         padding: 8
    //         spacing: 5

    //         Button{
    //             id: scanButton
    //             text: "Scan"
    //             onClicked: scanner.start()
    //         }

    //         BusyIndicator{
    //             running: scanner.scanning
    //             height: scanButton.height
    //         }

    //         Button{
    //             text: "Clear List"
    //             onClicked: {
    //                 robotRepeater.addresses = [];
    //                 QMLCache.write("addresses","");
    //             }
    //         }
    //     }

    //     Row {
    //         padding: 8
    //         spacing: 8

    //         ComboBox {
    //             id: mapListComboBox
    //             currentIndex: 1
    //             enabled: gameState == "IDLE"
    //             model: ListModel {
    //                 id: mapListItems
    //                 ListElement { text: "Numbers (A3, 2-3 players)"; name: "a3-numbers"; }
    //                 ListElement { text: "Easymaze (A3, 2 players)"; name: "a3-easymaze"; }
    //                 ListElement { text: "Colors (A4, 2 players)"; name: "a4-colors"; }
    //             }
    //             textRole: "text"
    //             width: 400
    //             onCurrentIndexChanged: loadMap(mapListItems.get(currentIndex).name)
    //         }

    //         Button {
    //             id: addPlayerButton
    //             text: "Add player"
    //             enabled: (gameState == "IDLE" && playerCount < maxPlayerCount)
    //             onClicked: playerCount += 1
    //         }

    //         Button {
    //             id: removePlayerButton
    //             text: "Remove player"
    //             enabled: (gameState == "IDLE" && playerCount > 2)
    //             onClicked: playerCount -= 1
    //         }

    //         Button{
    //             id: startButton
    //             text: "Start Game"
    //             onClicked: {
    //                 if (gameState == "IDLE") {
    //                     var allPlayersConnected = true;
    //                     for (var i = 0; i < playerCount; ++i) {
    //                         if (players[i].connectionStatus != CelluloBluetoothEnums.ConnectionStatusConnected)
    //                             allPlayersConnected = false;
    //                     }

    //                     if (!allPlayersConnected) {
    //                         toast.show("Cannot start game before both robots are connected!");
    //                         return;
    //                     }

    //                     changeGameState("INIT");

    //                     lastPositions = [];
    //                     lastPoseDeltas = [];
    //                     for (var i = 0; i < playerCount; ++i) {
    //                         changePlayerState(i, "INIT");

    //                         lastPositions.push(initialPositions[i]);
    //                         currentPositions.push(initialPositions[i]);
    //                         lastPoseDeltas.push(initialPositions[i].minus(initialPositions[0]));
    //                         currentPoseDeltas.push(lastPoseDeltas[i]);

    //                         players[i].setGoalPosition(initialPositions[i].x, initialPositions[i].y, linearVelocity);

    //                         zoneEngine.addNewClient(players[i]);
    //                     }

    //                     text = "Stop Game";
    //                 }
    //                 else {
    //                     for (var i = 0; i < playerCount; ++i) {
    //                         players[i].clearTracking();
    //                         changePlayerState(i, "IDLE");
    //                     }

    //                     gameState = "IDLE";

    //                     text = "Start Game";
    //                 }
    //             }
    //         }
    //     }
    // }


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
                text: qsTr("Start Game")
                width: parent.width
                onClicked: {
                    numbers.players = robotSettings.robots
                    stackView.push(numbers)
                    numbers.start()
                    drawer.close()
                    activityOn = true
                    // game.drawZones(game.alpha)
                }
            }

            ItemDelegate {
                text: qsTr("Game Settings")
                width: parent.width
                onClicked: {
                    stackView.push(gameSettings)
                    drawer.close()
                    activityOn = false
                }
            }

            ItemDelegate {
                text: qsTr("Robots Settings")
                width: parent.width
                onClicked: {
                    stackView.push(robotSettings)
                    drawer.close()
                    activityOn = false
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
