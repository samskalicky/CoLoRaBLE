# iOS App Software Architecture
The iOS app is organized into 3 categories:
- Graphical Views
- Data structures (for device info, bluetooth, etc)
- Singleton controllers

In general an iOS app has a main "ContentView" as the entry-point and an Info.plist that contains the app configuration info.

## Views

For the CoLoRaBLE app, the [ContentView.swift](ContentView.swift) is the main entry-point that displays the visible Bluetooth devices in range of the phone. When a user chooses a particular device to connect to \(by tapping one of the rows -- see [main screenshot](../../screenshots/main.png)\) it opens the "DeviceView". In [DeviceView.swift](DeviceView.swift) this is where the current Bluetooth connection status is displayed (as well as the signal strength -- RSSI), and where text messages can be sent and messages receive from other nodes on the LoRa network displayed. From this view users can navigate to the "MapView" and "SettingsView" also.

In [ChatView.swift](ChatView.swift) both sent messages as well as messages received on the LoRa network are displayed. Sent messages are shown aligned to the right (in blue), and messages received from other nodes are shown aligned to the left (with different colors). There is also a TextField where users can write new messages and a send Button to transmit the message from the app -- over Bluetooth -- to the radio device which will then be sent over the LoRa radio network to any nodes in range.

In [MapView.swift](MapView.swift) the current location of the phone is shown as the standard blue dot, and the locations of the other radio devices (in range) are also plotted on the map (using the same color scheme as in the chat view). In the [SettingsView.swift](SettingsView.swift) users can see/update the "username" that other nodes on the network will see as well as see the raw LoRa networkg info. In [NetworkView.swift](NetworkView.swift) each node on the LoRa network is shown by node ID and signal strength (RSSI and SNR values).

## Controllers

In [LoraController.swift](LoraController.swift) the network status is processed from a JSON string into `NetworkRow` objects to be displayed. The [MsgController.swift](MsgController.swift) organizes messages sent and and received.

## Data Structures

[Devices.swift](Devices.swift) contains the `Peripheral` class definition for radio devices local to the phone. The [BLEmanager.swift](BLEmanager.swift) is where the Bluetooth support is implemented using the CoreBluetooth framework. 