import QtQuick 2.7
import QtQuick.Window 2.2
import QtQuick.Controls 2.3
import QtQml.Models 2.2
import QtQuick.Dialogs 1.3
import QtQuick.Layouts 1.3

Page {
    id: root
    title: qsTr("Capture Settings")

    property var game

    GridLayout {
        anchors.centerIn: parent
        columns: 2
        columnSpacing: 8
        rowSpacing: 24

        Text {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            text: qsTr("ROS master IP Address: ")
            font.bold: true
        }

        TextField {
        	text: "192.168.1.100"
			RegExpValidator {
				id: ipAddressValidator
				regExp: /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/
			}
        }

        Text {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            text: qsTr("Publisher node status: ")
            font.bold: true
        }

        Text {
            text: game != undefined ? game.publisher.status : "Idle"
            font.bold: true
        }

        Text {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            text: qsTr("Recorder node status: ")
            font.bold: true
        }

        Text {
            text: game != undefined ? game.recorder.status : "Idle"
            font.bold: true
        }

        Button {
            text: {
            	if (game.publisher.status == "Running") {
            		return "Stop publisher"
            	}
            	else {
            		return "Start publisher"
            	}
            }
            onClicked: {
            	if (game.publisher.status == "Running") {
            		game.publisher.stopNode()
            	}
            	else {
            		game.publisher.startNode()
            	}
            }
        }

        Button {
            text: {
            	if (game.recorder.status == "Running") {
            		return "Stop recorder"
            	}
            	else {
            		return "Start recorder"
            	}
            }
            onClicked: {
            	if (game.recorder.status == "Running") {
            		game.recorder.stopNode()
            	}
            	else {
            		game.recorder.startNode()
            	}
            }
        }
    }
}