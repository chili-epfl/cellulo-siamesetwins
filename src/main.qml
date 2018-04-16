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
    property var players: [null, null]
    property var playerStates: ["IDLE", "IDLE"]
    property var player0InitialPosition: Qt.vector3d(45.0, 55.0, 0.0)
    property var player1InitialPosition: Qt.vector3d(345.0, 55.0, 0.0)
    property var initialPoseDelta: player1InitialPosition.minus(player0InitialPosition)
    property var currentPoseDelta: initialPoseDelta
    property var ledColors: ["#0000FF", "#00FF00"]
    property real linearVelocity: 100.0
    property real angularVelocity: 3.14159

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
                        // rosNode.publishKidnapped(robot.macAddr, robot.kidnapped)
                    }

                    onLongTouch: {
                        keyStates[key] = 2;

                        var openLock = true;
                        for (var i = 0; i < 6; ++i) {
                            if (players[index].keyStates[i] != 2)
                                touchActive = false;
                        }

                        if (openLock) {
                            players[otherPlayerIndex].setVisualEffect(CelluloBluetoothEnums.VisualEffectBlink, ledColors[otherPlayerIndex], 10);
                            staticPlayer = index;
                        }
                        // rosNode.publishLongTouch(robot.macAddr, key)
                    }

                    onTouchBegan: {
                        keyStates[key] = 1;
                        // rosNode.publishTouchStart(robot.macAddr, key)
                    }

                    onTouchReleased:  {
                        keyStates[key] = 0;

                        if (staticPlayer == index) {
                            players[otherPlayerIndex].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, ledColors[otherPlayerIndex], 255);
                            staticPlayer = -1;
                        }
                        // rosNode.publishTouchEnd(robot.macAddr, key)
                    }

                    onTrackingGoalReached: {
                        console.log("Player " + index + ": tracking goal reached.");

                        if (gameState == "INIT" && playerStates[index] == "INIT") {
                            console.log("Player " + index + " position initialized.");
                            players[index].clearTracking();
                            players[index].setVisualEffect(CelluloBluetoothEnums.VisualEffectConstAll, ledColors[index], 255);
                            playerStates[index] = "READY";

                            if (playerStates[otherPlayerIndex] == "READY")
                                gameState = "RUNNING";
                        }
                        else if (gameState == "RUNNING")
                            players[index].clearTracking();
                    }

                    onPoseChanged: {
                        if (gameState == "RUNNING") {
                            if (staticPlayer < 0) {
                                var touchActive = false;
                                for (var i = 0; i < 6; ++i) {
                                    if (players[index].keyStates[i] != 0)
                                        touchActive= true;
                                }

                                if (!touchActive)
                                    return;

                                if (index == 0)
                                    players[otherPlayerIndex].setGoalPose(
                                        players[index].x + currentPoseDelta.x,
                                        players[index].y + currentPoseDelta.y,
                                        players[index].theta + currentPoseDelta.z,
                                        linearVelocity, angularVelocity);
                                else
                                    players[otherPlayerIndex].setGoalPose(
                                        players[index].x - currentPoseDelta.x,
                                        players[index].y - currentPoseDelta.y,
                                        players[index].theta - currentPoseDelta.z,
                                        linearVelocity, angularVelocity);
                            }
                            else {

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
                enabled: gameState == "IDLE"
                onClicked: {
                    if (players[0].connectionStatus != CelluloBluetoothEnums.ConnectionStatusConnected ||
                        players[1].connectionStatus != CelluloBluetoothEnums.ConnectionStatusConnected) {
                        toast.show("Cannot start game before both robots are connected!");
                        return;
                    }

                    console.log("Initializing positions...");
                    gameState = "INIT";
                    playerStates[0] = "INIT";
                    playerStates[1] = "INIT";
                    players[0].setGoalPose(player0InitialPosition.x, player0InitialPosition.y, player0InitialPosition.z, linearVelocity, angularVelocity);
                    players[1].setGoalPose(player1InitialPosition.x, player1InitialPosition.y, player1InitialPosition.z, linearVelocity, angularVelocity);
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
