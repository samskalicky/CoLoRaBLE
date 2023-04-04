//
//  SesameEnv.h
//  
//
//  Created by Skalicky, Sam on 6/16/21.
//

#ifndef SesameEnv_h
#define SesameEnv_h

#include "Adafruit_BME680.h"

#define SEALEVELPRESSURE_HPA (1013.25)

class SesameEnv {
public:
    SesameEnv() : temperature(0), pressure(0), humidity(0), altitude(0), error(false) {
      
    }

    void start() {
      if(!bme.begin()) {
        error = true;
      } else {
        sampleTime = bme.beginReading(); //start first reading
      }
    }

    void sample() {
      if(!error) {
        unsigned long curTime = millis();
        if(curTime > sampleTime) {
          //store results
          if (bme.endReading()) {
            temperature = bme.temperature;
            pressure = bme.pressure / 100.0;
            humidity = bme.humidity;
            altitude = bme.readAltitude(SEALEVELPRESSURE_HPA);
          } 
          //start the next reading
          sampleTime = bme.beginReading();
        }
      }
    }

    Adafruit_BME680 bme;
    unsigned long sampleTime;
    float temperature; //degrees C
    float pressure; //hectopascal (hPa), aka millibar (mb)
    float humidity; //percentage (ie. 35% humidity)
    float altitude; //meters
    bool error;
};

#endif /* SesameEnv_h */
