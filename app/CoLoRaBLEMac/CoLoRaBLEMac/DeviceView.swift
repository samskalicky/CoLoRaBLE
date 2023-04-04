//
//  DeviceView.swift
//  CoLoRaBLEMac
//
//  Created by Skalicky, Sam on 6/17/22.
//

import SwiftUI
import MapKit
import CoreBluetooth

struct DeviceView: View {
    var bleMgr: BLEmanager
    @ObservedObject var data: DataStore
    var periph: Periph
    
    @State var isConnected = false
    
    var body: some View {
        Text(periph.name)
            
            .onAppear() {
                if data.currentPeriph != nil {
                    if data.currentPeriph!.isConnected {
                        bleMgr.disconnectFrom(peripheral: data.currentPeriph!.cbperipheral)
                    }
                }
                data.currentPeriph = periph
                if !periph.isConnected {
                    bleMgr.connectTo(peripheral: periph.cbperipheral)
                }
            }
//            .onReceive(periph.$isConnected) { val in
//                isConnected = val
//                if currentPeriph != nil {
//                    print(currentPeriph?.isConnected)
                    //                }&& !currentPeriph!.isConnected {
                    
//                    self.presentationMode.wrappedValue.dismiss()
//                }
    }
}

struct DeviceView_Previews: PreviewProvider {
    static var data = DataStore.sampleData
    static var bleMgr: BLEmanager= BLEmanager()

    static var previews: some View {
        DeviceView(scrum: scrum)
            .background(scrum.theme.mainColor)
            .previewLayout(.fixed(width: 400, height: 60))
    }
}
