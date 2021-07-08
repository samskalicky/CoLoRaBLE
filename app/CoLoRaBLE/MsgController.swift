//
//  MsgController.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 7/1/21.
//

import Combine
import SwiftUI

class MsgController : ObservableObject {
    var didChange = PassthroughSubject<Void, Never>()
    let colors = [Color.green, Color.yellow, Color.red, Color.orange, Color.purple, Color.pink]
    var idMap = [String: Int]()
    @Published var messages = [ChatRow]()
    
    // add a message from me
    func sendMessage(message: String) {
        // add message to list
        messages.append(ChatRow(id: messages.count, msg: ChatMessage(msg: message)))
        // notify watchers that something changed
        didChange.send(())
    }
    
    // add a message received from LoRa network
    func addMessage(message: String) {
        // split message by special character
        let comps = message.components(separatedBy: "\u{1f}")
        // add ID for this sender if not seen yet
        if idMap[comps[0]] == nil {
            idMap[comps[0]] = idMap.count
        }
        // add message to list
        messages.append(ChatRow(id: messages.count, msg: ChatMessage(msg: comps[1], user: comps[0], color: colors[idMap[comps[0]]!], fromMe: false), Halign: .leading))
        // notify watchers that something changed
        didChange.send(())
    }
}
