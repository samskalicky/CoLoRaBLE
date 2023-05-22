//
//  Sesame.h
//  
//
//  Created by Skalicky, Sam on 6/16/21.
//

#ifndef SesameBLE_h
#define SesameBLE_h

#include <sstream>

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>

#include "SesameLoRa.h"
#include "SesameGPS.h"

//BLE IDs
#define SERVICE_UUID                 "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_MSG_UUID      "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define CHARACTERISTIC_LORA_UUID     "9971353b-aa92-491d-a960-734cd69d1f5e"
#define CHARACTERISTIC_RADIO_UUID    "236c1eb8-7179-4a3c-a532-0c164ab912e6"
#define CHARACTERISTIC_NODEDATA_UUID "d233a9d8-f33e-4e3b-be6c-52914e5947fe"

/* Unused
#define CHARACTERISTIC_FAN_UUID      "856885ae-7ed5-480b-bc90-52b274d4fbdd"
#define CHARACTERISTIC_CAMERA_UUID   "64899e65-0781-4e68-9e03-e4531902cad1"
#define CHARACTERISTIC_POWER_UUID    "70d56ac3-6263-4f48-adc1-c748493c3918"
#define CHARACTERISTIC_TEMP_UUID     "93096739-4047-41cd-8c5c-97272718271d"
#define CHARACTERISTIC_LED_UUID      "0d0d4515-ec36-4c3b-a902-03a2e753e932"
*/

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

    void onRead(BLECharacteristic *pCharacteristic) {
      std::string info = "{}";
      if(lora) {
        info = lora->getMessages();
      }
      pCharacteristic->setValue(info);
    }
    
    std::deque<std::string> incoming;
    SesameLoRa *lora;
};

class loraCallbacks : public BLECharacteristicCallbacks {
  public:
    loraCallbacks() : lora(0) {}
    /*
     * Called when phone reads from device
     */
    void onRead(BLECharacteristic *pCharacteristic) {
      std::string send = "{}";
      if(lora) {
        if(info.length() == 0)
          info = lora->getNetworkInfo();
        
        if(info.length() > 500) {
          send = info.substr(0, 500) + "\x1f";
          info = info.substr(500, info.length()-500);
        } else {
          send = info;
          info = "";
        }
      }
      pCharacteristic->setValue(send);
    }
    
    SesameLoRa *lora;
    std::string info;
};

class radioCallbacks : public BLECharacteristicCallbacks {
  public:
    radioCallbacks() : lora(0) {}

    void onWrite(BLECharacteristic *pCharacteristic) {
      std::string value = pCharacteristic->getValue();
    }

    void onRead(BLECharacteristic *pCharacteristic) {
      std::string radioConfig = "{}";
      if(lora) {
        radioConfig = lora->getRadioConfig();
      }
      pCharacteristic->setValue(radioConfig);
    }
    
    SesameLoRa *lora;
};

class nodeDataCallbacks : public BLECharacteristicCallbacks {
  public:
    nodeDataCallbacks() : lora(0) {}

    void onWrite(BLECharacteristic *pCharacteristic) {
      std::string value = pCharacteristic->getValue();
      //store data from phone (phone GPS, fan on/off, etc)
    }

    void onRead(BLECharacteristic *pCharacteristic) {
    std::string nodeData = "{}";
      if(lora) {
        nodeData = lora->getNodeData();
      }
      pCharacteristic->setValue(nodeData);
    }
    
    SesameLoRa *lora;
};

class SesameBLE  {
public:
    SesameBLE() {
      isStarted = false;
      msgHandler = new msgCallbacks();
      nodeDataHandler = new nodeDataCallbacks();
      loraHandler = new loraCallbacks();
      radioHandler = new radioCallbacks();
      srvrCallbacks = new serverCallbacks();
    }
    
    void start(unsigned char _id, std::string name) {
      isStarted = true;
      id = _id;
      
      // setup BLE
      BLEDevice::init(name.c_str());
      
      BLEServer* pServer = BLEDevice::createServer();
      pServer->setCallbacks(srvrCallbacks);

      BLEService *pService = pServer->createService(SERVICE_UUID);

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

      //Radio Characteristic
      radioCharacteristic = pService->createCharacteristic(
                                           CHARACTERISTIC_RADIO_UUID,
                                           BLECharacteristic::PROPERTY_READ |
                                           BLECharacteristic::PROPERTY_WRITE
                                         );
      radioCharacteristic->setCallbacks(radioHandler);
      radioCharacteristic->addDescriptor(new BLE2902());
      

      // Node Data Characteristic
      nodeDataCharacteristic = pService->createCharacteristic(
                                           CHARACTERISTIC_NODEDATA_UUID,
                                           BLECharacteristic::PROPERTY_READ |
                                           BLECharacteristic::PROPERTY_WRITE
                                         );
      nodeDataCharacteristic->setCallbacks(nodeDataHandler);
      nodeDataCharacteristic->addDescriptor(new BLE2902());

      pService->start();

      BLEAdvertising *pAdvertising = pServer->getAdvertising();
      pAdvertising->start();
    }

    void disable() {
      isStarted = false;
      BLEDevice::deinit(false);
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
            std::string str = msgHandler->incoming.front();
            msgHandler->incoming.pop_front();
            return str;
        } else {
            return std::string();
        }
    }

    void setPeriphs(SesameLoRa *_lora) {
      lora = _lora;
      loraHandler->lora = _lora;
      radioHandler->lora = _lora;
      msgHandler->lora = _lora;
      nodeDataHandler->lora = _lora;
    }

    bool isStarted;
    unsigned char id;
    SesameLoRa *lora;
    serverCallbacks *srvrCallbacks;
    nodeDataCallbacks *nodeDataHandler;
    msgCallbacks *msgHandler;
    loraCallbacks *loraHandler;
    radioCallbacks *radioHandler;
    BLECharacteristic* msgCharacteristic;
    BLECharacteristic* nodeDataCharacteristic;
    BLECharacteristic* loraCharacteristic;
    BLECharacteristic* radioCharacteristic;
};

#endif /* SesameBLE_h */
