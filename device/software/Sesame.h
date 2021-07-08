//
//  Sesame.h
//  
//
//  Created by Skalicky, Sam on 6/16/21.
//

#ifndef Sesame_h
#define Sesame_h

#include <sstream>
#include "Arduino.h"

#include "SesameLoRa.h"
#include "SesameBLE.h"


class SesameClass {
public:
    SesameClass(int _id) : id(_id) {
      std::stringstream ss;
      ss << "Sesame-" << _id;
      name = ss.str();
    }
    
    void startBLE() {
        ble.start(name);
    }
    
    void startLoRa() {
        lora.start(id, name);
    }

    void init() {
      startBLE();
      startLoRa();
      ble.setLoRa(&lora);
    }
    
    unsigned char id=-1;
    std::string name;
    SesameLoRa lora;
    SesameBLE ble;
};

#endif /* Sesame_h */
