//
//  MapView.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 7/2/21.
//

import SwiftUI
import UIKit
import MapKit

// MapView design
struct MapKitView: UIViewRepresentable {
    let locationManager: CLLocationManager = CLLocationManager()
    var annotations: [Position]
    var authStatus: CLAuthorizationStatus
    
    func updateRegion() -> MKCoordinateRegion {
        // find rectangle for locations)
        var user: CLLocationCoordinate2D
        if (locationManager.authorizationStatus == .authorizedAlways || locationManager.authorizationStatus == .authorizedWhenInUse),
           let loc = locationManager.location?.coordinate {
            user = loc
        } else if annotations.count > 0 {
            user = annotations[0].coordinate
        } else {
            // use default location to determine map view
            user = CLLocationCoordinate2D(latitude: 37.33085612429879, longitude: -122.00746704858705)
        }
        
        var min = user
        var max = user
        for pos in annotations {
            if pos.coordinate.latitude < min.latitude {
                min.latitude = pos.coordinate.latitude
            }
            if pos.coordinate.latitude > max.latitude {
                max.latitude = pos.coordinate.latitude
            }
            if pos.coordinate.longitude < min.longitude {
                min.longitude = pos.coordinate.longitude
            }
            if pos.coordinate.longitude > max.longitude {
                max.longitude = pos.coordinate.longitude
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
        
        // create region to show in map
        let region = MKCoordinateRegion( center: CLLocationCoordinate2D(latitude: lat, longitude:  lon), span: MKCoordinateSpan(latitudeDelta: latd, longitudeDelta: lond))
        
        return region
    }
    
    // create the mapView
    func makeUIView(context: Context) -> MKMapView {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        let region = updateRegion()
        
        // create mapView
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        
        if locationManager.authorizationStatus == .authorizedAlways || locationManager.authorizationStatus == .authorizedWhenInUse {
            mapView.showsUserLocation = true
        } else {
            mapView.showsUserLocation = false
        }
        
        return mapView
    }

    // called to whenever theres a change to the annotations
    func updateUIView(_ view: MKMapView, context: Context) {
        // remove the previous ones and re-add them (in case position has changed)
        view.removeAnnotations(view.annotations)
        view.addAnnotations(annotations)
        
        let region = updateRegion()
        
        // create mapView
        view.setRegion(region, animated: false)
        
        if locationManager.authorizationStatus == .authorizedAlways || locationManager.authorizationStatus == .authorizedWhenInUse {
            view.showsUserLocation = true
        } else {
            view.showsUserLocation = false
        }
    }

    // create coordinator class to handle displaying things on the map
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // Class handles calls to display things on the map
    class Coordinator: NSObject, MKMapViewDelegate {
        // Called to display each annotation on the map
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // check if this annotation is a Position (as opposed to showing userLocation)
            if let pos = annotation as? Position {
                // create marker to show on the map
                let annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: annotation.title!)
                annotationView.markerTintColor = pos.color
                annotationView.glyphText = String(pos.title!.prefix(1)) // set first letter of username
                annotationView.titleVisibility = MKFeatureVisibility.hidden
                return annotationView
            } else {
                // return nil to use standard display for userLocation
                return nil
            }
        }
    }
}


struct MapView: View {
    @EnvironmentObject var locCtrl: LocationController
    let locationManager: CLLocationManager = CLLocationManager()
    @State private var positions: [Position] = [
        Position(coordinate: .init(latitude: 37.33456537483293, longitude:  -122.00893963508311), name: "Bob", color: UIColor.green),
        Position(coordinate: .init(latitude: 37.19588963981751, longitude: -121.98523014927038), name: "Sam", color: UIColor.orange)
    ]
    @State var showLocAlert: Bool = false
    
    var body: some View {
        MapKitView(annotations: positions, authStatus: locCtrl.authStatus)
            .onAppear() {
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
                if locationManager.authorizationStatus == .notDetermined {
                    locationManager.stopUpdatingLocation()
                    locationManager.requestWhenInUseAuthorization()
                } else if locationManager.authorizationStatus == .authorizedAlways || locationManager.authorizationStatus == .authorizedWhenInUse {
                    locationManager.startUpdatingLocation()
                } else {
                    locationManager.stopUpdatingLocation()
                    showLocAlert = true
                }
            }
            .onDisappear() {
                locationManager.stopUpdatingLocation()
            }
            .alert(isPresented: $showLocAlert) {
                Alert(title: Text("Location Services Disabled"), message: Text("To see where you are in relation to other radio devices, enable location services for this app in Settings."))
            }
    }
}
