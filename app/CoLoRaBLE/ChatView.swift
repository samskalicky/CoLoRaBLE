//
//  ChatView.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 7/2/21.
//

import SwiftUI

struct ChatMessage {
    var msg: String
    var user: String = "me"
    var color: Color = .blue
    var fromMe: Bool = true
}

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
                    .background(msg.color, alignment: Halign)
                    .cornerRadius(15)
            }
        } else {
            HStack {
                Text(msg.user)
                Text(msg.msg)
                    .bold()
                    .padding(10)
                    .foregroundColor(Color.white)
                    .background(msg.color, alignment: Halign)
                    .cornerRadius(15)
            }
        }
    }
}

struct ChatView: View {
    @EnvironmentObject var bleMgr: BLEmanager
    @EnvironmentObject var msgCtrl: MsgController
    
    @State var composedMessage: String = ""
    
    var periph: Peripheral
    
    var body: some View {
        List(msgCtrl.messages) { msg in
            msg
        }
        HStack {
            TextField("Message...", text: $composedMessage).frame(minHeight: CGFloat(30))
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button("Send") {
                msgCtrl.sendMessage(message: composedMessage)
                let msg = periph.username + "\u{1f}" + composedMessage
                bleMgr.writeMsg(peripheral: periph.periph, withValue: msg)
                composedMessage = ""
            }.padding(CGFloat(5))
            .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue, lineWidth: 2)
                )
        }.frame(minHeight: CGFloat(50)).padding()
    }
}
