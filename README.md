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
 - Make sure a ROS master is reachable at IP address 192.168.1.100 
 - After starting the game, use the "Robots" menu entry connect to 2 Cellulo robots.
 - A number of game parameters can be configured under the "Config" menu entry
 - Select "Game" and use the displayed button to start/stop a game.
