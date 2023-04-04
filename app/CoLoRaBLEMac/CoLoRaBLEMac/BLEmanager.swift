//
//  BLEmanager.swift
//  CoLoRaBLEMac
//
//  Created by Skalicky, Sam on 6/17/22.
//

import MapKit
import SwiftUI
import CoreBluetooth

class BLEmanager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var data: DataStore?
    
    let serviceUUID = CBUUID.init(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
    let msgCharacteristicUUID = CBUUID.init(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")
    let loraCharacteristicUUID = CBUUID.init(string: "9971353b-aa92-491d-a960-734cd69d1f5e")
    let radioCharacteristicUUID = CBUUID.init(string: "236c1eb8-7179-4a3c-a532-0c164ab912e6")
    let nodeDataCharacteristicUUID = CBUUID.init(string: "d233a9d8-f33e-4e3b-be6c-52914e5947fe")
    
    private var centralMgr: CBCentralManager!
    
    required override init() {
        super.init()
        
        centralMgr = CBCentralManager(delegate: self, queue: nil)
        centralMgr.delegate = self
    }
    
    // called when bluetooth is enabled/disabled for this app
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        }
    }
    
    func startScanning() {
        if centralMgr.state == .poweredOn {
            // start looking for devices
            centralMgr.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    func stopScanning() {
        if centralMgr.isScanning {
            centralMgr.stopScan()
        }
    }
    
    func connectTo(peripheral: CBPeripheral) {
        print("connecting")
        centralMgr.connect(peripheral, options: nil)
    }
    
    func disconnectFrom(peripheral: CBPeripheral) {
        centralMgr.cancelPeripheralConnection(peripheral)
    }
    
    // called for each peripheral discovered
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        var pname = "Unknown"
        // get name of device
        if let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            pname = name
        }
        // check if this is the type of device we're looking for
        if pname.contains("Sesame") {
            let dash = pname.index(after: pname.firstIndex(of: "-")!)
            let nodeID = Int(pname[dash...])!
            
            let uuid = peripheral.identifier.uuidString
            
            // check if we've seen this periph already
            if data!.periphMap[uuid] == nil {
                let periph = Periph(id: nodeID, name: pname, uuid: uuid, cbperipheral: peripheral)
                data!.periphMap[uuid] = periph
                data!.periphs.append(periph)
                peripheral.delegate = self
            } else {
                let periph = data!.periphMap[uuid]!
                // update the last seen time
                periph.lastSeen = NSDate()
                if !data!.periphs.contains(periph) {
                    data!.periphs.append(periph)
                }
            }
        }
    }
    
    // called when a peripheral is connected
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("connected")
        let uuid = peripheral.identifier.uuidString
        
        // continue discovering services for this device
        peripheral.discoverServices([serviceUUID])
        
        data!.periphMap[uuid]!.isConnected = true
        data!.periphMap[uuid]!.startTimer()
    }
    
    // call when a peripheral is disconnected
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("disconnected")
        let uuid = peripheral.identifier.uuidString
        data!.periphMap[uuid]!.isConnected = false
        data!.periphMap[uuid]!.stopTimer()
    }
    
    // called for each service discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                if service.uuid == serviceUUID {
                    // continue discovering characteristics for this device
                    peripheral.discoverCharacteristics([msgCharacteristicUUID, loraCharacteristicUUID, radioCharacteristicUUID, nodeDataCharacteristicUUID], for: service)
                }
            }
        }
    }
    
    // called for each characteristic discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let uuid = peripheral.identifier.uuidString
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if characteristic.uuid == msgCharacteristicUUID {
                    peripheral.setNotifyValue(true, for: characteristic)
                } else if characteristic.uuid == loraCharacteristicUUID {
                } else if characteristic.uuid == radioCharacteristicUUID {
                }  else if characteristic.uuid == nodeDataCharacteristicUUID {
                }
            }
        }
    }
    
    // called when device notifies that the value has changed (ie. received new data)
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let uuid = peripheral.identifier.uuidString
        var val = characteristic.value!
        
    }
    
    // called when readRSSI is called
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        let uuid = peripheral.identifier.uuidString
//            periph.rssi = RSSI.stringValue
    }

}
