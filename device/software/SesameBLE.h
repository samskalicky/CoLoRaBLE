//
//  Sesame.h
//  
//
//  Created by Skalicky, Sam on 6/16/21.
//

#ifndef SesameBLE_h
#define SesameBLE_h

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>

#include "SesameLoRa.h"

//BLE IDs
#define SERVICE_UUID               "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_MSG_UUID    "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define CHARACTERISTIC_LORA_UUID   "9971353b-aa92-491d-a960-734cd69d1f5e"
#define CHARACTERISTIC_GPS_UUID    "d233a9d8-f33e-4e3b-be6c-52914e5947fe"
#define CHARACTERISTIC_FAN_UUID    "856885ae-7ed5-480b-bc90-52b274d4fbdd"
#define CHARACTERISTIC_CAMERA_UUID "64899e65-0781-4e68-9e03-e4531902cad1"
#define CHARACTERISTIC_POWER_UUID  "70d56ac3-6263-4f48-adc1-c748493c3918"
#define CHARACTERISTIC_TEMP_UUID   "93096739-4047-41cd-8c5c-97272718271d"
#define CHARACTERISTIC_LED_UUID    "0d0d4515-ec36-4c3b-a902-03a2e753e932"

class serverCallbacks : public BLEServerCallbacks {
public:
  serverCallbacks() : deviceConnected(false) {}
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
  };

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    pServer->getAdvertising()->start();
  }
  
  bool deviceConnected;
};

class msgCallbacks : public BLECharacteristicCallbacks {
  public:
  msgCallbacks() {}
  /*
     * Called when phone writes to device
     */
    void onWrite(BLECharacteristic *pCharacteristic) {
        std::string value = pCharacteristic->getValue();
        incoming.push_back(value);
    }
    std::deque<std::string> incoming;
};

class loraCallbacks : public BLECharacteristicCallbacks {
  public:
  /*
     * Called when phone writes to device
     */
    void onRead(BLECharacteristic *pCharacteristic) {
        std::string info = lora->getNetworkInfo();
        pCharacteristic->setValue(info);
    }
    
    SesameLoRa *lora;
};

class gpsCallbacks : public BLECharacteristicCallbacks {
  public:
  gpsCallbacks() {}
  /*
     * Called when phone writes to device
     */
    void onWrite(BLECharacteristic *pCharacteristic) {
        std::string value = pCharacteristic->getValue();
        phone = value;
    }

    void onRead(BLECharacteristic *pCharacteristic) {
        pCharacteristic->setValue(phone);
    }
    
    std::string phone;
};

class SesameBLE  {
public:
    SesameBLE() {
      msgHandler = new msgCallbacks();
      gpsHandler = new gpsCallbacks();
      loraHandler = new loraCallbacks();
      srvrCallbacks = new serverCallbacks();
    }
    
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

        //LoRa Characteristic
        loraCharacteristic = pService->createCharacteristic(
                                             CHARACTERISTIC_LORA_UUID,
                                             BLECharacteristic::PROPERTY_READ
                                           );
        loraCharacteristic->setCallbacks(loraHandler);
        loraCharacteristic->setValue("{}");

        // GPS Characteristic
        gpsCharacteristic = pService->createCharacteristic(
                                             CHARACTERISTIC_GPS_UUID,
                                             BLECharacteristic::PROPERTY_READ |
                                             BLECharacteristic::PROPERTY_WRITE
                                           );
        gpsCharacteristic->setCallbacks(gpsHandler);
        gpsCharacteristic->addDescriptor(new BLE2902());

        pService->start();

        BLEAdvertising *pAdvertising = pServer->getAdvertising();
        pAdvertising->start();
    }
    
    void send(std::string str) {
        //write data to BLE
        msgCharacteristic->setValue(str);
        msgCharacteristic->notify();
    }
    
    bool hasData() {
        return msgHandler->incoming.size() > 0;
    }
    
    std::string getNextData() {
        if(hasData()) {
            std::string data = msgHandler->incoming.front();
            msgHandler->incoming.pop_front();
            return data;
        } else {
            return std::string();
        }
    }

    void setLoRa(SesameLoRa *_lora) {
      lora = _lora;
      loraHandler->lora = _lora;
    }

    SesameLoRa *lora;
    serverCallbacks *srvrCallbacks;
    gpsCallbacks *gpsHandler;
    msgCallbacks *msgHandler;
    loraCallbacks *loraHandler;
    BLECharacteristic* msgCharacteristic;
    BLECharacteristic* gpsCharacteristic;
    BLECharacteristic* loraCharacteristic;
};

#endif /* SesameBLE_h */
