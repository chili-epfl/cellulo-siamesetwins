### Siamese Twins

A Cellulo game designed to elicit coordination and consensus-finding.

Tested under Qt 5.11 on the following platforms:
  - ArchLinux (rolling)
  - Android 6.0.1 (arm-v7) built with SDK API 18 and NDK r10e on ArchLinux host

### Dependencies
 - [qml-fileio](https://github.com/chili-epfl/qml-fileio)
 - [qml-ros-publisher](https://github.com/chili-epfl/qml-ros-publisher)
 - [qml-ros-recorder](https://github.com/chili-epfl/qml-ros-recorder)

### Building
```
mkdir build
cd build
qmake ..
make
```

### Usage
 - If the game should be captured, configure the ROS master and start the publisher and recording nodes under "Capture Settings"
 - After starting the game, use the "RobotSettings" menu entry connect to 2 Cellulo robots.
 - A number of game parameters can be configured under the "Game Settings" menu entry
 - Select the game screen in the menu and use the displayed button to start/stop a game.
