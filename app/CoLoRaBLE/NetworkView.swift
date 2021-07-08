//
//  NetworkView.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 7/2/21.
//

import SwiftUI

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
