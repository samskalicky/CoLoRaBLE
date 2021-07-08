//
//  DeviceView.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 7/1/21.
//

import SwiftUI
import CoreBluetooth

struct DeviceView: View {
    @EnvironmentObject var bleMgr: BLEmanager
    @EnvironmentObject var msgCtrl: MsgController
    
    var name: String
    @State var bleStatus: String = "unknown"
    @State var bleStatusColor: Color = Color.gray
    
    @State var rssiStr: String = ""
    @State var rssiVisible: Bool = false
    
    var periph: Peripheral
    
    init(name: String, periph: Peripheral) {
        self.name = name
        self.periph = periph
    }
    
    var body: some View {
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
            NavigationLink(destination: MapView()) {
                Text("Map")
            }
            Spacer()
            NavigationLink(destination: SettingsView(periph: periph)) {
                Text("Settings")
            }
            NavigationLink(destination: EmptyView()) {
                EmptyView()
            }
        }.padding()
        ChatView(periph: periph)
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
            .onAppear() {
                if !periph.isConnected {
                    bleMgr.connectTo(peripheral: periph.periph)
                }
            }
    }
}
