# Sesame device software

The software for the radio device is mostly C++, but the main controller is Arduino. The [Sesame.ino](Sesame.ino) is the Arduino Sketch where the top level components are tied together. During the main loop, the device does 3 things:

1. LoRa radio networking (receive packets and send any ACKs)
2. Send any messages over LoRa (that were sent from the phone over Bluetooth)
3. Send any messages received from LoRa to the phone over Bluetooth

[Sesame.h](Sesame.h) is the main C++ entry point where the `Sesame` class is defined that holds the Bluetooth and LoRa objects and device ID. [SesameBLE.h](SesameBLE.h) defines the Bluetooth configuration of the device for communicating with the phone. And the [SesameLoRa.h](SesameLoRa.h) is where the LoRa radio networking configuration lives.

The LoRa software is built on top of the (LoRa Arduino library](https://github.com/sandeepmistry/arduino-LoRa). The Bluetooth software is built on top of the [Arduino ESP-32 core](https://github.com/espressif/arduino-esp32) \(leveraging the [SparkFun board config](https://github.com/sparkfun/ESP32_LoRa_1Ch_Gateway/tree/main/Firmware)\).

## LoRa Networking

The LoRa Arduino library is just a wrapper around the LoRa PHY RFM95W module register access. It doesnt provide any reliability or MAC layer over the radio link. Check out the [NETWORKING.md](NETWORKING.md) for a description of that. 