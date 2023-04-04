//
//  DeviceView.swift
//  CoLoRaBLEMac
//
//  Created by Skalicky, Sam on 6/17/22.
//

import SwiftUI
import MapKit
import CoreBluetooth

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
            Text("GPS: "+String(node.coord.latitude)+", "+String(node.coord.longitude)).onTapGesture(count: 1) {
                let gps = String(node.coord.latitude)+", "+String(node.coord.longitude)
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(gps, forType: .string)                
            }
        }
    }
}

struct DeviceViewSetup<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content, periph: Peripheral, data: DataStore) {
        self.build = build
        data.username = periph.name
    }
    var body: Content {
        build()
    }
}

struct DeviceView: View {
    var name: String
    @ObservedObject var data: DataStore
    var bleMgr: BLEmanager
    
    @State var usernameStr: String = ""
    
    @State var bleStatus: String = "unknown"
    @State var bleStatusColor: Color = Color.gray
    
    @State var rssiStr: String = ""
    @State var rssiVisible: Bool = false
    
    var periph: Peripheral
    
    init(name: String, periph: Peripheral, data: DataStore, bleMgr: BLEmanager) {
        self.name = name
        self.periph = periph
        self.data = data
        self.bleMgr = bleMgr
        _usernameStr = State(initialValue: data.username)
    }
    
    var body: some View {
        VStack {
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
                HStack {
                    Text("Username: ").padding()
                    Spacer()
                    TextField(data.username, text: $usernameStr, onCommit: {
                        data.username = usernameStr
                    }).textFieldStyle(RoundedBorderTextFieldStyle())
                        
                }
            }
            Spacer()
            Text("LoRa Network Info")
                .onAppear() {
                    bleMgr.readLora(peripheral: periph.periph)
                    periph.loraTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                        if periph.periph.state == CBPeripheralState.connected {
                            bleMgr.readLora(peripheral: periph.periph)
                            bleMgr.readGPS(peripheral: periph.periph)
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
            Spacer()
        }.padding()
        .navigationTitle(name)
        .onAppear() {
            if !periph.isConnected {
                bleMgr.connectTo(peripheral: periph.periph)
            }
        }
    }
}
