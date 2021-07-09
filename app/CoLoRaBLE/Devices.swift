//
//  Devices.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 6/29/21.
//

import SwiftUI
import CoreBluetooth

class SimulatedCBPeripheral: CBPeripheral {
    
    init(name: String = "sim") {
        
    }
}

class Peripheral: Identifiable {
    var id = UUID()
    var name: String
    var username: String
    let periph: CBPeripheral
    var msg: CBCharacteristic?
    var lora: CBCharacteristic?
    var rssiTimer: Timer?
    var loraTimer: Timer?
    @Published var rssi: String = ""
    @Published var isConnected: Bool = false
    
    init(name: String, periph: CBPeripheral) {
        self.name = name
        self.periph = periph
        username = "Bob"
    }
}

struct PName: Identifiable {
    var id: String
    var name: String
}
