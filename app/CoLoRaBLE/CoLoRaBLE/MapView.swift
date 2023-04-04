//
//  MapView.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 7/2/21.
//

import SwiftUI
import UIKit
import MapKit


// Class to hold an annotation to show on the map
class Position: MKPointAnnotation {
    var id = UUID()
    var name: String
    var color: UIColor
    var nodeID: Int
    
    init(coord: CLLocationCoordinate2D, name: String, color: UIColor, nodeID: Int) {
        self.name = name
        self.color = color
        self.nodeID = nodeID
        super.init()
        self.coordinate = coord
        self.title = name
        self.subtitle = name
    }
}

// MapView design
struct MapKitView: UIViewRepresentable {
    var nodes: [LoRaNode]
    var nodeMap: [Int: LoRaNode]
    var colors: [UIColor]
    @ObservedObject var region: GPSRegion
    var locCtrl: LocationController
    
    // create the mapView
    func makeUIView(context: Context) -> MKMapView {
        if locCtrl.authStatus == .notDetermined {
            locCtrl.requestAuthorization()
        }
        
        // create mapView
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region.loc, animated: false)
        
        if locCtrl.isAuthorized() {
            mapView.showsUserLocation = true
        } else {
            mapView.showsUserLocation = false
        }
        
        for node in nodes {
            let position = Position(coord: node.coord, name: node.name, color: colors[node.id % colors.count], nodeID: node.id)
            node.position = position
            mapView.addAnnotation(position)
        }
        
        return mapView
    }

    // called to whenever theres a change to the annotations
    func updateUIView(_ view: MKMapView, context: Context) {
        // remove the previous ones and re-add them (in case position has changed)
        for node in nodes {
            if node.position == nil {
                let position = Position(coord: node.coord, name: node.name, color: colors[node.id % colors.count], nodeID: node.id)
                node.position = position
                view.addAnnotation(position)
            } else {
                
            }
        }
        
        if locCtrl.isAuthorized() {
            view.showsUserLocation = true
        } else {
            view.showsUserLocation = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            
        }
        
        func  mapView(_ mapView: MKMapView, clusterAnnotationForMemberAnnotations memberAnnotations: [MKAnnotation]) -> MKClusterAnnotation {
            print("$$$$$$$$$$$$$$$$$$$$$$$$$")
            var cluster = MKClusterAnnotation(memberAnnotations: memberAnnotations)
            for annotation in memberAnnotations {
                if let position = annotation as? Position {
                    print(position.name)
                }
            }
            return cluster
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // check if this annotation is a Position (as opposed to showing userLocation)
            if let pos = annotation as? Position {
                // create marker to show on the map
                let annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: annotation.title!)
                annotationView.markerTintColor = pos.color
                annotationView.clusteringIdentifier = "nodes"
                return annotationView
            } else {
                // return nil to use standard display for userLocation
                return nil
            }
        }
    }
}


struct MapView: View {
    @ObservedObject var data: DataStore
    var bleMgr: BLEmanager
    @State var showLocAlert: Bool = false
    var locCtrl: LocationController = LocationController()
    
    var body: some View {
        MapKitView(nodes: data.nodes, nodeMap: data.loraMap, colors: data.colors, region: data.mapRegion, locCtrl: locCtrl)
            .onAppear() {
                bleMgr.readLora(peripheral: data.peripheral!.periph)
                data.peripheral!.loraTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                    bleMgr.readLora(peripheral: data.peripheral!.periph)
                    bleMgr.readNodeInfo(peripheral: data.peripheral!.periph)
                    data.node!.coord = data.StringToCoord(position: data.deviceGPS)
                    data.node!.position!.coordinate = data.node!.coord
                }
                
                if locCtrl.authStatus == .notDetermined {
                    locCtrl.stopUpdating()
                    locCtrl.requestAuthorization()
                } else if locCtrl.isAuthorized() {
                    locCtrl.startUpdating()
                } else {
                    locCtrl.stopUpdating()
                    showLocAlert = true
                }
            }
            .onDisappear() {
                locCtrl.stopUpdating()
                data.peripheral!.loraTimer!.invalidate()
            }
            .alert(isPresented: $showLocAlert) {
                Alert(title: Text("Location Services Disabled"), message: Text("To see where you are in relation to other radio devices, enable location services for this app in Settings."))
            }
    }
}
