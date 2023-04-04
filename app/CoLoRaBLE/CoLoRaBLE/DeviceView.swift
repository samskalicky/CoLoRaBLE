//
//  DeviceView.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 7/1/21.
//

import SwiftUI
import CoreBluetooth

struct DeviceView: View {
    var name: String
    @ObservedObject var data: DataStore
    var bleMgr: BLEmanager
    
    @State var usernameStr: String = ""
    
    @State var bleStatus: String = "unknown"
    @State var bleStatusColor: Color = Color.gray
    
    @State var rssiStr: String = ""
    @State var rssiVisible: Bool = false
    
    @State var envStr: String = "Temp:     | Humid:     | Pressure:        "
    @State var battStr: String = "Battery Voltage:        | Current:      "
    
    var periph: Peripheral
    
    init(name: String, periph: Peripheral, data: DataStore, bleMgr: BLEmanager) {
        self.name = name
        self.periph = periph
        self.data = data
        self.bleMgr = bleMgr
        _usernameStr = State(initialValue: data.username)
    }
    
    var body: some View {
        VStack(spacing: 1) {
            HStack {
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
                Spacer()
                HStack {
                    Text("BT RSSI: ")
                        .onAppear() {
                            rssiVisible = true
                            periph.rssiTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                                if periph.periph.state == CBPeripheralState.connected && rssiVisible {
                                    periph.periph.readRSSI()
                                } else {
                                    periph.isConnected = false
                                }
                            }
                        }
                        .onDisappear() {
                            rssiVisible = false
                            periph.rssiTimer?.invalidate()
                        }
                    Text(rssiStr)
                        .frame(width: 50)
                        .onReceive(periph.$rssi) { val in
                            rssiStr = val
                        }
                }
                Spacer()
                NavigationLink(destination: MapView(data: data, bleMgr:bleMgr)) {
                    Text("Map")
                }
                Spacer()
                NavigationLink(destination: SettingsView(data:data, bleMgr:bleMgr, periph: periph)) {
                    Text("Settings")
                }
                NavigationLink(destination: EmptyView()) {
                    EmptyView()
                }
            }.padding()
            HStack {
                Text(envStr)
                    .onReceive(data.$info) { info in
                        if info != nil {
                            envStr = String(format: "Temp: %2.0f℃ | Humid: %2.0f%% | Pressure: %4.0f mPa", info!.temperature, info!.humidity, info!.pressure)
                        }
                    }
                Spacer()
            }.padding().frame(height: 20)
            HStack {
                Text(battStr)
                    .onReceive(data.$info) { info in
                        if info != nil {
                            battStr = String(format: "Battery Voltage: %1.2f V | Current: %3.0f mA", info!.voltage, info!.current)
                        }
                    }
                Spacer()
            }.padding()
        }
        ChatView(bleMgr: bleMgr, data: data)
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
            .onAppear() {
                if !periph.isConnected {
                    bleMgr.connectTo(peripheral: periph.periph)
                }
                
                bleMgr.readLora(peripheral: data.peripheral!.periph)
                data.peripheral!.loraTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                    if data.peripheral!.isConnected {
                        bleMgr.readLora(peripheral: data.peripheral!.periph)
                        bleMgr.readNodeInfo(peripheral: data.peripheral!.periph)
                        data.node!.coord = data.StringToCoord(position: data.deviceGPS)
                        data.node!.position?.coordinate = data.node!.coord
                    } else {
                        bleMgr.connectTo(peripheral: periph.periph)
                    }
                }
            }
            .onDisappear() {
                data.peripheral!.loraTimer?.invalidate()
            }
    }
}
