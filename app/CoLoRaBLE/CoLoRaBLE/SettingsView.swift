//
//  SettingsView.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 7/2/21.
//

import Combine
import SwiftUI
import MapKit
import CoreBluetooth
import UniformTypeIdentifiers

struct NetworkRow: View {
    @ObservedObject var node: LoRaNode
    
    var body: some View {
        HStack {
            Text(String(node.id))
            if !node.isSelf {
                let time = Int(-node.time.timeIntervalSinceNow)
                let sec = time % 60
                let min = time/60
                Text("[" + String(min) + ":" + String(format: "%02d", sec) + "]")
            }
            Text("RSSI ")
            Text(String(node.rx_rssi))
            Text("SNR ")
            Text(String(node.rx_snr))
            Text("GPS: "+String(format: "%3.5f", node.coord.latitude)+", "+String(format: "%3.5f", node.coord.longitude)).onTapGesture(count: 1) {
                let gps = String(node.coord.latitude)+", "+String(node.coord.longitude)
                UIPasteboard.general.setValue(gps,
                            forPasteboardType: UTType.plainText.identifier)
            }
        }
    }
}

struct SettingsView: View {
    @State var usernameStr: String = ""
    
    @ObservedObject var data: DataStore
    var bleMgr: BLEmanager
    var periph: Peripheral
    
    
    init(data: DataStore, bleMgr: BLEmanager, periph: Peripheral) {
        self.data = data
        self.bleMgr = bleMgr
        self.periph = periph
        _usernameStr = State(initialValue: data.username)
    }
    
    var body: some View {
        HStack {
            Text("Username: ").padding()
            Spacer()
            TextField(data.username, text: $usernameStr, onCommit: {
                data.username = usernameStr
            }).textFieldStyle(RoundedBorderTextFieldStyle())
        }
        Text("LoRa Network Info")
            .onAppear() {
                bleMgr.readLora(peripheral: periph.periph)
                periph.loraTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                    if periph.periph.state == CBPeripheralState.connected {
                        bleMgr.readLora(peripheral: periph.periph)
                        bleMgr.readNodeInfo(peripheral: periph.periph)
                        data.node!.coord = data.StringToCoord(position: data.deviceGPS)
                        data.node!.position?.coordinate = data.node!.coord
                    } else {
                        periph.isConnected = false
                    }
                }
            }
            .onDisappear() {
                periph.loraTimer?.invalidate()
            }
        if data.nodes.count > 0 {
            List(data.nodes) { node in
                NetworkRow(node: node)
            }
        } else {
            Text("no other nodes found")
        }
//        .navigationTitle("Settings")
//        .navigationBarTitleDisplayMode(.inline)
    }
}
