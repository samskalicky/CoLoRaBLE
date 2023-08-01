
# Required Libraries
- LoRa by Sandeep Mistry Version 0.8.0
- Adafruit INA219 Version 1.2.1
- Adafruit GPS Library Version 1.7.2
- Adafruit BME680 Version 2.0.2

## Install
Select `Tools`->`Manage Libraries`. Then search for and install each of the above libraries.

# Setting up Arduino
Following the instructions from [Sparkfun](https://learn.sparkfun.com/tutorials/sparkfun-lora-gateway-1-channel-hookup-guide/programming-the-esp32-with-arduino)

## Install ESP32 Arduino Core
Open Arduino and go to Settings, then set the `Additional Board Manager URLs:` to:
```
https://dl.espressif.com/dl/package_esp32_index.json
```
Then click `Ok`.

Next, select `Tools`->`Boards`->`Boards Manager`. Install the `esp32` package from Esspressif Systems (version 2.0.11 at the time of writing). Warning, do NOT install the `Arduino ESP32 Boards` package by Arduino. 

## Selecting the board
After installing the ESP32 Arduino Core (above), select `Tools`->`ESP32 Arduino`->`SparkFun LoRa Gateway 1-Channel`.

# Sesame device software

The software for the radio device is mostly C++, but the main controller is Arduino. The [Sesame.ino](Sesame.ino) is the Arduino Sketch where the top level components are tied together. During the main loop, the device does 3 things:

1. LoRa radio networking (receive packets and send any ACKs)
2. Send any messages over LoRa (that were sent from the phone over Bluetooth)
3. Send any messages received from LoRa to the phone over Bluetooth

[Sesame.h](Sesame.h) is the main C++ entry point where the `Sesame` class is defined that holds the Bluetooth and LoRa objects and device ID. [SesameBLE.h](SesameBLE.h) defines the Bluetooth configuration of the device for communicating with the phone. And the [SesameLoRa.h](SesameLoRa.h) is where the LoRa radio networking configuration lives.

The LoRa software is built on top of the [LoRa Arduino library](https://github.com/sandeepmistry/arduino-LoRa). The Bluetooth software is built on top of the [Arduino ESP-32 core](https://github.com/espressif/arduino-esp32) \(leveraging the [SparkFun board config](https://github.com/sparkfun/ESP32_LoRa_1Ch_Gateway/tree/main/Firmware)\).

## LoRa Networking

The LoRa Arduino library is just a wrapper around the LoRa PHY RFM95W module register access. It doesnt provide any reliability or MAC layer over the radio link. Check out the [NETWORKING.md](NETWORKING.md) for a description of that. 
