//
//  ContentView.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 6/29/21.
//

import SwiftUI

// main view for the app
struct ContentView: View {
    @EnvironmentObject var bleMgr: BLEmanager
    
    var body: some View {
        NavigationView {
            List(bleMgr.periphs) { pname in
                let periph = bleMgr.periphMap[pname.id]
                NavigationLink(destination: DeviceView(name: pname.name, periph: periph!)) {
                    Text(pname.name)
                }
            }
            .navigationBarTitle("Bluetooth Devices")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear() {
            bleMgr.startScanning()
        }
        .onDisappear() {
            bleMgr.stopScanning()
            print("stopped scanning")
        }
        if !bleMgr.simulating {
            Button("Simulate Device") {
                bleMgr.simulateDevice()
            }
        }
    }
}
