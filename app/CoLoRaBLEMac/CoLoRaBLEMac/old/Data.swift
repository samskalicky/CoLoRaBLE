//
//  Data.swift
//  CoLoRaBLEMac
//
//  Created by Skalicky, Sam on 6/21/22.
//

import Foundation
import MapKit

class GPSRegion: ObservableObject {
    @Published var loc: MKCoordinateRegion
    
    init() {
        self.loc = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: 37.33456,
                longitude: -122.0089
            ),
            span: MKCoordinateSpan(
                latitudeDelta: 0.1,
                longitudeDelta: 0.1
            )
        )
    }
}

class LoRaNode: Identifiable, ObservableObject {
    var id: Int
    var name: String
    @Published var rx_rssi: Int
    @Published var rx_snr: Double
    var tx_rssi: Int
    var tx_snr: Double
    var last: Int
    var received: Int
    @Published var coord: CLLocationCoordinate2D
    var position: Position?
    var time: NSDate
    var isSelf: Bool = false
    
    init(id: Int, name: String, rx_rssi: Int, rx_snr: Double, tx_rssi: Int, tx_snr: Double, last: Int, received: Int, coord: CLLocationCoordinate2D) {
        self.id = id
        self.name = name
        self.rx_rssi = rx_rssi
        self.rx_snr = rx_snr
        self.tx_rssi = tx_rssi
        self.tx_snr = tx_snr
        self.last = last
        self.received = received
        self.coord = coord
        self.time = NSDate()
    }
}

class Conversation: Identifiable, ObservableObject {
    var id: Int
    var with: String
    @Published var messages = [ChatMessage]()
    
    init(id: Int, with: String) {
        self.id = id
        self.with = with
    }
}

class ChatMessage: Identifiable, ObservableObject {
    var id: Int
    var msg: String
    var user: String
    var color: NSColor
    var fromMe: Bool
    
    init(id: Int, msg: String, user: String, color: NSColor, fromMe: Bool) {
        self.id = id
        self.msg = msg
        self.user = user
        self.color = color
        self.fromMe = fromMe
    }
}

class DataStore: NSObject, ObservableObject {
    
    var peripheral: Peripheral?
    var username: String = "<empty>"
    @Published var periphs = [PName]()
    var periphMap = [String: Peripheral]()
    @Published var nodes = [LoRaNode]()
    @Published var mapRegion = GPSRegion()
    var deviceGPS: String = "37.33456, -122.0089"
    var nodeMap = [Int: LoRaNode]()
    var node: LoRaNode?
    @Published var conversations = [Conversation]()
    var convMap = [Int:Conversation]()
    var updateTime: NSDate = NSDate()
    
    let colors = [NSColor.blue, NSColor.green, NSColor.red, NSColor.orange, NSColor.purple, NSColor.magenta, NSColor.gray]
    
    override init() {
        super.init()
        conversations.append(Conversation(id: 255, with: "Everyone"))
        convMap[255] = conversations[0]
    }
    
    func fit() -> MKCoordinateRegion {
        let user: CLLocationCoordinate2D = StringToCoord(position: deviceGPS)
        
        // find min & max lat/long for all annotations
        var min = user
        var max = user
        for node in nodes {
            if node.coord.latitude < min.latitude {
                min.latitude = node.coord.latitude
            }
            if node.coord.latitude > max.latitude {
                max.latitude = node.coord.latitude
            }
            if node.coord.longitude < min.longitude {
                min.longitude = node.coord.longitude
            }
            if node.coord.longitude > max.longitude {
                max.longitude = node.coord.longitude
            }
        }
        // compute center
        let lat = (max.latitude - min.latitude)/2 + min.latitude
        let lon = (max.longitude - min.longitude)/2 + min.longitude
        // compute span (delta)
        var latd = (max.latitude - min.latitude)*1.25
        var lond = (max.longitude - min.longitude)*1.25
        // set minimum span
        latd = (latd > 0.00001) ? latd : 0.00001
        lond = (lond > 0.00001) ? lond : 0.00001
        
        let updateRegion = MKCoordinateRegion(center:  CLLocationCoordinate2D(latitude: lat, longitude:  lon), span: MKCoordinateSpan(latitudeDelta: latd, longitudeDelta: lond))
        return updateRegion
    }
    
    func StringToCoord(position: String) -> CLLocationCoordinate2D {
        let array = position.components(separatedBy: ", ")
        if (array.count != 2) {
            return CLLocationCoordinate2DMake(0,0)
        }
        let coord = CLLocationCoordinate2DMake(CLLocationDegrees(Float(array[0])!),CLLocationDegrees(Float(array[1])!))
        return coord
    }
    
    func updateNetwork(info: String) {
        updateTime = NSDate()
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
                        let position = stats["position"] as! String
                        
                        let coord = StringToCoord(position:position)
                        
                        if nodeMap[nodeID] == nil {
                            nodes.append(LoRaNode(id: nodeID, name: "Sesame-"+String(nodeID), rx_rssi: rx_rssi, rx_snr: rx_snr, tx_rssi: tx_rssi, tx_snr: tx_snr, last: last, received: received, coord: coord))
                            nodeMap[nodeID] = nodes.last
                        } else {
                            let node = nodeMap[nodeID]
                            node!.rx_rssi = rx_rssi
                            node!.rx_snr = rx_snr
                            node!.tx_rssi = tx_rssi
                            node!.tx_snr = tx_snr
                            node!.received = received
                            node!.coord = coord
                            
                            if node!.last != last {
                                node!.time = updateTime
                            }
                            node!.last = last
                            
                            if node!.position != nil {
                                node!.position!.coordinate = coord
                            }
                        }
                        
                        if nodeID != node!.id && convMap[nodeID] == nil {
                            conversations.append(Conversation(id: nodeID, with: "Sesame-"+String(nodeID)))
                            convMap[nodeID] = conversations.last
                        }
                        
                        mapRegion.objectWillChange.send()
                        mapRegion.loc = fit()
                    }
                }
            }
        } catch let error as NSError {
            print("unable to parse lora network json: \(String(describing: error.localizedFailureReason))")
            print(info)
        }
    }
    
    func updateRadio(info: String) {
        
    }
    
    func updateNodeData(info: String) {
        
    }
}
