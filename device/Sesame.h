/*
 * Sesame.h
 *  
 * Base class for the ESP32-based device
 */

#ifndef Sesame_h
#define Sesame_h

// C/C++ core includes
#include <sstream>

// Arduino includes
#include "Arduino.h"

// project includes
#include "SesameLoRa.h"
#include "SesameBLE.h"

class SesameClass {
public:
  // initialize with a unique device ID, will be used identify this particular board over BLE & LoRa
  SesameClass(int _id) : id(_id) {
    // create a name string with ID
    std::stringstream ss;
    ss << "Sesame-" << _id;
    name = ss.str();
  }

  // start BLE server
  void startBLE() {
    ble.start(name);
  }

  // start LoRa radio
  void startLoRa() {
    lora.start(id, name);
  }

  // initialize device
  void init() {
    startBLE();
    startLoRa();
    // need to give BLE a pointer to LoRa so it can send messages
    ble.setLoRa(&lora);
  }
  
  unsigned char id=-1;
  std::string name;
  SesameLoRa lora;
  SesameBLE ble;
};

#endif /* Sesame_h */
