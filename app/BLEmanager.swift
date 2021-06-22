//
//  BLEmanager.swift
//  BTchat
//
//  Created by Skalicky, Sam on 6/12/21.
//

import CoreBluetooth
import SwiftUI
import Foundation

class Peripheral: Identifiable {
    let id: Int
    let name: String
    let rssi: Int
    @Published var rssiStr: String = ""
    let periph: CBPeripheral
    @Published var isConnected: Bool = false
    var msg: CBCharacteristic?
    var lora: CBCharacteristic?
    var rssiTimer: Timer?
    var loraTimer: Timer?
    
    init(id: Int, name: String, rssi: Int, periph: CBPeripheral) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.rssiStr = String(rssi)
        self.periph = periph
    }
}

struct PeriphUUID: Identifiable {
    let id: Int
    let name: String
}

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    let serviceUUID = CBUUID.init(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
    let characteristicMsgUUID = CBUUID.init(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")
    let characteristicLoraUUID = CBUUID.init(string: "9971353b-aa92-491d-a960-734cd69d1f5e")

    var ctrl: Controller?
    var myCentral: CBCentralManager!
    
    @Published var peripherals = [PeriphUUID]()
    var peripheralMap = [String: Peripheral]()
  
    override init() {
        super.init()

        myCentral = CBCentralManager(delegate: self, queue: nil)
        myCentral.delegate = self
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        }
    }
    
    func startScanning() {
        print("startScanning")
        myCentral.scanForPeripherals(withServices: nil, options: nil)
    }
    
    func stopScanning() {
        print("stopScanning")
        myCentral.stopScan()
    }
    
    func connectTo(peripheral: CBPeripheral) {
        self.myCentral.connect(peripheral, options: nil)
    }
 
    /*
     Called when discovering peripherals (for each)
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        var peripheralName: String!
        
        if let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            peripheralName = name
        }
        else {
            peripheralName = "Unknown"
        }
       
        let newPeripheral = Peripheral(id: peripherals.count, name: peripheralName, rssi: RSSI.intValue, periph: peripheral)
        let uuid = peripheral.identifier.uuidString
        
        if newPeripheral.name.contains("Sesame") {
            peripheral.delegate = self
            if peripheralMap[uuid] == nil {
                peripherals.append(PeriphUUID(id: newPeripheral.id, name: uuid))
                peripheralMap[uuid] = newPeripheral
            }
        }
    }
    
    /*
     Called on connect to peripheral, to discover services
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("connected")
        self.peripheralMap[peripheral.identifier.uuidString]?.isConnected = true
        peripheral.discoverServices([serviceUUID])
        
        let periph = self.peripheralMap[peripheral.identifier.uuidString]!
        periph.rssiTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if peripheral.state == CBPeripheralState.connected {
                peripheral.readRSSI()
            } else {
                periph.isConnected = false
            }
        }
    }
    
    /*
     Called on disconnect of peripheral
     */
    func centralManager (_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("disconnected")
        self.peripheralMap[peripheral.identifier.uuidString]?.isConnected = false
    }
    
    /*
     Called when discovering services (for each)
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                if service.uuid == serviceUUID {
                    peripheral.discoverCharacteristics([characteristicMsgUUID, characteristicLoraUUID], for: service)
                }
            }
        }
    }
    
    /*
     Called when discovering characteristics (for each)
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if characteristic.uuid == characteristicMsgUUID {
                    self.peripheralMap[peripheral.identifier.uuidString]?.msg = characteristic
                    peripheral.setNotifyValue(true, for: characteristic) // config receiving notifications from device
                    print("msgCh")
                }
                
                if characteristic.uuid == characteristicLoraUUID {
                    self.peripheralMap[peripheral.identifier.uuidString]?.lora = characteristic
                    print("loraCh")
                }
            }
        }
    }
    
    /*
     Called when device notifies that value has changed (ie. received new data)
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let str = NSString(data: characteristic.value!, encoding: String.Encoding.utf8.rawValue)! as String

        let periph = self.peripheralMap[peripheral.identifier.uuidString]

        if characteristic == periph?.msg {
            if ctrl != nil {
                ctrl?.addMessage(message: str)
            }
        } else if characteristic == periph?.lora {
            if ctrl != nil {
                ctrl?.networkInfo = str
                ctrl?.updateNetwork()
            }
        }
    }
    
    /*
     * Called when readRSSI is called
     */
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        let periph = self.peripheralMap[peripheral.identifier.uuidString]!
        periph.rssiStr = RSSI.stringValue
    }
    
    /*
     Writes a new value to device
     */
    func writeMsg( peripheral: CBPeripheral, withValue value: String) {
        if self.peripheralMap[peripheral.identifier.uuidString]!.isConnected {
            let valueString = (value as NSString).data(using: String.Encoding.utf8.rawValue)
            if let msg = self.peripheralMap[peripheral.identifier.uuidString]?.msg {
                peripheral.writeValue(valueString!, for: msg, type: .withResponse)
            }
        }
    }
    
    /*
     Reads the current value (if notifications are disabled, otherwise just re-reads the same value after notification)
     */
    func readMsg( peripheral: CBPeripheral) -> String {
        if let msg = self.peripheralMap[peripheral.identifier.uuidString]?.msg {
            peripheral.readValue(for: msg)
            return NSString(data: msg.value!, encoding: String.Encoding.utf8.rawValue)! as String
        }
        return "Error reading msg"
    }
    
    /*
     Reads the current value (if notifications are disabled, otherwise just re-reads the same value after notification)
     */
    func readLora( peripheral: CBPeripheral) {
        if let lora = self.peripheralMap[peripheral.identifier.uuidString]?.lora {
            peripheral.readValue(for: lora)
        }
    }
}
