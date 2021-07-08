//
//  LoraController.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 7/1/21.
//

import Combine
import SwiftUI

class LoraController : ObservableObject {
    var didChange = PassthroughSubject<Void, Never>()
    @Published var nodes = [NetworkRow]()
    
    func updateNetwork(info: String) {
        nodes.removeAll()
        do {
            if let json = try JSONSerialization.jsonObject(with: Data(info.utf8), options: []) as? [String: Any] {
                for (key,val) in json {
                    let nodeID = Int(key)!
                    if let stats = val as? [String: Any] {
                        let rx_rssi = stats["rx_rssi"] as! Int
                        let rx_snr = stats["rx_snr"] as! Double
                        let tx_rssi = stats["tx_rssi"] as! Int
                        let tx_snr = stats["tx_snr"] as! Double
                        let last = stats["last"] as! Int
                        let received = stats["received"] as! Int
                        
                        nodes.append(NetworkRow(id: nodeID, rx_rssi: rx_rssi, rx_snr: rx_snr, tx_rssi: tx_rssi, tx_snr: tx_snr, last: last, received: received))
                    }
                }
            }
        } catch let error as NSError {
            print("unable to parse lora network json: \(String(describing: error.localizedFailureReason))")
        }
    }
}
