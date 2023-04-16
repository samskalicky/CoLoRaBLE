
#include "Arduino.h"

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#include "esp_ota_ops.h"

#define SW_VER 0x010000
#define HW_VER 0x0100

#define SERVICE_UUID_OTA                    "c8659210-af91-4ad3-a995-a58d6fd26145" // UART service UUID
#define CHARACTERISTIC_UUID_FW              "c8659211-af91-4ad3-a995-a58d6fd26145"
#define CHARACTERISTIC_UUID_HW_VERSION      "c8659212-af91-4ad3-a995-a58d6fd26145"

#define FULL_PACKET 512

class BLECustomServerCallbacks: public BLEServerCallbacks {
  
};

class otaCallback: public BLECharacteristicCallbacks {
  public:
    esp_ota_handle_t otaHandler;
  
    bool updateFlag = false;
    int packetCnt = 0;
  
    otaCallback() {
      otaHandler = 0;
      updateFlag = false;
      packetCnt = 0;
    }

    void onWrite(BLECharacteristic *pCharacteristic) {
      std::string rxData = pCharacteristic->getValue();
      if (!updateFlag) { //If it's the first packet of OTA since bootup, begin OTA
        Serial.println("BeginOTA");
        esp_ota_begin(esp_ota_get_next_update_partition(NULL), OTA_SIZE_UNKNOWN, &otaHandler);
        updateFlag = true;
      }
      if (rxData.length() > 0) {
        Serial.println(packetCnt++);
        esp_ota_write(otaHandler, rxData.c_str(), rxData.length());
        if (rxData.length() != FULL_PACKET) {
          updateFlag = false;
          esp_ota_end(otaHandler);
          Serial.println("EndOTA");
          if (ESP_OK == esp_ota_set_boot_partition(esp_ota_get_next_update_partition(NULL))) {
            delay(2000);
            esp_restart();
          } else {
            Serial.println("Upload Error");
            packetCnt = 0;
          }
        }
      }
    }
};

void setup() {
  Serial.begin(115200);
  Serial.println("Serial Begin");
  Serial.print("SW v");
  Serial.print((SW_VER >> 16) & 0xFF); // major
  Serial.print(".");
  Serial.print((SW_VER >> 8) & 0xFF); // minor
  Serial.print(".");
  Serial.println((SW_VER >> 0) & 0xFF); // patch
  
  Serial.print("HW v");
  Serial.print((HW_VER >> 8) & 0xFF); // major
  Serial.print(".");
  Serial.println((HW_VER >> 0) & 0xFF); // minor

  // Create the BLE Device
  BLEDevice::init("UART Service");

  // Create the BLE Server
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new BLECustomServerCallbacks());

  // Create the BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID_OTA);

  // Create a BLE Characteristic

  BLECharacteristic *pVersionCharacteristic = pService->createCharacteristic(
                             CHARACTERISTIC_UUID_HW_VERSION,
                             BLECharacteristic::PROPERTY_READ
                           );

  BLECharacteristic *pOtaCharacteristic = pService->createCharacteristic(
                         CHARACTERISTIC_UUID_FW,
                         BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_WRITE
                       );

  pOtaCharacteristic->addDescriptor(new BLE2902());
  pOtaCharacteristic->setCallbacks(new otaCallback());

  // Start the service(s)
  pService->start();

  // Start advertising
  pServer->getAdvertising()->addServiceUUID(SERVICE_UUID_OTA);
  pServer->getAdvertising()->start();

  uint8_t hardwareVersion[5] = {(HW_VER >> 8) & 0xFF, (HW_VER >> 0) & 0xFF, (SW_VER >> 16) & 0xFF, (SW_VER >> 8) & 0xFF, (SW_VER >> 0) & 0xFF};
  pVersionCharacteristic->setValue((uint8_t*)hardwareVersion, 5);
}

void loop() {
  // put your main code here, to run repeatedly:

}
