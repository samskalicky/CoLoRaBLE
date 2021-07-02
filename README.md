# CoLoRaBLE
Code for a [LoRa](https://en.wikipedia.org/wiki/LoRa) [BLE](https://en.wikipedia.org/wiki/Bluetooth_Low_Energy) device based on the [SparkFun LoRa Gateway - 1-Channel (ESP32)](https://www.sparkfun.com/products/18074)

<img src="logo/CoLoRaBLE.png" alt="CoLoRaBLE logo" width="200"/>

## Applications
I plan to build a few different project with this:
- LoRa-based messaging app, use your iOS phone to send/receive messages over 915MHz (iOS Phone -BT-> ESP32 --> LoRa --> ESP32 -BT-> iOS Phone). Communicate when hiking or out of cellular range, share GPS coordinates & see friends on map
- Remote temperature controller, see temperature inside the car & turn on a fan remotely
- Remote camera, see pictures from remote device

## Hardware
This project is built on top of the [SparkFun LoRa Gateway - 1-Channel (ESP32)](https://www.sparkfun.com/products/18074) with the [Pycom LoRa and Sigfox Antenna Kit - 915MHz](https://www.sparkfun.com/products/14676). Other sensors/peripherals will be added later, but these are the core components

## Software
This project will program the ESP32 using the Arduino IDE & software stack. iOS apps will be written to communicate from the phone over Bluetooth Low Energy (BLE).
