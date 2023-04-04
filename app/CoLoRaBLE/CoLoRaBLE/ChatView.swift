//
//  ChatView.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 7/2/21.
//

import SwiftUI

struct ChatRow: View, Identifiable {
    var id: Int
    var msg: ChatMessage
    var Halign: Alignment = .trailing
    
    var body: some View {
        if msg.fromMe {
            HStack {
                Spacer()
                Text(msg.msg)
                    .bold()
                    .padding(10)
                    .foregroundColor(Color.white)
                    .background(Color(msg.color), alignment: Halign)
                    .cornerRadius(15)
            }
        } else {
            HStack {
                Text(msg.user)
                Text(msg.msg)
                    .bold()
                    .padding(10)
                    .foregroundColor(Color.white)
                    .background(Color(msg.color), alignment: Halign)
                    .cornerRadius(15)
            }
        }
    }
}

struct ConversationView: View {
    var data: DataStore
    var bleMgr: BLEmanager
    @ObservedObject var conversation: Conversation
    var nodeInfo: NodeInfo?
    
    @State var composedMessage: String = ""
    
    @State var envStr: String = "Temp:     | Humid:     | Pressure:        "
    @State var battStr: String = "Battery Voltage:        | Current:      "
    
    func sendMessage() {
        let msg = ChatMessage(id: conversation.messages.count, msg: composedMessage, user: data.username, color: data.colors[data.node!.id % data.colors.count], fromMe: true)
        conversation.messages.append(msg)
        
        //create packet format to send {from nodeID, from username, message}
        let msgx = String(data.node!.id) + String(UnicodeScalar(31)!) + data.username + String(UnicodeScalar(31)!) + composedMessage
        //insert the destination nodeID for the conversation as byte [0:255]
        var val = (msgx as NSString).data(using: String.Encoding.utf8.rawValue)!
        val.insert(UInt8(conversation.id), at: 0)
        
        bleMgr.writeMsg(peripheral: data.peripheral!.periph, value: val)
        composedMessage = ""
    }
    
    var body: some View {
        VStack {
            List(conversation.messages) { msg in
                ChatRow(id: msg.id, msg: msg, Halign: .leading)
            }
            HStack {
                TextField("Message...", text: $composedMessage)
                    .frame(minHeight: CGFloat(30))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Send") {
                    sendMessage()
                }.padding(CGFloat(5))
                .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, lineWidth: 2)
                    )
            }.frame(minHeight: CGFloat(50)).padding()
            if nodeInfo != nil {
                HStack {
                    Text(envStr)
                        .onReceive(nodeInfo!.$temperature) { info in
                            envStr = String(format: "Temp: %2.0f℃  |  Humid: %2.0f%% | Pressure: %4.0f mPa", nodeInfo!.temperature, nodeInfo!.humidity, nodeInfo!.pressure)
                        }
                    Spacer()
                }.padding().frame(height: 15)
                HStack {
                    Text(battStr)
                        .onReceive(nodeInfo!.$voltage) { info in
                            battStr = String(format: "Battery Voltage: %1.2f V  |  Current: %3.0f mA", nodeInfo!.voltage, nodeInfo!.current)
                        }
                    Spacer()
                }.padding().frame(height: 15)
            }
        }
    }
}

struct ChatView: View {
    var bleMgr: BLEmanager
    @ObservedObject var data: DataStore
    
    var body: some View {
        NavigationView {
            List(data.conversations) { conversation in
                if conversation.id == 255 {
                    NavigationLink(destination: ConversationView(data: data, bleMgr: bleMgr, conversation: conversation, nodeInfo: nil)) {
                        Text(conversation.with)
                    }
                } else {
                    NavigationLink(destination: ConversationView(data: data, bleMgr: bleMgr, conversation: conversation, nodeInfo: data.infoMap[conversation.id])) {
                        Text(conversation.with)
                    }
                }
            }
        }
    }
}
