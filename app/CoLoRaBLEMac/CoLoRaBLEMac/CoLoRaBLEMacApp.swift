//
//  CoLoRaBLEMacApp.swift
//  CoLoRaBLEMac
//
//  Created by Skalicky, Sam on 6/17/22.
//

import SwiftUI

@main
struct CoLoRaBLEMacApp: App {
    
    var bleMgr: BLEmanager
    var data: DataStore
    
    init() {
        data = DataStore()
        bleMgr = BLEmanager()
        bleMgr.data = data
    }
        
    var body: some Scene {
        WindowGroup {
            ContentView(bleMgr: bleMgr, data: data)
                .frame(maxWidth: 1440, maxHeight: 900)
        }
    }
}
