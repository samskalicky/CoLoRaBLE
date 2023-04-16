//
//  ContentView.swift
//  testOTA2
//
//  Created by Skalicky, Sam on 4/9/23.
//

import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var bleMgr: BLEmanager
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
            Button("Open File", action: {
                let dialog = NSOpenPanel();
                
                dialog.title                   = "Choose a file| Our Code World";
                dialog.showsResizeIndicator    = true;
                dialog.showsHiddenFiles        = false;
                dialog.allowsMultipleSelection = false;
                dialog.canChooseDirectories = false;
                
                if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
                    let result = dialog.url // Pathname of the file
                    
                    if (result != nil) {
                        let path: String = result!.path
                        //load file                        
                        var bytes = [UInt8]()
                        if let data = NSData(contentsOfFile: path) {

                            var buffer = [UInt8](repeating: 0, count: data.length)
                            data.getBytes(&buffer, length: data.length)
                            bytes = buffer
                        }
                    }
                } else {
                    // User clicked on "Cancel"
                    return
                }
            })
            Button("Update", action: {
                print("update")
                // download latest bin
                var request = URLRequest(url: bleMgr.latestBin!)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let task = URLSession.shared.dataTask(with: bleMgr.latestBin!) { data, response, error in
                    print("in task")
                    if let data = data {
                        print("calling writeBin")
                        bleMgr.writeBin(value:data)
                    }
                }
                task.resume()

            })
        }
        .padding()
        .onAppear() {
            bleMgr.startScanning()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
