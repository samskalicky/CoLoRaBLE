//
//  SesameBatt.h
//  
//
//  Created by Skalicky, Sam on 6/16/21.
//

#ifndef SesameBatt_h
#define SesameBatt_h

#include <Adafruit_INA219.h>

class SesameBatt {
public:
  SesameBatt() {
    current = 0;
    voltage = 0;
    error = false;
  }

  void start() {
    if (ina219.begin()) {
      ina219.setCalibration_16V_400mA();
    } else {
      error = true;
    }
  }

  void sample() {
    if(!error) {
      voltage = ina219.getBusVoltage_V();
      current = ina219.getCurrent_mA();
    }
  }

  Adafruit_INA219 ina219;
  float current; // mA
  float voltage; // V
  bool error;
};

#endif /* SesameBatt_h */
