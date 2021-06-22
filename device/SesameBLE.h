/*
 * SesameBLE.h
 *  
 * BLE class for the ESP32-based device
 */

#ifndef SesameBLE_h
#define SesameBLE_h

// includes from ESP32 package 
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>

// project includes
#include "SesameLoRa.h"

//BLE IDs
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_MSG_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define CHARACTERISTIC_LORA_UUID "9971353b-aa92-491d-a960-734cd69d1f5e"
#define CHARACTERISTIC_FAN_UUID "856885ae-7ed5-480b-bc90-52b274d4fbdd"
#define CHARACTERISTIC_CAMERA_UUID "64899e65-0781-4e68-9e03-e4531902cad1"
#define CHARACTERISTIC_POWER_UUID "70d56ac3-6263-4f48-adc1-c748493c3918"
#define CHARACTERISTIC_TEMP_UUID "93096739-4047-41cd-8c5c-97272718271d"
#define CHARACTERISTIC_LED_UUID "0d0d4515-ec36-4c3b-a902-03a2e753e932"

/*
 * serverCallbacks is a class for BLE Server callbacks
 */
class serverCallbacks : public BLEServerCallbacks {
public:
  serverCallbacks() : deviceConnected(false) {}
  // called when phone connects to device
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
  };
  // called when phone disconnects from device
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    pServer->getAdvertising()->start();
  }
  
  bool deviceConnected;
};

/*
 * msgCallbacks is a class for BLE Characteristic callbacks for messaging
 */
class msgCallbacks : public BLECharacteristicCallbacks {
  public:
  msgCallbacks() {}
  // Called when phone writes data to device
  void onWrite(BLECharacteristic *pCharacteristic) {
    // get value written over BLE
    std::string value = pCharacteristic->getValue();
    // store in queue to send over LoRa as text message
    incoming.push_back(value);
  }
  std::deque<std::string> incoming;
};

/*
 * loraCallbacks is a class for BLE Characteristic callbacks for LoRa radio status
 */
class loraCallbacks : public BLECharacteristicCallbacks {
  public:
  // Called when phone reads data from device
  void onRead(BLECharacteristic *pCharacteristic) {
    // get the latest LoRa radio network status
    pCharacteristic->setValue(lora->getNetworkInfo());
  }
  
  SesameLoRa *lora;
};


class SesameBLE  {
public:
  SesameBLE() {
    msgHandler = new msgCallbacks();
    loraHandler = new loraCallbacks();
    srvrCallbacks = new serverCallbacks();
  }
  
  // start BLE
  void start(std::string name) {
    // setup BLE
    BLEDevice::init(name.c_str());
    BLEServer* pServer = BLEDevice::createServer();
    
    BLEService *pService = pServer->createService(SERVICE_UUID);
    pServer->setCallbacks(srvrCallbacks);
    
    // Msg Characteristic
    msgCharacteristic = pService->createCharacteristic(
					     CHARACTERISTIC_MSG_UUID,
                                             BLECharacteristic::PROPERTY_READ |
                                             BLECharacteristic::PROPERTY_WRITE |
                                             BLECharacteristic::PROPERTY_NOTIFY
						       );
    msgCharacteristic->setCallbacks(msgHandler);
    msgCharacteristic->addDescriptor(new BLE2902());
    
    // LoRa Characteristic
    loraCharacteristic = pService->createCharacteristic(
					     CHARACTERISTIC_LORA_UUID,
                                             BLECharacteristic::PROPERTY_READ
							);
    loraCharacteristic->setCallbacks(loraHandler);
    loraCharacteristic->setValue("{}");

    // start BLE server
    pService->start();

    // start advertising BLE server
    BLEAdvertising *pAdvertising = pServer->getAdvertising();
    pAdvertising->start();
  }

  // transfer a message received over LoRa up to the phone over BLE
  void send(std::string str) {
    //write data to BLE
    msgCharacteristic->setValue(str);
    msgCharacteristic->notify();
  }

  // check if messages from the phone are waiting to be sent over LoRa
  bool hasData() {
    return msgHandler->incoming.size() > 0;
  }
  
  // get next message to send over LoRa
  std::string getNextData() {
    if(hasData()) {
      std::string data = msgHandler->incoming.front();
      msgHandler->incoming.pop_front();
      return data;
    } else {
      return std::string();
    }
  }

  // set the LoRa class object
  void setLoRa(SesameLoRa *_lora) {
    loraHandler->lora = _lora;
  }

  serverCallbacks *srvrCallbacks;
  msgCallbacks *msgHandler;
  loraCallbacks *loraHandler;
  BLECharacteristic* msgCharacteristic;
  BLECharacteristic* loraCharacteristic;
};

#endif /* SesameBLE_h */
