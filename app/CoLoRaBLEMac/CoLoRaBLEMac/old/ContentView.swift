//
//  ContentView.swift
//  CoLoRaBLEMac
//
//  Created by Skalicky, Sam on 6/17/22.
//

import SwiftUI

struct ContentView: View {
    var bleMgr: BLEmanager
    @ObservedObject var data: DataStore
    
    var body: some View {
        TabView {
            NavigationView {
                List(data.periphs) { pname in
                    let periph = data.periphMap[pname.id]
                    NavigationLink(destination: DeviceViewSetup(DeviceView(name: pname.name, periph: periph!, data: data, bleMgr: bleMgr), periph: periph!, data: data)) {
                        Text(pname.name)
                    }
                }
            }.tabItem {
                Text("Bluetooth Devices")
            }
            MapView(data: data, region: data.mapRegion, bleMgr: bleMgr).tabItem {
                Text("Map")
            }
            ChatView(bleMgr: bleMgr, data: data).tabItem {
                Text("Chat")
            }
        }
        .onAppear() {
            bleMgr.startScanning()
        }
    }
}
