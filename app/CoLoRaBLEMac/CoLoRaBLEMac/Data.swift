//
//  Data.swift
//  CoLoRaBLEMac
//
//  Created by Skalicky, Sam on 6/21/22.
//
import Foundation
import SwiftUI
import CoreBluetooth

class Periph: Identifiable, Equatable {
    
    var id: Int
    var name: String
    var uuid: String
    var lastSeen: NSDate
    var isConnected: Bool
    var cbperipheral: CBPeripheral
    var timer: Timer
    
    init(id: Int, name: String, uuid: String, cbperipheral: CBPeripheral) {
        self.id = id
        self.name = name
        self.uuid = uuid
        self.lastSeen = NSDate()
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

extension DataStore {
    
    convenience init(test:Bool) {
        periphs.append(Periph(id: 0, name: "Test-0", uuid: "zero", cbperipheral: <#T##CBPeripheral#>))
    }
    static let sampleData: DataStore =
    [
        DailyScrum(title: "Design", attendees: ["Cathy", "Daisy", "Simon", "Jonathan"], lengthInMinutes: 10, theme: .yellow),
        DailyScrum(title: "App Dev", attendees: ["Katie", "Gray", "Euna", "Luis", "Darla"], lengthInMinutes: 5, theme: .orange),
        DailyScrum(title: "Web Dev", attendees: ["Chella", "Chris", "Christina", "Eden", "Karla", "Lindsey", "Aga", "Chad", "Jenn", "Sarah"], lengthInMinutes: 5, theme: .poppy)
    ]
}
