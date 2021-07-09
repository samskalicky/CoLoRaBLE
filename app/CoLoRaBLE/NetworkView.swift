//
//  NetworkView.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 7/2/21.
//

import SwiftUI
import CoreBluetooth

struct NetworkRow: View, Identifiable {
    var id: Int // node ID
    //node status
    var rx_rssi: Int
    var rx_snr: Double
    var tx_rssi: Int
    var tx_snr: Double
    var last: Int
    var received: Int
    
    var body: some View {
        HStack {
            Text(String(id))
            Text("RSSI ")
            Text(String(rx_rssi))
            Text("SNR ")
            Text(String(rx_snr))
        }
    }
}


struct NetworkView: View {
    @EnvironmentObject var loraCtrl: LoraController
    @EnvironmentObject var bleMgr: BLEmanager
    
    @State var loraVisible: Bool = false

    var periph: Peripheral
    
    var body: some View {
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
        if loraCtrl.nodes.count > 0 {
            List(loraCtrl.nodes) { node in
                node
            }
        } else {
            Text("no other nodes found")
            Spacer()
        }
    }
}
