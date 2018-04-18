import QtQuick 2.7
import QtQuick.Window 2.1
import QtQuick.Layouts 1.1
import QtQuick.Controls 1.4
import QtQuick.Controls.Private 1.0
import QtQuick.Controls.Styles 1.3
import QtQuick.Dialogs 1.0

import Cellulo 1.0
import QMLCache 1.0
import QMLBluetoothExtras 1.0
import QMLRos 1.0

ApplicationWindow {
    id: root
    visible: true

    property bool mobile: Qt.platform.os === "android"
    width: mobile ? Screen.width : 840
    height: mobile ? Screen.height : 580

    title: "SiameseTwins"

    property string gameState: "IDLE"
    property int playerCount: 2
    property int maxPlayerCount: 4
    property var players: []
    property var playerStates: ["INIT", "INIT", "INIT", "INIT"]
    property var ledColors: ["#0000FF", "#00FF00", "#FFFF00", "#FF00FF"]
    property var initialPositions: [
        Qt.vector2d(45.0, 55.0),
        Qt.vector2d(145.0, 55.0),
        Qt.vector2d(245.0, 55.0),
        Qt.vector2d(345.0, 55.0)
    ]
    property var lastPositions: []
    property var currentPositions: []
    property var lastPoseDeltas: []
    property var currentPoseDeltas: []
    property int mobilePlayerIndex: -1
    property int leadingPlayerIndex: -1
    property real maximumVerticalDelta: 100.0
    property real linearVelocity: 200.0


    property var gameTransitions: {
        "IDLE": [
            "INIT"
        ],
        "INIT": [
            "RUNNING"
        ],
        "RUNNING": [
            "INIT"
        ]
    }

    property var playerTransitions: {
        "INIT": [
            "READY"
        ],
        "READY": [
            "FOLLOWING", 
            "LEADING", 
            "STATIC", 
            "MOVING", 
            "INIT"
        ],
        "FOLLOWING": [
            "READY",
            "INIT"
        ],
        "LEADING": [
            "READY", 
            "INIT"
        ],
        "STATIC": [
            "READY", 
            "INIT"
        ],
        "MOVING": [
            "OUT", 
            "READY", 
            "INIT"
        ],
        "OUT": [
            "READY", 
            "INIT"
        ]
    }

    function contains(list, element) {
        for (var i = 0; i < list.length; ++i)
            if (list[i] === element)
                return true;

        return false;
    }

    function findPlayersInState(state) {
        var found = [];
        for (var i = 0; i < playerCount; ++i)
            if (playerStates[i] == state)
                found.push(i);

        return found;
    }

    function changeGameState(newState) {
        if (gameState == newState)
            return;

        console.assert(contains(gameTransitions[gameState], newState));

        console.log("Game state changed from " + gameState + " to " + newState);

        if (newState == "INIT") {
            for (var i = 0; i < playerCount; ++i)
                changePlayerState(i, "INIT");
        }

        gameState = newState;
    }

    function changePlayerState(index, newState) {
        if (playerStates[index] == newState)
            return;

        console.assert(contains(playerTransitions[playerStates[index]], newState));

        console.log("Player " + index + " state changed from " + playerStates[index] + " to " + newState);

        if (playerStates[index] == "INIT") {
            players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, ledColors[index], 255);

            var initializing = findPlayersInState("INIT");
            if (initializing.length == 1)
                changeGameState("RUNNING");
        }
        else if (playerStates[index] == "READY") {
            if (newState == "STATIC") {
                players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectWaiting, ledColors[index], 0);

                var staticPlayers = findPlayersInState("STATIC");
                if (staticPlayers.length == (playerCount - 2)) {
                    var readyPlayers = findPlayersInState("READY");
                    for (var i = 0; i < readyPlayers.length; ++i) {
                        if (readyPlayers[i] != index)
                            changePlayerState(readyPlayers[i], "MOVING");
                    }
                }
            }
            else if (newState == "MOVING") {
                players[index].blinkPeriod = 80;
                players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, ledColors[index], players[index].blinkPeriod);
            }
        }
        else if (playerStates[index] == "STATIC") {
            if (newState == "READY") {
                players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, ledColors[index], 255);

                var mover = findPlayersInState("MOVING");
                if (mover.length > 0) {
                    changePlayerState(mover[0], "READY");
                }
            }
        }
        else if (playerStates[index] == "MOVING") {
            if (newState == "OUT") {
                players[index].blinkPeriod = 5;
                players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, "#FF0000", players[index].blinkPeriod);
                players[index].simpleVibrate(300, 300, 6.28, 200, 300);
                players[index].setGoalPosition(lastPositions[index].x, lastPositions[index].y, linearVelocity);
            }
            else {
                players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, ledColors[index], 0);
                players[index].blinkPeriod = 0;

                // modify pose
                lastPositions[index] = currentPositions[index];
                for (var i = 0; i < playerCount; ++i)
                    lastPoseDeltas[i] = currentPositions[i].minus(currentPositions[0]);
            }
        }
        else if (playerStates[index] == "OUT") {
            players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, ledColors[index], 0);
            players[index].blinkPeriod = 0;
        }

        var newPlayerStates = playerStates;
        newPlayerStates[index] = newState;
        playerStates = newPlayerStates;
    }

    Column {
        id: robotLayout
        spacing: 8

        Repeater {
            id: robotRepeater
            visible: true
            model: playerCount

            property var addresses: QMLCache.read("addresses").split(",")

            delegate: Column {
                padding: 8
                spacing: 8

                Row {
                    spacing: 5
                    Button {
                        text: "Change color..."
                        onClicked: {
                            colorDialog.color = ledColors[index];
                            colorDialog.visible = true;
                        }

                        enabled: gameState == "IDLE";
                    }
                    ColorDialog {
                        id: colorDialog
                        title: "Please choose a LED color"
                        color: ledColors[index]

                        function updateColor(newColor) {
                            var newLedColors = ledColors;
                            newLedColors[index] = newColor;
                            ledColors = newLedColors;
                        }

                        onAccepted: updateColor(color)
                        onCurrentColorChanged: updateColor(currentColor)
                        visible: false
                    }
                    Label {
                        id: playerLabel
                        text: "Player " + (index + 1)
                        font.bold: true
                        font.pointSize: 14
                        color: ledColors[index]
                    }
                    MacAddrSelector {
                        id: macAddrSelector
                        addresses: robotRepeater.addresses
                        onConnectRequested: {
                            robot.localAdapterMacAddr = selectedLocalAdapterAddress;
                            robot.macAddr = selectedAddress;
                        }
                        onDisconnectRequested: robot.disconnectFromServer()
                        connectionStatus: robot.connectionStatus
                    }
                }

                CelluloRobot {
                    id: robot
                    property string type: "cellulo"
                    property int number: index
                    property real blinkPeriod: 0
                    property var keyStates: [0, 0, 0, 0, 0, 0]

                    function areAllKeysHeld() {
                        var held = true;
                        for (var i = 0; i < keyStates.length; ++i) {
                            if (keyStates[i] != 2)
                                held = false;
                        }

                        return held;
                    }

                    onMacAddrChanged: QMLCache.write("Robot" + (index) + "MacAddr", macAddr)

                    onKidnappedChanged: {
                        // rosNode.publishKidnapped(robot.macAddr, robot.kidnapped)
                        if (gameState == "RUNNING") {
                            if (robot.kidnapped == false) {
                                if (playerStates[index] == "READY")
                                    changePlayerState(index, "STATIC");
                                else if (playerStates[index] == "STATIC")
                                    changePlayerState(index, "READY");
                            }
                        }
                    }

                    onLongTouch: {
                        // if (gameState == "RUNNING") {
                        //     console.log("Player " + index + " longtouch " + key);
                        //     keyStates[key] = 2;

                        //     if (playerStates[index] == "READY" && areAllKeysHeld()) {
                        //         changePlayerState(index, "STATIC");

                        //         var staticPlayerCount = 0;
                        //         for (var i = 0; i < playerCount; ++i) {
                        //             if (playerStates[i] == "STATIC")
                        //                 ++staticPlayerCount;
                        //         }

                        //         if (staticPlayerCount == (playerCount - 1)) {
                        //             for (var i = 0; i < playerCount; ++i) {
                        //                 if (playerStates[i] != "STATIC")
                        //                     changeMobilePlayer(i);
                        //             }
                        //         }
                        //     }
                        // }
                        // rosNode.publishLongTouch(robot.macAddr, key)
                    }

                    onTouchBegan: {
                        // if (gameState == "RUNNING") {
                        //     console.log("Player " + index + " touch " + key);
                        //     keyStates[key] = 1;
                        // }
                        // rosNode.publishTouchStart(robot.macAddr, key)
                    }

                    onTouchReleased:  {
                        // if (gameState == "RUNNING") {
                        //     console.log("Player " + index + " released " + key);
                        //     keyStates[key] = 0;

                        //     if (playerStates[index] == "STATIC") {
                        //         if (mobilePlayerIndex > 0) {
                        //             if (playerStates[mobilePlayerIndex] != "OUT")
                        //                 players[mobilePlayerIndex].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, ledColors[mobilePlayerIndex], 255);

                        //             changeMobilePlayer(-1);
                        //         }

                        //         changePlayerState(index, "READY");
                        //     }
                        // }
                        // rosNode.publishTouchEnd(robot.macAddr, key)
                    }

                    onTrackingGoalReached: {
                        players[index].clearTracking();

                        if (playerStates[index] == "INIT") {
                            console.log("Player " + index + " position initialized.");
                            changePlayerState(index, "READY");
                        }
                        else {
                            lastPositions[index] = currentPositions[index];

                            if (playerStates[index] == "FOLLOWING") {
                                changePlayerState(index, "READY");
                                var followers = findPlayersInState("FOLLOWING");
                                if (followers.length == 0) {
                                    var leader = findPlayersInState("LEADING");
                                    console.assert(leader.length == 1);
                                    changePlayerState(leader, "READY");
                                }
                            }
                            else if (playerStates[index] == "OUT") {
                                changePlayerState(index, "READY");
                            }
                        }
                    }

                    onPoseChanged: {
                        if (gameState != "IDLE") {
                            currentPositions[index] = Qt.vector2d(players[index].x, players[index].y);
                            currentPoseDeltas[index] = currentPositions[index].minus(currentPositions[0]);
                        }

                        if (gameState == "RUNNING") {
                            if (playerStates[index] == "INIT") {
                                players[index].setGoalPosition(initialPositions[index].x, initialPositions[index].y);
                            }
                            else if (playerStates[index] == "READY") {
                                var staticPlayers = findPlayersInState("STATIC");
                                if (staticPlayers.length > 0) {
                                    players[index].setGoalPosition(lastPositions[index].x, lastPositions[index].y, linearVelocity);
                                }
                                else {
                                    var positionDelta = currentPositions[index].minus(lastPositions[index]);
                                    var absoluteDelta = Math.sqrt(positionDelta.dotProduct(positionDelta));

                                    // assume leader position after moving far enough
                                    if (absoluteDelta > 20.0) {
                                        changePlayerState(index, "LEADING");
                                    }
                                }
                            }
                            else if (playerStates[index] == "LEADING") {
                                // instruct others to follow
                                for (var i = 0; i < playerCount; ++i) {
                                    if (i != index) {
                                        changePlayerState(i, "FOLLOWING");
                                        var goalPosition = currentPositions[index].minus(lastPoseDeltas[index]).plus(lastPoseDeltas[i]);
                                        players[i].setGoalPosition(goalPosition.x, goalPosition.y, linearVelocity);
                                    }
                                }

                                lastPositions[index] = currentPositions[index];
                            }
                            else if (playerStates[index] == "STATIC") {
                                players[index].setGoalPosition(lastPositions[index].x, lastPositions[index].y, linearVelocity);
                            }
                            else if (playerStates[index] == "MOVING") {
                                // limit free movement
                                var verticalDelta = Math.abs(currentPositions[index].y - lastPositions[index].y);

                                if (verticalDelta > maximumVerticalDelta) {
                                    changePlayerState(index, "OUT");
                                }
                                else {
                                    var blinkPeriod = players[index].blinkPeriod;
                                    if (verticalDelta > 0.9 * maximumVerticalDelta)
                                        blinkPeriod = 10;
                                    else if (verticalDelta > 0.7 * maximumVerticalDelta)
                                        blinkPeriod = 20;
                                    else if (verticalDelta > 0.5 * maximumVerticalDelta)
                                        blinkPeriod = 40;

                                    if (blinkPeriod != players[index].blinkPeriod) {
                                        players[index].blinkPeriod = blinkPeriod;
                                        players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, ledColors[index], players[index].blinkPeriod);
                                    }
                                }
                            }
                        }

                        // rosNode.publishPose(robot.macAddr, robot.x, robot.y, robot.theta)
                    }

                    // RosNode {
                    //     id: rosNode
                    // }
                }
            }

            onItemAdded: {
                for (var i = 0; i < item.children.length; ++i) {
                    var child = item.children[i];
                    if (child.type == "cellulo")
                        players[child.number] = child;
                }
            }
        }

        Row {
            padding: 8
            spacing: 5

            Button{
                id: scanButton
                text: "Scan"
                onClicked: scanner.start()
            }

            BusyIndicator{
                running: scanner.scanning
                height: scanButton.height
            }

            Button{
                text: "Clear List"
                onClicked: {
                    robotRepeater.addresses = [];
                    QMLCache.write("addresses","");
                }
            }
        }

        Row {
            padding: 8
            spacing: 8

            Button {
                id: addPlayerButton
                text: "Add player"
                enabled: (gameState == "IDLE" && playerCount < maxPlayerCount)
                onClicked: playerCount += 1
            }

            Button {
                id: removePlayerButton
                text: "Remove player"
                enabled: (gameState == "IDLE" && playerCount > 2)
                onClicked: playerCount -= 1
            }

            Button{
                id: startButton
                text: "Start Game"
                onClicked: {
                    var allPlayersConnected = true;
                    for (var i = 0; i < playerCount; ++i) {
                        if (players[i].connectionStatus != CelluloBluetoothEnums.ConnectionStatusConnected)
                            allPlayersConnected = false;
                    }

                    if (!allPlayersConnected) {
                        toast.show("Cannot start game before both robots are connected!");
                        return;
                    }

                    lastPositions = [
                        initialPositions[0],
                        initialPositions[1],
                        initialPositions[3],
                        initialPositions[4]
                    ];
                    currentPositions = [
                        initialPositions[0],
                        initialPositions[1],
                        initialPositions[3],
                        initialPositions[4]
                    ];
                    lastPoseDeltas = [
                        Qt.vector2d(0.0, 0.0),
                        initialPositions[1].minus(initialPositions[0]),
                        initialPositions[2].minus(initialPositions[0]),
                        initialPositions[3].minus(initialPositions[0])
                    ];
                    currentPoseDeltas = [
                        Qt.vector2d(0.0, 0.0),
                        initialPositions[1].minus(initialPositions[0]),
                        initialPositions[2].minus(initialPositions[0]),
                        initialPositions[3].minus(initialPositions[0])
                    ];

                    changeGameState("INIT");

                    for (var i = 0; i < playerCount; ++i) {
                        changePlayerState(i, "INIT");
                        players[i].setGoalPosition(initialPositions[i].x, initialPositions[i].y, linearVelocity);
                    }

                    text = "Reset";
                }
            }
        }
    }

    ToastManager{ id: toast }    

    CelluloBluetoothScanner{
        id: scanner
        onRobotDiscovered: {
            var newAddresses = robotRepeater.addresses;
            if(newAddresses.indexOf(macAddr) < 0){
                toast.show(macAddr + " discovered.");
                newAddresses.push(macAddr);
                newAddresses.sort();
            }
            robotRepeater.addresses = newAddresses;
            QMLCache.write("addresses", robotRepeater.addresses.join(','));
        }
    }
}
