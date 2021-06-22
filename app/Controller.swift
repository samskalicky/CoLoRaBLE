//
//  Controller.swift
//  BTchat
//
//  Created by Skalicky, Sam on 6/11/21.
//
import Combine
import SwiftUI

class Controller : ObservableObject {
    var didChange = PassthroughSubject<Void, Never>()
    let colors = [Color.green, Color.yellow, Color.red, Color.orange, Color.purple, Color.pink]
    var idMap = [String: Int]()
    @Published var messages = [ChatRow]()
    @Published var networkInfo = "{}"
    @Published var network = [NetworkRow]()
    
    /*
     Add message from others
     */
    func addMessage(message: String) {
        for char in message {
            print("character = \(char)")
        }
        let comps = message.components(separatedBy: "\u{1f}")
        if idMap[comps[0]] == nil {
            idMap[comps[0]] = idMap.count % colors.count
        }
        
        messages.append(ChatRow(id: messages.count, msg: ChatMessage(message: comps[1], user: comps[0], color: colors[idMap[comps[0]]!]), Halign: .leading))
        didChange.send(())
    }
    
    /*
     Send a message to others
     */
    func sendMessage(chatMessage: ChatMessage) {
        messages.append(ChatRow(id: messages.count, msg: chatMessage))
        didChange.send(())
    }
    
    func updateNetwork() {
        network.removeAll()
        do {
            if let json = try JSONSerialization.jsonObject(with: Data(networkInfo.utf8), options:[]) as? [String: Any] {
                for(key,value) in json {
                    let nodeID = Int(key)!
                    if let stats = value as? [String: Any] {
                        let rx_rssi = stats["rx_rssi"] as! Int
                        let rx_snr = stats["rx_snr"] as! Double
                        let tx_rssi = stats["tx_rssi"] as! Int
                        let tx_snr = stats["tx_snr"] as! Double
                        let last = stats["last"] as! Int
                        let received = stats["received"] as! Int
                        
                        network.append(NetworkRow(id: nodeID, rx_rssi: rx_rssi, rx_snr: rx_snr, tx_rssi: tx_rssi, tx_snr: tx_snr, last: last, received: received))
                    }
                }
            }
        } catch let error as NSError {
            print("unable to parse lora network json: \(error.localizedFailureReason)")
        }
    }
}
