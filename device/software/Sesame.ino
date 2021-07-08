
#include "Sesame.h"

SesameClass Sesame(0);

void setup() {
  delay(1000);
  Serial.begin(115200);
  Sesame.init();

  Serial.println(Sesame.name.c_str());
}

unsigned long nextTx = 0;

void loop() {
  unsigned long current = millis();

  // do RF networking
  Sesame.lora.do_network();

  // Send BLE msgs over LoRa
  if(Sesame.ble.hasData()) {
    std::string data = Sesame.ble.getNextData();
    Sesame.lora.send((Sesame.id+1)%2, Sesame.id, data.length(), (unsigned char*)data.c_str());
  }

  // Send LoRa msgs to BLE
  if(Sesame.lora.hasData()) {
    std::string data = Sesame.lora.getNextData();
    Sesame.ble.send(data);
  }
}
