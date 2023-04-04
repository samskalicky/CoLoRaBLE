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
    
    func getView(periph: Periph) -> DeviceView {
        if data.deviceViews[periph.uuid] == nil {
            data.deviceViews[periph.uuid] = DeviceView(bleMgr: bleMgr, data: data, periph: periph)
        }
        return data.deviceViews[periph.uuid]!
    }
    
    var body: some View {
        NavigationView {
            List(data.periphs) { peripheral in
                NavigationLink(destination: getView(periph: peripheral)) {
                    Text(peripheral.name)
                        .onTapGesture {
                            
                        }
                }
            }
        }
        .onAppear() {
            bleMgr.startScanning()
            
            if data.currentPeriph != nil {
                if data.currentPeriph!.isConnected {
                    bleMgr.disconnectFrom(peripheral: data.currentPeriph!.cbperipheral)
                }
                data.currentPeriph!.stopTimer()
            }
        }
    }
}
