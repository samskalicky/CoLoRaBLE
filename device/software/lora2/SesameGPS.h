//
//  SesameLoRa.h
//  
//
//  Created by Skalicky, Sam on 6/16/21.
//

#ifndef SesameGPS_h
#define SesameGPS_h

#include <sstream>
#include <Adafruit_GPS.h>

#define GPSECHO false
#define GPS_RST_PIN 23
#define GPS_WAKE_PIN 18

class SesameGPS {
public:
    SesameGPS() : GPS(&Wire) {      
      latitude = 37.33456;
      longitude = -122.0089;
      lastFix = 0;
      isStandby = false;
      
      pinMode(GPS_WAKE_PIN,OUTPUT);
      pinMode(GPS_RST_PIN,OUTPUT);
      digitalWrite(GPS_RST_PIN, LOW); // hold GPS in reset
      digitalWrite(GPS_WAKE_PIN, LOW);
    }

    void start() {
      // GPS reset sequence
      digitalWrite(GPS_RST_PIN, LOW); // hold GPS reset active low for 200ms
      delay(200);
      digitalWrite(GPS_RST_PIN, HIGH); // then relese for 10ms    
      delay(10);
      digitalWrite(GPS_WAKE_PIN, HIGH); // in case GPS was standby, wake
      delay(700);
      digitalWrite(GPS_WAKE_PIN, LOW);

      // initialize GPS module
      GPS.begin(0x10);
      GPS.sendCommand(PMTK_SET_NMEA_OUTPUT_GGAONLY);
      update5s();
    }

    void update() {
      char c = GPS.read();
      if (GPS.newNMEAreceived()) {
//        if(isStandby) {
//          // if GPS was standby, its now awake since new GPS data is received
//          digitalWrite(GPS_WAKE_PIN, LOW);
//          isStandby = false;
//        }
        GPS.parse(GPS.lastNMEA());
        if(GPS.fix) {  
          parseLocation();
          altitude = GPS.altitude;
          lastFix = millis();
        }
      }        
    }

    void update1s() {
      GPS.sendCommand(PMTK_SET_NMEA_UPDATE_1HZ);
      GPS.sendCommand(PMTK_API_SET_FIX_CTL_1HZ);
    }

    void update5s() {
      GPS.sendCommand(PMTK_SET_NMEA_UPDATE_200_MILLIHERTZ);
      GPS.sendCommand(PMTK_API_SET_FIX_CTL_200_MILLIHERTZ);
    }

    void standby() {
      GPS.sendCommand("$PMTK225,4*2F");
      isStandby = true;
    }

    void wakeup() {
      digitalWrite(GPS_WAKE_PIN, HIGH);
    }

    void parseLocation() {
      //convert latitude from DDMM.MMMM to DD.MMMMMM
      short lat_degrees = GPS.latitude/100;
      float lat_minutes = (GPS.latitude - (lat_degrees*100)) / 60.0f;
      float lat_decimal = lat_degrees + lat_minutes;
      if(GPS.lat == 'S')
        lat_decimal = -lat_decimal;

      //convert longitude from DDDMM.MMMM to DDD.MMMMMM
      short lon_degrees = GPS.longitude/100;
      float lon_minutes = (GPS.longitude - (lon_degrees*100)) / 60.0f;
      float lon_decimal = lon_degrees + lon_minutes;
      if(GPS.lon == 'W')
        lon_decimal = -lon_decimal;

      latitude = lat_decimal;
      longitude = lon_decimal;
    }

    std::string getLocation() {
      std::stringstream ss;
    
      ss << latitude << ", ";
      ss << longitude;
      
      return ss.str();
    }

    unsigned long getLocationAge() {
      return millis() - lastFix;
    }
    
    /*
     * float latitude = DDMM.MMMM
     * float longitude = DDDMM.MMMM
     * char lat = N or S
     * char lon = E or W
     * unsigned char satellites
     * bool fix
     * unsigned char fixquality (0, 1, 2 = Invalid, GPS, DGPS) 
     * unsigned char fixquality_3d (1, 3, 3 = Nofix, 2D fix, 3D fix)
     * float altitude (meters)
     * 
     * unsigned char hour, minute, seconds
     * unsigned short milliseconds
     * unsigned char year, month, day
     */
    Adafruit_GPS GPS;

    float latitude, longitude, altitude;
    bool isStandby;
    unsigned long lastFix;
};

#endif /* SesameGPS_h */
