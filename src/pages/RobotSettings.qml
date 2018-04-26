import QtQuick 2.7
import QtQuick.Window 2.2
import QtQuick.Controls 2.3
import QtQml.Models 2.2
import QtQuick.Dialogs 1.3

import Cellulo 1.0
import QMLCache 1.0
import QMLBluetoothExtras 1.0

Page {
    id: root

    title: qsTr("Robot Settings")

    property int robotCount: 1
    property var robots: []

    function updateRobotList() {
        robots = []
        for (var i = 0; i < robotRepeater.count; ++i) {
            var item = robotRepeater.itemAt(i)
            for (var j = 0; j < item.children.length; ++j) {
                var child = item.children[j]
                if (child.type == "cellulo" && child.connectionStatus == CelluloBluetoothEnums.ConnectionStatusConnected) {
                    child.number = robots.length
                    robots.push(child)
                }
            }
        }
    }

    ToastManager {
        id: toast
    }

    CelluloBluetoothScanner {
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

    Column {
        id: robotLayout
        spacing: 8

        Repeater {
            id: robotRepeater
            visible: true
            model: robotCount

            property var addresses: QMLCache.read("addresses").split(",")

            delegate: Column {
                padding: 8
                spacing: 8

                CelluloRobot {
                    id: robot
                    property string type: "cellulo"
                    property string state: "IDLE"
                    property int number
                    property color ledColor
                    property int blinkPeriod
                    property var lastPosition
                    // property var lastPoseDelta
                    // property var currentPoseDelta
                    property var targetZone
                    property var nextZone
                    property var currentZone
                    onConnectionStatusChanged: updateRobotList()
                }

                Row {
                    spacing: 5
                    Label {
                        id: playerLabel
                        text: "Robot " + (index + 1)
                        font.bold: true
                        font.pointSize: 14
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
            }
        }

        Row {
            padding: 8
            spacing: 5

            BusyIndicator {
                running: scanner.scanning
                height: scanButton.height
            }

            Button {
                id: scanButton
                text: "Scan"
                onClicked: scanner.start()
            }

            Button {
                text: "Clear List"
                onClicked: {
                    robotRepeater.addresses = [];
                    QMLCache.write("addresses","");
                }
            }

            Button {
                text: "Add player"
                onClicked: robotCount += 1
            }

            Button {
                text: "Remove player"
                enabled: robotCount > 1
                onClicked: robotCount -= 1
            }
        }
    }
}
