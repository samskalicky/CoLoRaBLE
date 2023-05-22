//
//  Data.swift
//  CoLoRaBLEMac
//
//  Created by Skalicky, Sam on 6/21/22.
//
import Foundation
import SwiftUI
import CoreBluetooth
import MapKit


class NodeInfo: ObservableObject {
    var position: CLLocationCoordinate2D
    var gps_altitude: Double
    @Published var temperature: Double
    var pressure: Double
    var humidity: Double
    var pressure_altitude: Double
    var current: Double
    @Published var voltage: Double
    
    init() {
        position = CLLocationCoordinate2D()
        gps_altitude = 0
        temperature = 0
        pressure = 0
        humidity = 0
        pressure_altitude = 0
        current = 0
        voltage = 0
    }
    
    init(position: CLLocationCoordinate2D, gps_altitude: Double, temperature: Double, pressure: Double, humidity: Double, pressure_altitude: Double, current: Double, voltage: Double) {
        self.position = position
        self.gps_altitude = gps_altitude
        self.temperature = temperature
        self.pressure = pressure
        self.humidity = humidity
        self.pressure_altitude = pressure_altitude
        self.current = current
        self.voltage = voltage
    }
}

class Periph: Identifiable, Equatable {
    
    var id: Int
    var name: String
    var uuid: String
    var lastSeen: NSDate
    var cbperipheral: CBPeripheral
    var timer: Timer
    var rssiTimer: Timer?
    @Published var info: NodeInfo
    @Published var rssi: String = ""
    @Published var isConnected: Bool = false
    
    init(id: Int, name: String, uuid: String, cbperipheral: CBPeripheral) {
        self.id = id
        self.name = name
        self.uuid = uuid
        self.lastSeen = NSDate()
        self.info = NodeInfo()
        self.isConnected = false
        self.cbperipheral = cbperipheral
        self.timer = Timer()
    }
    
    func startTimer() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            self.lastSeen = NSDate()
        }
    }
    
    func stopTimer() {
        self.timer.invalidate()
    }
    
    static func == (lhs: Periph, rhs: Periph) -> Bool {
        return lhs.id == rhs.id
    }
}

class DataStore: NSObject, ObservableObject {
    
    var deviceViews = [String:DeviceView]()
    
    @Published var currentPeriph: Periph?
    @Published var periphs = [Periph]()
    var periphMap = [String:Periph]()
    var periphTimer: Timer
    let colors = [NSColor.blue, NSColor.green, NSColor.red, NSColor.orange, NSColor.purple, NSColor.magenta, NSColor.gray]
    
    override init() {
        self.periphTimer = Timer()
        super.init()
        
        self.periphTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            // get periphs last seen within 5 seconds
            let filterArray = self.periphs.filter { $0.lastSeen.timeIntervalSinceNow >= -5 }
            self.periphs = filterArray
        }
    }
}
