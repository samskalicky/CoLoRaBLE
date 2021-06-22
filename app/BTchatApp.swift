//
//  BTchatApp.swift
//  BTchat
//
//  Created by Skalicky, Sam on 6/11/21.
//

import SwiftUI

@main
struct BTchatApp: App {
    var ctrl: Controller
    var bleMgr: BLEManager
    
    init() {
        ctrl = Controller()
        bleMgr = BLEManager()
        bleMgr.ctrl = ctrl
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
            .environmentObject(ctrl)
            .environmentObject(bleMgr)
        }
    }
}
