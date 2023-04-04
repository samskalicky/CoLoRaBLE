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

class NodeInfo: ObservableObject {
    var position: CLLocationCoordinate2D
    var gps_altitude: Double
    @Published var temperature: Double
    var pressure: Double
    var humidity: Double
    var pressure_altitude: Double
    var current: Double
    @Published var voltage: Double
    
    init() {
        position = CLLocationCoordinate2D()
        gps_altitude = 0
        temperature = 0
        pressure = 0
        humidity = 0
        pressure_altitude = 0
        current = 0
        voltage = 0
    }
    
    init(position: CLLocationCoordinate2D, gps_altitude: Double, temperature: Double, pressure: Double, humidity: Double, pressure_altitude: Double, current: Double, voltage: Double) {
        self.position = position
        self.gps_altitude = gps_altitude
        self.temperature = temperature
        self.pressure = pressure
        self.humidity = humidity
        self.pressure_altitude = pressure_altitude
        self.current = current
        self.voltage = voltage
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
    var isSelf: Bool = false
    var time: NSDate = NSDate()
    
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
    var color: UIColor
    var fromMe: Bool
    
    init(id: Int, msg: String, user: String, color: UIColor, fromMe: Bool) {
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
    var loraMap = [Int: LoRaNode]()
    var node: LoRaNode?
    var infoMap = [Int: NodeInfo]()
    @Published var info: NodeInfo?
    @Published var conversations = [Conversation]()
    var convMap = [Int:Conversation]()
    var updateTime: NSDate = NSDate()
    
    let colors = [UIColor.blue, UIColor.green, UIColor.red, UIColor.orange, UIColor.purple, UIColor.magenta, UIColor.gray]
    
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
                        
                        let gps_altitude = stats["gps_altitude"] as! Double
                        let temperature = stats["temperature"] as! Double
                        let pressure = stats["pressure"] as! Double
                        let humidity = stats["humidity"] as! Double
                        let pressure_altitude = stats["pressure_altitude"] as! Double
                        let current = stats["current"] as! Double
                        let voltage = stats["voltage"] as! Double
                        
                        let coord = StringToCoord(position:position)
                        
                        if loraMap[nodeID] == nil {
                            nodes.append(LoRaNode(id: nodeID, name: "Sesame-"+String(nodeID), rx_rssi: rx_rssi, rx_snr: rx_snr, tx_rssi: tx_rssi, tx_snr: tx_snr, last: last, received: received, coord: coord))
                            loraMap[nodeID] = nodes.last
                            
                            infoMap[nodeID] = NodeInfo(position: coord, gps_altitude: gps_altitude, temperature: temperature, pressure: pressure, humidity: humidity, pressure_altitude: pressure_altitude, current: current, voltage: voltage)
                        } else {
                            let node = loraMap[nodeID]
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
                            
                            let nodeInfo = infoMap[nodeID]
                            nodeInfo!.position = coord
                            nodeInfo!.gps_altitude = gps_altitude
                            nodeInfo!.temperature = temperature
                            nodeInfo!.pressure = pressure
                            nodeInfo!.humidity = humidity
                            nodeInfo!.pressure_altitude = pressure_altitude
                            nodeInfo!.voltage = voltage
                            nodeInfo!.current = current
                        }
                        
                        if nodeID != node!.id && convMap[nodeID] == nil {
                            conversations.append(Conversation(id: nodeID, with: "Sesame-"+String(nodeID)))
                            convMap[nodeID] = conversations.last
                        }
                        
                        mapRegion.loc = fit()
                    }
                }
            }
        } catch let error as NSError {
            print("unable to parse lora network json: \(String(describing: error.localizedFailureReason))")
            print(info)
        }
    }
    
    func parseNodeInfo(info: String) -> NodeInfo {
        var nodeInfo = NodeInfo()
        do {
            if let json = try JSONSerialization.jsonObject(with: Data(info.utf8), options: []) as? [String: Any] {
                for (key,val) in json {
                    if key == "position" {
                        if let vstr = val as? String {
                            nodeInfo.position = StringToCoord(position: vstr)
                        }
                    } else if key == "gps_altitude" {
                        if let vfp = val as? Double {
                            nodeInfo.gps_altitude = vfp
                        }
                    } else if key == "temperature" {
                        if let vfp = val as? Double {
                            nodeInfo.temperature = vfp
                        }
                    } else if key == "pressure" {
                        if let vfp = val as? Double {
                            nodeInfo.pressure = vfp
                        }
                    } else if key == "humidity" {
                        if let vfp = val as? Double {
                            nodeInfo.humidity = vfp
                        }
                    } else if key == "pressure_altitude" {
                        if let vfp = val as? Double {
                            nodeInfo.pressure_altitude = vfp
                        }
                    } else if key == "current" {
                        if let vfp = val as? Double {
                            nodeInfo.current = vfp
                        }
                    } else if key == "voltage" {
                        if let vfp = val as? Double {
                            nodeInfo.voltage = vfp
                        }
                    }
                }
            }
        } catch let error as NSError {
            print("unable to parse lora network json: \(String(describing: error.localizedFailureReason))")
            print(info)
        }
        
        return nodeInfo
    }
}
