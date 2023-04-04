//
//  CoLoRaBLEApp.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 6/29/21.
//

import SwiftUI

@main
struct CoLoRaBLEApp: App {
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
        }
    }
}
