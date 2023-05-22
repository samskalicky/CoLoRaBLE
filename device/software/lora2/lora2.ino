
#include "SesameBLE.h"
#include "SesameGPS.h"
#include "SesameLoRa.h"
#include "SesameEnv.h"
#include "SesameBatt.h"

#include <map>
#include <string>
#include <sstream>
#include <iostream>

#define BUTTON_PIN 0
#define LED_PIN 17

std::map<uint64_t, int> IDmap = {
  {97461182530472ULL, 2},
  {141103667332656ULL, 1},
  {35347382272936ULL, 0}
};

uint64_t chipID = 0;
int id = -1;
std::string name;

SesameBLE ble;
SesameGPS gps;
SesameLoRa lora;
SesameEnv env;
SesameBatt batt;

bool ignoreButton = false;
bool buttonPressed = false;
void buttonISR() {
  if(!ignoreButton) {
    buttonPressed = true;
  }
}

void loraISR(int packetSize) {
  lora.handleIRQ(packetSize);
}

void setup() {
  Serial.begin(115200);
  
  chipID = ESP.getEfuseMac();
  id = IDmap[chipID];
  std::stringstream ss;
  ss << "Sesame-" << id;
  name = ss.str();

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
      
  setCpuFrequencyMhz(160); //240, 160, 80, 40 (no BLE), 20, 10
  
  gps.start();
  lora.start(id, name, loraISR);
  env.start();
  batt.start();

  ble.setPeriphs(&lora);
  lora.setPeriphs(&gps, &env, &batt);
  
  //configure wakeup
  esp_sleep_enable_ext1_wakeup(1,ESP_EXT1_WAKEUP_ALL_LOW); //wakeup on button press
  attachInterrupt(digitalPinToInterrupt(0), buttonISR, FALLING); //interrupt on button press

  esp_sleep_enable_ext0_wakeup(GPIO_NUM_26,1); // wakeup on LoRa Dio0 (received)

  /************************************************************************************
   * Theres a problem triggering the first esp_light_sleep_start() with a timer wakeup
   * thats causing the buttonISR to get called even when the button isnt pressed. So
   * here we trigger it once up-front and ignore the button so that future wakeups are 
   * normal.
   */
  ignoreButton = true;
  esp_sleep_enable_timer_wakeup(10);
  esp_light_sleep_start();
  ignoreButton = false;                                                                                                                         
  /************************************************************************************/
  esp_sleep_enable_timer_wakeup(5000000);
}

void print_wakeup_reason(){
  esp_sleep_wakeup_cause_t wakeup_reason;

  wakeup_reason = esp_sleep_get_wakeup_cause();

  switch(wakeup_reason)
  {
    case ESP_SLEEP_WAKEUP_EXT0 : Serial.println("Wakeup caused by external signal using EXT0 (LoRa)"); break;
    case ESP_SLEEP_WAKEUP_EXT1 : Serial.println("Wakeup caused by external signal using EXT1 (Button)"); break;
    case ESP_SLEEP_WAKEUP_TIMER : Serial.println("Wakeup caused by timer"); break;
    case ESP_SLEEP_WAKEUP_TOUCHPAD : Serial.println("Wakeup caused by touchpad"); break;
    case ESP_SLEEP_WAKEUP_ULP : Serial.println("Wakeup caused by ULP program"); break;
    default : Serial.printf("Wakeup was not caused by deep sleep: %d\n",wakeup_reason); break;
  }
}

unsigned long previousGPSFix = 0; //time of last GPS fix
unsigned long gpsWait = 30000; // time to wait for a new GPS fix before sleeping again
unsigned long sleep_start=5000, sleep_stop=0;

void loop() {
  if(buttonPressed) {
    buttonPressed = false;
    if(ble.isStarted) {
      ble.disable();
      digitalWrite(LED_PIN, LOW);
      gps.update5s();
    } else {
      digitalWrite(LED_PIN, HIGH);
      ble.start(id, name);
      gps.update1s();
    }
  }

//  if(gps.isStandby) {
//    unsigned long current = millis();
//    unsigned long timeSinceLastFix = (current - gps.lastFix)/60000; // minutes since last fix
//    // if its been more than 5min since last fix, try again once every 15min
//    if(timeSinceLastFix >= 5 && timeSinceLastFix % 15 == 0) {
//      gps.wakeup();
//      gpsWait = current + 30000; // 30 seconds from now
//    }
//  }
  
  // do RF networking
  lora.do_network();

  // update peripherals
  gps.update();
  env.sample();
  batt.sample();
  lora.update();

  // Send BLE msgs over LoRa
  while(ble.hasData()) {
    std::string data = ble.getNextData();
    unsigned char to = data[0]; // first byte is node ID to send to
    lora.send(to, id, data.length()-1, ((unsigned char*)data.c_str())+1); // send string without ID
  }
  
  if(ble.isStarted) {
    // Send LoRa msgs to BLE
    while(lora.hasData()) {
      std::string data = lora.getNextData();
      ble.send(data);
    }
  } else {
    // automated reply
    while(lora.hasData()) {
      std::string data = lora.getNextData();
      int first = data.find('\x1f',1); // start at 1 to skip the toID
      int to = atoi(data.substr(1,first+1).c_str());
      
      int second = data.find('\x1f',first+1);
      std::string user = data.substr(first+1,second-first-1);
      std::string msg = data.substr(second+1,data.length()-second);

      std::stringstream ss;
      ss << (int)id << "\x1f" << user << "\x1f" << "Auto Reply: " << msg;
      std::string send = ss.str();

      lora.send(to, id, send.length(), ((unsigned char*)send.c_str()));
    }
  }
  
  // sleep system if BLE is not running, and we have a new GPS fix or we timed out waiting
  unsigned long current = millis();
  if(!ble.isStarted && sleep_start < current) {
  
//  && // if BLE isnt running and,
//     (previousGPSFix < gps.lastFix || // we got a new GPS fix since last time or,
//      gpsWait < current)) { // we've waited long enough and still havent gotten a fix
      
      // put GPS to standby
//      gps.standby();
//      previousGPSFix = gps.lastFix;
//      Serial.println("sleeping");
//      Serial.flush();
      // put ESP to sleep
      digitalWrite(LED_PIN, LOW);
      esp_light_sleep_start();
      // woke up, go around the loop again      
      sleep_start = 1000+millis();
      digitalWrite(LED_PIN, HIGH);
      
//      print_wakeup_reason();
  }
}
