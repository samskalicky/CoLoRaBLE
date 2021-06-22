//
//  ContentView.swift
//  BTchat
//
//  Created by Skalicky, Sam on 6/11/21.
//

import SwiftUI
import CoreBluetooth

struct ChatMessage : Hashable {
    var message: String
    var user: String = "me"
    var color: Color = .blue
    var fromMe: Bool = false
}

struct ChatRow : View, Identifiable {
    var id: Int
    var msg: ChatMessage
    var Halign: Alignment = .trailing
    
    var body: some View {
        if msg.fromMe {
            HStack {
                Group {
                    Spacer()
                    Text(msg.message)
                        .bold()
                        .padding(10)
                        .foregroundColor(Color.white)
                        .background(msg.color)
                        .cornerRadius(15)
                }
            }
        } else {
            HStack {
                Group {
                    Text(msg.user)
                    Text(msg.message)
                        .bold()
                        .padding(10)
                        .foregroundColor(Color.white)
                        .background(msg.color)
                        .cornerRadius(15)
                }
            }
        }
    }
}

struct NetworkRow: View, Identifiable {
    var id: Int
    var rx_rssi: Int
    var rx_snr: Double
    var tx_rssi: Int
    var tx_snr: Double
    var last: Int
    var received: Int
    
    var body: some View {
        HStack {
            Group {
                Text(String(id))
                Text("RSSI")
                Text(String(rx_rssi))
                Text("SNR")
                Text(String(rx_snr))
            }
        }
    }
}

struct DeviceDetail: View {
    @EnvironmentObject var ctrl: Controller
    @EnvironmentObject var bleMgr: BLEManager
    @State var composedMessage: String = ""
    @State var BLEstatus: String = "Unknown"
    @State var BLEcolor: Color = .gray
    @State var rssi: String = ""
    @State var viewID: Int = 0
    @State var username: String = "Bob"
    
    var uuid: PeriphUUID
    
    @State private var writeVal: String = ""
    @State var readVal: String = ""
    
    init(uuid: PeriphUUID) {
        self.uuid = uuid
    }
    
    var body: some View {
        let peripheral = bleMgr.peripheralMap[self.uuid.name]!
        if viewID == 0 {
            HStack {
                Text(BLEstatus)
                    .foregroundColor(BLEcolor)
                    .onReceive(peripheral.$isConnected) { val in
                        if val {
                            BLEstatus = "Connected"
                            BLEcolor = .green
                        } else {
                            BLEstatus = "Disconnected"
                            BLEcolor = .red
                        }
                    }
                Spacer()
                HStack{
                    Text("BT RSSI: ")
                    Text(rssi)
                        .onReceive(peripheral.$rssiStr) { val in
                            rssi = val
                        }
                }
                Spacer()
                Button("Settings") {
                    viewID = 1
                }
            }.padding()
            List(ctrl.messages) { msg in
                msg
            }
            HStack {
                TextField("Message...", text: $composedMessage).frame(minHeight: CGFloat(30))
                Button("Send") {
                    ctrl.sendMessage(chatMessage: ChatMessage(message: composedMessage, fromMe: true))
                    let msg = username + "\u{1f}" + composedMessage
                    bleMgr.writeMsg(peripheral: peripheral.periph, withValue: msg)
                    composedMessage = ""
                }
            }.frame(minHeight: CGFloat(50)).padding()
        } else {
            VStack {
                Text("Settings")
                HStack {
                    Text("Username")
                    Spacer()
                    TextField("You", text: $username)
                }
                Text("LoRa Network")
                    .onAppear() {
                    bleMgr.readLora(peripheral: peripheral.periph)
                    peripheral.loraTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                        if peripheral.periph.state == CBPeripheralState.connected {
                            bleMgr.readLora(peripheral: peripheral.periph)
                            print("lora")
                        } else {
                            peripheral.isConnected = false
                        }
                    }
                }
                .onDisappear() {
                    peripheral.loraTimer?.invalidate()
                }
                List(ctrl.network) { msg in
                    msg
                }
                Button("Save") {
                    viewID = 0
                }
            }.padding()
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var ctrl: Controller
    @EnvironmentObject var bleMgr: BLEManager
    
    var body: some View {
        VStack (spacing: 10) {
            Text("Bluetooth Devices")
                .font(.largeTitle)
                .frame(maxWidth: .infinity, alignment: .center)
            NavigationView {
                VStack {
                    List(bleMgr.peripherals) { uuid in
                        NavigationLink(destination: DeviceDetail(uuid: uuid)
                                        .onAppear {
                                            let peripheral = bleMgr.peripheralMap[uuid.name]!
                                            if !peripheral.isConnected {
                                                bleMgr.connectTo(peripheral: peripheral.periph)
                                            }
                                        }
                        ) {
                            HStack {
                                Text(bleMgr.peripheralMap[uuid.name]!.name)
                                Spacer()
                                Text(String(bleMgr.peripheralMap[uuid.name]!.rssi))
                            }
                        }
                    }.frame(height: 300)
                }
            }
        }
    }
}
