//
//  SettingsView.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 7/2/21.
//

import SwiftUI
import CoreBluetooth

struct SettingsView: View {
    @EnvironmentObject var bleMgr: BLEmanager
    @EnvironmentObject var loraCtrl: LoraController
    
    var periph: Peripheral
    
    @State var usernameStr: String = ""
    @State var loraVisible: Bool = false
    
    init(periph: Peripheral) {
        self.periph = periph
        _usernameStr = State(initialValue: periph.username)
    }
    
    var body: some View {
        HStack {
            Text("Username: ").padding()
            Spacer()
            TextField("You", text: $usernameStr, onCommit: {
                periph.username = usernameStr
            }).textFieldStyle(RoundedBorderTextFieldStyle())
        }
        Text("LoRa Network Info")
            .onAppear() {
                loraVisible = true
                bleMgr.readLora(peripheral: periph.periph)
                periph.loraTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                    if periph.periph.state == CBPeripheralState.connected && loraVisible {
                        bleMgr.readLora(peripheral: periph.periph)
                    } else {
                        periph.isConnected = false
                    }
                }
            }
            .onDisappear() {
                loraVisible = false
                periph.loraTimer?.invalidate()
            }
        List(loraCtrl.nodes) { node in
            node
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
