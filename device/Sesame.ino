/*
 * Main device run top level code
 */

// project includes
#include "Sesame.h"

// create instance of Sesame class
SesameClass Sesame(0);

// Arduino one-time setup
void setup() {
  delay(1000);
  // start serial
  Serial.begin(115200);

  // initialize device
  Sesame.init();

  // print device name
  Serial.println(Sesame.name.c_str());
}

// Arduino main run loop
void loop() {
  // do LoRa radio networking
  Sesame.lora.do_network();

  // send BLE msgs over LoRa
  if(Sesame.ble.hasData()) {
    std::string data = Sesame.ble.getNextData();
    Sesame.lora.send((Sesame.id+1)%2, Sesame.id, data.length(), (unsigned char*)data.c_str());
  }

  // send LoRa msgs to BLE
  if(Sesame.lora.hasData()) {
    std::string data = Sesame.lora.getNextData();
    Sesame.ble.send(data);
  }
}
