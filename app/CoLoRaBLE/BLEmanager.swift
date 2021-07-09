//
//  BLEmanager.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 7/1/21.
//

import SwiftUI
import CoreBluetooth

class BLEmanager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var msgCtrl: MsgController?
    var loraCtrl: LoraController?
    var simulating: Bool = false
    
    @Published var periphs = [PName]()
    @Published var periphMap = [String: Peripheral]()
    
    let serviceUUID = CBUUID.init(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
    let msgCharacteristicUUID = CBUUID.init(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")
    let loraCharacteristicUUID = CBUUID.init(string: "9971353b-aa92-491d-a960-734cd69d1f5e")
    
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
        // connect if its a real device, do nothing for sim
        if peripheral as? SimulatedCBPeripheral == nil {
            centralMgr.connect(peripheral, options: nil)
        }
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
            let periph = Peripheral(name: pname, periph: peripheral)
            let uuid = peripheral.identifier.uuidString
            peripheral.delegate = self
            // add this new device to the map if we havent seen it before
            if periphMap[uuid] == nil {
                periphs.append(PName(id: uuid, name: pname))
                periphMap[uuid] = periph
            }
        }
    }
    
    // called when a peripheral is connected
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if let periph = periphMap[peripheral.identifier.uuidString] {
            // set that this device is connected
            periph.isConnected = true
            // continue discovering services for this device
            peripheral.discoverServices([serviceUUID])
        }
    }
    
    // call when a peripheral is disconnected
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let periph = periphMap[peripheral.identifier.uuidString] {
            periph.isConnected = false
        }
    }
    
    // called for each service discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                if service.uuid == serviceUUID {
                    // continue discovering characteristics for this device
                    peripheral.discoverCharacteristics([msgCharacteristicUUID, loraCharacteristicUUID], for: service)
                }
            }
        }
    }
    
    // called for each characteristic discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if let periph = periphMap[peripheral.identifier.uuidString] {
                    if characteristic.uuid == msgCharacteristicUUID {
                        periph.msg = characteristic
                        peripheral.setNotifyValue(true, for: characteristic)
                    }
                    if characteristic.uuid == loraCharacteristicUUID {
                        periph.lora = characteristic
                    }
                }
            }
        }
    }
    
    // called when device notifies phone that the value has changed (ie. received new data)
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let periph = periphMap[peripheral.identifier.uuidString] {
            let str = NSString(data: characteristic.value!, encoding: String.Encoding.utf8.rawValue)! as String
            if characteristic == periph.msg {
                msgCtrl!.addMessage(message: str)
            } else if characteristic == periph.lora {
                loraCtrl!.updateNetwork(info: str)
            }
        }
    }
    
    // called when readRSSI is called
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let periph = periphMap[peripheral.identifier.uuidString] {
            periph.rssi = RSSI.stringValue
        }
    }
    
    // write a new value to the device
    func writeMsg(peripheral: CBPeripheral, withValue value: String) {
        if peripheral as? SimulatedCBPeripheral == nil {
            if let periph = periphMap[peripheral.identifier.uuidString] {
                if periph.isConnected {
                    let val = (value as NSString).data(using: String.Encoding.utf8.rawValue)
                    if let msg = periph.msg {
                        peripheral.writeValue(val!, for: msg, type: .withResponse)
                    }
                }
            }
        } else {
            // split message by special character
            let comps = value.components(separatedBy: "\u{1f}")
            let othMsg = "sim" + "\u{1f}" + "echoed '" + comps[1] + "'"
            msgCtrl!.addMessage(message: othMsg)
        }
    }
    
    // async request to read lora network info
    func readLora(peripheral: CBPeripheral) {
        if peripheral as? SimulatedCBPeripheral == nil {
            if let periph = periphMap[peripheral.identifier.uuidString] {
                if periph.isConnected {
                    if let lora = periph.lora {
                        peripheral.readValue(for: lora)
                    }
                }
            }
        }
    }
    
    // simulate a device for testing
    func simulateDevice() {
        simulating = true
        let uuid = "simulated-device"
        if periphMap[uuid] == nil {
            let pname = PName(id: uuid, name: "Sesame-sim")
            let peripheral = SimulatedCBPeripheral()
            let periph = Peripheral(name: "Sesame-sim", periph: peripheral)
            periphs.append(pname)
            periphMap[uuid] = periph
        }
    }
}
