//
//  DeviceView.swift
//  CoLoRaBLEMac
//
//  Created by Skalicky, Sam on 6/17/22.
//

import SwiftUI
import MapKit
import CoreBluetooth

struct DeviceView: View {
    var bleMgr: BLEmanager
    @ObservedObject var data: DataStore
    var periph: Periph
    
    @State var isConnected = false
    
    @State var bleStatus: String = "unknown"
    @State var bleStatusColor: Color = Color.gray
    @State var rssiStr: String = "?"

    @State var envStr: String = "Temp:     | Humid:     | Pressure:        "

    
    var body: some View {
        VStack {
            Text(periph.name)
                .onAppear() {
                    if data.currentPeriph != nil {
                        if data.currentPeriph!.isConnected {
                            bleMgr.disconnectFrom(peripheral: data.currentPeriph!.cbperipheral)
                        }
                    }
                    data.currentPeriph = periph
                    if !periph.isConnected {
                        bleMgr.connectTo(peripheral: data.currentPeriph!.cbperipheral)
                    }
                }
            HStack {
                Text("BLE: ")
                Text(bleStatus)
                    .foregroundColor(bleStatusColor)
                    .onReceive(periph.$isConnected) { val in
                        if val {
                            bleStatus = "Connected"
                            bleStatusColor = Color.green
                        } else {
                            bleStatus = "Disconnected"
                            bleStatusColor = Color.red
                        }
                    }
                HStack {
                    Text("BT RSSI: ")
                        .onAppear() {
                            periph.rssiTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                                if periph.cbperipheral.state == CBPeripheralState.connected {
                                    periph.cbperipheral.readRSSI()
                                } else {
                                    periph.isConnected = false
                                }
                            }
                        }
                        .onDisappear() {
                            periph.rssiTimer?.invalidate()
                        }
                    Text(rssiStr)
                        .frame(width: 50)
                        .onReceive(periph.$rssi) { val in
                            rssiStr = val
                        }
                }
            } // BLE
            HStack {
                Text(envStr)
                    .onReceive(periph.$info) { info in
                        envStr = String(format: "Temp: %2.0f℃ | Humid: %2.0f%% | Pressure: %4.0f mPa", info.temperature, info.humidity, info.pressure)
                    }
            }
        }
    }
}
