//
//  BLEmanager.swift
//  testOTA2
//
//  Created by Skalicky, Sam on 4/9/23.
//

import Foundation
import CoreBluetooth

class BLEmanager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    private var centralMgr: CBCentralManager!
    var periph: CBPeripheral?
    var fwCharacteristic: CBCharacteristic?
    var verCharacteristic: CBCharacteristic?
    
    var latestBin: URL?
    
    let serviceUUIDOTA = CBUUID.init(string: "c8659210-af91-4ad3-a995-a58d6fd26145")
    let characteristicUUIDFW = CBUUID.init(string: "c8659211-af91-4ad3-a995-a58d6fd26145")
    let characteristicUUIDversion = CBUUID.init(string: "c8659212-af91-4ad3-a995-a58d6fd26145")
    
    struct Book: Decodable {
        let title: String
        let author: String
    }
    
    required override init() {
        super.init()
        
        centralMgr = CBCentralManager(delegate: self, queue: nil)
        
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("centralMgs update")
        if central.state == .poweredOn {
            print("poweredOn")
            // start looking for devices
            centralMgr.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    func startScanning() {
        let base_url = "https://raw.githubusercontent.com/samskalicky/CoLoRaBLE/testOTA/device/binaries/"
        let url = URL(string: base_url + "info.json")!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        for (hw,val) in json {
                            print(hw)
                            if let list = val as? [Any] {
                                for entry in list {
                                    if let sw = entry as? [String: String] {
                                        let sw_ver = sw["ver"]!
                                        let sw_bin = sw["bin"]!
                                        print(sw_ver)
                                        print(sw_bin)
                                        
                                        let bin_url = URL(string: base_url + sw_bin)!
                                        self.latestBin = bin_url
                                        print(self.latestBin)
                                    }
                                }
                            }
                        }
                    } else {
                        print("unable to parse info.json")
                    }
                } catch let error as NSError {
                    print("unable to parse info.json: \(String(describing: error.localizedFailureReason))")
                    print(data)
                }
            } else if let error = error {
                print("HTTP Request Failed \(error)")
            }
        }
        task.resume()
        
        print("startScanning")
        if centralMgr.state == .poweredOn {
            print("poweredOn")
            // start looking for devices
            centralMgr.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    func stopScanning() {
        if centralMgr.isScanning {
            centralMgr.stopScan()
        }
    }
    
    // called for each peripheral discovered
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        var pname = "Unknown"
        // get name of device
        if let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            pname = name
        }
        
        if(pname.contains("UART Service")) {
            periph = peripheral;
            peripheral.delegate = self
            
            centralMgr.connect(peripheral, options: nil)
            print(pname)
        }
    }
    
    // called when a peripheral is connected
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("connected to " + peripheral.name!)
        
        // continue discovering services for this device
        peripheral.discoverServices([serviceUUIDOTA])
    }
    
    // called for each service discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                if service.uuid == serviceUUIDOTA {
                    print("found service serviceUUIDOTA")
                    // continue discovering characteristics for this device
                    peripheral.discoverCharacteristics([characteristicUUIDFW,characteristicUUIDversion], for: service)
                    
                }
            }
        }
    }
    
    // called for each characteristic discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if characteristic.uuid == characteristicUUIDFW {
                    print("found characteristicUUIDFW")
                    self.fwCharacteristic = characteristic
                } else if characteristic.uuid == characteristicUUIDversion {
                    print("found characteristicUUIDversion")
                    self.verCharacteristic = characteristic
                    peripheral.readValue(for: characteristic)
                }
            }
        }
    }
    
    // called when device notifies that the value has changed (ie. received new data)
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let val = characteristic.value!
        if characteristic.uuid == characteristicUUIDversion {
            let hw_ver = "\(val[0]).\(val[1])";
            let sw_ver = "\(val[2]).\(val[3]).\(val[4])";
            print("sw ver: ",sw_ver)
            print("hw ver: ",hw_ver)
            
            //write to device
            //            peripheral.writeValue(value, for: msg, type: .withResponse)
        }
    }
    
    func writeBin(value: Data) {
        print("in writeBin")
        
        if let periph = self.periph {
            print("about to writeValue")
            print(value.count)
            let maxSize = 512
            var packetCnt = 0
            for currentIndex in stride(from: 0, to: value.count, by: maxSize) {
                let length = min(maxSize, value.count - currentIndex) // ensures that the last chunk is the remainder of the data
                let endIndex = value.index(currentIndex, offsetBy: length)
                let buffer = [UInt8](value[currentIndex..<endIndex])
                // do something with buffer
                print(packetCnt)
                packetCnt += 1
                periph.writeValue(Data(buffer), for: self.fwCharacteristic!, type: .withResponse)
            }
//            periph.writeValue(value, for: self.fwCharacteristic!, type: .withResponse)
//            let test = NSString("42").data(using: String.Encoding.utf8.rawValue)!
//            periph.writeValue(Data(test), for: self.fwCharacteristic!, type: .withResponse)
            print("wrote value")
        }
        print("done writeBin")
    }
}
