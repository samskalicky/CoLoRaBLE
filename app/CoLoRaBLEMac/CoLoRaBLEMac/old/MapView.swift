//
//  MapView.swift
//  CoLoRaBLEMac
//
//  Created by Skalicky, Sam on 6/18/22.
//

import SwiftUI
import MapKit

// Class to hold an annotation to show on the map
class Position: MKPointAnnotation {
    var id = UUID()
    var name: String
    var color: NSColor
    var nodeID: Int
    
    init(coord: CLLocationCoordinate2D, name: String, color: NSColor, nodeID: Int) {
        self.name = name
        self.color = color
        self.nodeID = nodeID
        super.init()
        self.coordinate = coord
        self.title = name
        self.subtitle = name
    }
}

class MKMapViewCoordinator: NSObject, MKMapViewDelegate {
    var parent: MKMapViewRepresentable

    init(_ parent: MKMapViewRepresentable) {
        self.parent = parent
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        parent.region.loc = mapView.region
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
        let annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "MyMarker")
        annotationView.clusteringIdentifier = "nodes"
        if let position = annotation as? Position {
            annotationView.markerTintColor = position.color
        }
        
        return annotationView
    }
}

struct MKMapViewRepresentable: NSViewRepresentable {
    var nodes: [LoRaNode]
    var nodeMap: [Int: LoRaNode]
    var colors: [NSColor]
    @ObservedObject var region: GPSRegion

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region.loc, animated: false)
        
        for node in nodes {
            let position = Position(coord: node.coord, name: node.name, color: colors[node.id % colors.count], nodeID: node.id)
            node.position = position
            mapView.addAnnotation(position)
        }
        
        return mapView
    }
    
    func updateNSView(_ view: MKMapView, context: Context) {        
//        // remove the previous ones and re-add them (in case position has changed)
        for node in nodes {
            if node.position == nil {
                let position = Position(coord: node.coord, name: node.name, color: colors[node.id % colors.count], nodeID: node.id)
                node.position = position
                view.addAnnotation(position)
            } else {
                
            }
        }
        
    }
    
    func makeCoordinator() -> MKMapViewCoordinator {
        MKMapViewCoordinator(self)
    }
}


struct MapView: View {
    @ObservedObject var data: DataStore
    @ObservedObject var region: GPSRegion
    var bleMgr: BLEmanager
    
    var body: some View {
        MKMapViewRepresentable(nodes: data.nodes, nodeMap: data.nodeMap, colors: data.colors, region: data.mapRegion)
            .onAppear() {
                if data.peripheral != nil {
                    bleMgr.readLora(peripheral: data.peripheral!.periph)
                    data.peripheral!.loraTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                        if data.peripheral!.isConnected {
                            bleMgr.readLora(peripheral: data.peripheral!.periph)
                            bleMgr.readGPS(peripheral: data.peripheral!.periph)
                            data.node!.coord = data.StringToCoord(position: data.deviceGPS)
                            data.node!.position?.coordinate = data.node!.coord
                        } else {
                            data.peripheral!.isConnected = false
                        }
                    }
                }
                data.mapRegion.loc = data.fit()
            }
            .onDisappear() {
                if data.peripheral != nil {
                    data.peripheral!.loraTimer?.invalidate()
                }
            }
    }
};
