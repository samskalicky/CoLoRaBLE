//
//  ContentView.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 6/29/21.
//

import SwiftUI

// main view for the app
struct ContentView: View {
    var bleMgr: BLEmanager
    @ObservedObject var data: DataStore
    
    var body: some View {
        NavigationView {
            List(data.periphs) { pname in
                let periph = data.periphMap[pname.id]
                NavigationLink(destination: DeviceView(name: pname.name, periph: periph!, data: data, bleMgr: bleMgr)) {
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
    }
}
