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
        let uuid = peripheral.identifier.uuidString
        data!.peripheral = data!.periphMap[uuid]
        data!.username = data!.peripheral!.name
        
        let name = data!.peripheral!.name
        let nodeID = data!.peripheral!.nodeID
        
        if data!.node != nil {
            data!.node!.isSelf = false
        }
        
        //add yourself if not already added
        if data!.nodeMap[nodeID] == nil {
            let user: CLLocationCoordinate2D = data!.StringToCoord(position: data!.deviceGPS)
            let node = LoRaNode(id: nodeID, name: name, rx_rssi: 0, rx_snr: 0, tx_rssi: 0, tx_snr: 0, last: 0, received: 0, coord: user) 
            node.isSelf = true
            data!.nodes.append(node)
            data!.node = node
            data!.nodeMap[nodeID] = data!.nodes.last
        }
        
        centralMgr.connect(peripheral, options: nil)
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
            
            let periph = Peripheral(name: pname, nodeID: nodeID, periph: peripheral)
            let uuid = peripheral.identifier.uuidString
            peripheral.delegate = self
            // add this new device to the map if we havent seen it before
            if data!.periphMap[uuid] == nil {
                data!.periphs.append(PName(id: uuid, name: pname))
                data!.periphMap[uuid] = periph
            }
        }
    }
    
    // called when a peripheral is connected
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if let periph = data!.periphMap[peripheral.identifier.uuidString] {
            // set that this device is connected
            periph.isConnected = true
            // continue discovering services for this device
            peripheral.discoverServices([serviceUUID])
        }
    }
    
    // call when a peripheral is disconnected
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let periph = data!.periphMap[peripheral.identifier.uuidString] {
            periph.isConnected = false
        }
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
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if let periph = data!.periphMap[peripheral.identifier.uuidString] {
                    if characteristic.uuid == msgCharacteristicUUID {
                        periph.msg = characteristic
                        peripheral.setNotifyValue(true, for: characteristic)
                    } else if characteristic.uuid == loraCharacteristicUUID {
                        periph.lora = characteristic
                    } else if characteristic.uuid == radioCharacteristicUUID {
                        periph.radio = characteristic
                    }  else if characteristic.uuid == nodeDataCharacteristicUUID {
                        periph.nodeData = characteristic
                    }
                }
            }
        }
    }
    
    // called when device notifies that the value has changed (ie. received new data)
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let periph = data!.periphMap[peripheral.identifier.uuidString] {
            var val = characteristic.value!
            if characteristic == periph.msg {
                let toID = Int(val.removeFirst())
                let str = NSString(data: val, encoding: String.Encoding.utf8.rawValue)! as String
                // split message by special character
                let comps = str.components(separatedBy: "\u{1f}")
                let fromID = Int(comps[0])!
                let fromName = comps[1]
                let content = comps[2]
                let msg = ChatMessage(id: -1, msg: content, user: fromName, color: data!.colors[fromID % data!.colors.count], fromMe: false)
                
                if toID == 255 {
                    msg.id = data!.convMap[toID]!.messages.count
                    data!.convMap[toID]!.messages.append(msg)
                } else {
                    if fromID != data!.node!.id && data!.convMap[fromID] == nil {
                        data!.conversations.append(Conversation(id: fromID, with: "Sesame-"+String(fromID)))
                        data!.convMap[fromID] = data!.conversations.last
                    }
                    msg.id = data!.convMap[fromID]!.messages.count
                    data!.convMap[fromID]?.messages.append(msg)
                }
            } else if characteristic == periph.lora {
                let str = NSString(data: val, encoding: String.Encoding.utf8.rawValue)! as String
                data!.updateNetwork(info: str)
            } else if characteristic == periph.radio {
                let str = NSString(data: val, encoding: String.Encoding.utf8.rawValue)! as String
                data!.updateRadio(info: str)
            } else if characteristic == periph.nodeData {
                let str = NSString(data: val, encoding: String.Encoding.utf8.rawValue)! as String
                data!.updateNodeData(info: str)
            }
        }
    }
    
    // async request to read lora network info
    func readLora(peripheral: CBPeripheral) {
        if let periph = data!.periphMap[peripheral.identifier.uuidString] {
            if periph.isConnected {
                if let lora = periph.lora {
                    peripheral.readValue(for: lora)
                }
            }
        }
    }
    
    // async request to read radio info
    func readRadio(peripheral: CBPeripheral) {
        if let periph = data!.periphMap[peripheral.identifier.uuidString] {
            if periph.isConnected {
                if let radio = periph.radio {
                    peripheral.readValue(for: radio)
                }
            }
        }
    }
    
    // async request to read radio info
    func readNodeData(peripheral: CBPeripheral) {
        if let periph = data!.periphMap[peripheral.identifier.uuidString] {
            if periph.isConnected {
                if let nodeData = periph.nodeData {
                    peripheral.readValue(for: nodeData)
                }
            }
        }
    }
    
    func writeMsg(peripheral: CBPeripheral, value: Data) {
        if let periph = data!.periphMap[peripheral.identifier.uuidString] {
            if periph.isConnected {
                if let msg = periph.msg {
                    peripheral.writeValue(value, for: msg, type: .withResponse)
                }
            }
        }
    }
    
    // called when readRSSI is called
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let periph = data!.periphMap[peripheral.identifier.uuidString] {
            periph.rssi = RSSI.stringValue
        }
    }
}
