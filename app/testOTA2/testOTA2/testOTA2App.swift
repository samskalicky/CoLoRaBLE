//
//  testOTA2App.swift
//  testOTA2
//
//  Created by Skalicky, Sam on 4/9/23.
//

import SwiftUI

@main
struct testOTA2App: App {
    var bleMgr: BLEmanager
    
    init() {
        bleMgr = BLEmanager()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bleMgr)
        }
    }
}
