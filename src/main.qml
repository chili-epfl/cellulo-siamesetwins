import QtQuick 2.7
import QtQuick.Window 2.1
import QtQuick.Layouts 1.1
import QtQuick.Controls 1.4
import QtQuick.Controls.Private 1.0
import QtQuick.Controls.Styles 1.3

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
    property int staticPlayer: -1
    property var players: []
    property var playerStates: []
    property var playerInitialPositions: [ Qt.vector2d(45.0, 55.0), Qt.vector2d(345.0, 55.0) ]
    property var playerCurrentPositions: [ playerInitialPositions[0], playerInitialPositions[1] ]
    property var playerLastPositions: [ playerInitialPositions[0], playerInitialPositions[1] ]
    property var lastPoseDelta: playerInitialPositions[1].minus(playerInitialPositions[0])
    property var currentPoseDelta: lastPoseDelta
    property real maximumVerticalDelta: 100.0
    property var ledColors: [ "#0000FF", "#00FF00" ]
    property real linearVelocity: 200.0

    Column {
        id: robotLayout
        spacing: 8

        Repeater {
            id: robotRepeater
            visible: true
            model: 2

            property var addresses: QMLCache.read("addresses").split(",")

            delegate: Column {
                padding: 8
                spacing: 8

                Row {
                    spacing: 5
                    Label {
                        text: "Player " + (index + 1) + " robot: "
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
                    property int otherPlayerIndex: index == 0 ? 1 : 0;
                    property string name: "player" + (index)
                    property var keyStates: [ 0, 0, 0, 0, 0, 0 ]

                    macAddr: QMLCache.read("Robot" + (index) + "MacAddr")
                    onMacAddrChanged: QMLCache.write("Robot" + (index) + "MacAddr", macAddr)

                    onKidnappedChanged: {
                        if (robot.kidnapped)
                            players[index].setGoalPosition(playerCurrentPositions[index].x, playerCurrentPositions[index].y, linearVelocity);

                        // rosNode.publishKidnapped(robot.macAddr, robot.kidnapped)
                    }

                    onLongTouch: {
                        keyStates[key] = 2;

                        var openLock = true;
                        for (var i = 0; i < 6; ++i) {
                            if (players[index].keyStates[i] != 2)
                                openLock = false;
                        }

                        if (playerStates[index] == "READY" && openLock) {
                            players[otherPlayerIndex].setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, ledColors[otherPlayerIndex], 10);
                            playerStates[index] = "STATIC";
                            console.log("Player " + index + " entered STATIC mode.");
                        }
                        // rosNode.publishLongTouch(robot.macAddr, key)
                    }

                    onTouchBegan: {
                        keyStates[key] = 1;
                        // rosNode.publishTouchStart(robot.macAddr, key)
                    }

                    onTouchReleased:  {
                        keyStates[key] = 0;

                        if (playerStates[index] == "STATIC") {
                            players[otherPlayerIndex].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, ledColors[otherPlayerIndex], 255);
                            playerStates[index] == "READY";
                            console.log("Player " + index + " entered READY mode.");
                        }
                        // rosNode.publishTouchEnd(robot.macAddr, key)
                    }

                    onTrackingGoalReached: {
                        console.log("Player " + index + ": tracking goal reached.");
                        players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, ledColors[index], 255);
                        
                        if (gameState == "INIT" && playerStates[index] == "INIT") {
                            console.log("Player " + index + " position initialized.");
                            playerStates[index] = "READY";
                            console.log("Player " + otherPlayerIndex + " entered READY mode.");

                            if (playerStates[otherPlayerIndex] == "READY") {
                                players[0].clearTracking();
                                players[1].clearTracking();
                                gameState = "RUNNING";
                            }
                        }
                        else if (gameState == "RUNNING") {
                            players[index].clearTracking();

                            if (playerStates[index] == "FOLLOWING" || playerStates[index] == "OUT") {
                                playerLastPositions[index] = playerCurrentPositions[index];
                                playerStates[index] = "READY";
                                console.log("Player " + index + " entered READY mode.");
                            }
                        }
                    }

                    onPoseChanged: {
                        if (gameState == "RUNNING") {
                            playerCurrentPositions[index] = Qt.vector2d(players[index].x, players[index].y);
                            currentPoseDelta = playerCurrentPositions[1].minus(playerCurrentPositions[0]);

                            if (playerStates[index] == "READY") {
                                if (playerStates[otherPlayerIndex] == "STATIC") {
                                    var verticalDelta = currentPoseDelta.y - lastPoseDelta.y;
                                    if (Math.abs(verticalDelta) > maximumVerticalDelta) {
                                        playerStates[index] = "OUT";
                                        players[index].setGoalYCoordinate(playerCurrentPositions[otherPlayerIndex].y, linearVelocity);
                                        players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, "#FF0000", 10);
                                        players[index].simpleVibrate(300, 300, 6.28, 10, 300);
                                        console.log("Player " + index + " entered OUT mode.");
                                    }
                                }
                                else if (playerStates[otherPlayerIndex] == "FOLLOWING") {
                                    var otherGoalPosition = null;
                                    if (index == 0)
                                        otherGoalPosition = playerCurrentPositions[index].plus(lastPoseDelta);
                                    else
                                        otherGoalPosition = playerCurrentPositions[index].minus(lastPoseDelta);

                                    players[otherPlayerIndex].setGoalPosition(otherGoalPosition.x, otherGoalPosition.y, linearVelocity);
                                }
                                else {
                                    var poseDifference = currentPoseDelta.minus(lastPoseDelta);
                                    if (Math.sqrt(poseDifference.dotProduct(poseDifference)) > 20.0) {
                                        playerStates[otherPlayerIndex] = "FOLLOWING";
                                        console.log("Player " + otherPlayerIndex + " entered FOLLOWING mode.");
                                    }
                                }
                                
                                playerLastPositions[index] = playerCurrentPositions[index];
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
                    if (child.name == "player0")
                        players[0] = item.children[i]
                    else if (child.name == "player1")
                        players[1] = item.children[i]
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
            spacing: 5

            Button{
                id: startButton
                text: "Start Game"
                onClicked: {
                    if (players[0].connectionStatus != CelluloBluetoothEnums.ConnectionStatusConnected ||
                        players[1].connectionStatus != CelluloBluetoothEnums.ConnectionStatusConnected) {
                        toast.show("Cannot start game before both robots are connected!");
                        return;
                    }

                    console.log("Initializing positions...");
                    gameState = "INIT";
                    playerStates = [ "INIT", "INIT" ];
                    players[0].setGoalPosition(playerInitialPositions[0].x, playerInitialPositions[0].y, linearVelocity);
                    players[1].setGoalPosition(playerInitialPositions[1].x, playerInitialPositions[1].y, linearVelocity);
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
