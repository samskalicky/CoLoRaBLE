//
//  SettingsView.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 7/2/21.
//

import Combine
import SwiftUI
import MapKit

struct SettingsView: View {
    @State var usernameStr: String = ""
    
    var periph: Peripheral
    
    init(periph: Peripheral) {
        self.periph = periph
        _usernameStr = State(initialValue: periph.username)
    }
    
    var body: some View {
        HStack {
            Text("Username: ").padding()
            Spacer()
            TextField("You", text: $usernameStr, onCommit: {
                periph.username = usernameStr
            }).textFieldStyle(RoundedBorderTextFieldStyle())
        }
        NetworkView(periph: periph)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
