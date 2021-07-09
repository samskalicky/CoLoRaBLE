//
//  CoLoRaBLEApp.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 6/29/21.
//

import SwiftUI

@main
struct CoLoRaBLEApp: App {
    var msgCtrl: MsgController
    var loraCtrl: LoraController
    var locCtrl: LocationController
    var bleMgr: BLEmanager
    
    init() {
        msgCtrl = MsgController()
        loraCtrl = LoraController()
        locCtrl = LocationController()
        bleMgr = BLEmanager()
        bleMgr.loraCtrl = loraCtrl
        bleMgr.msgCtrl = msgCtrl
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(msgCtrl)
                .environmentObject(loraCtrl)
                .environmentObject(locCtrl)
                .environmentObject(bleMgr)
        }
    }
}
