//
//  Devices.swift
//  CoLoRaBLEMac
//
//  Created by Skalicky, Sam on 6/17/22.
//

import SwiftUI
import CoreBluetooth

class Peripheral: Identifiable {
    var id = UUID()
    var name: String
    var nodeID: Int
    let periph: CBPeripheral
    var msg: CBCharacteristic?
    var lora: CBCharacteristic?
    var radio: CBCharacteristic?
    var nodeData: CBCharacteristic?
    var rssiTimer: Timer?
    var loraTimer: Timer?
    @Published var rssi: String = ""
    @Published var isConnected: Bool = false
    
    init(name: String, nodeID: Int, periph: CBPeripheral) {
        self.name = name
        self.nodeID = nodeID
        self.periph = periph
    }
}

struct PName: Identifiable {
    var id: String
    var name: String
}
