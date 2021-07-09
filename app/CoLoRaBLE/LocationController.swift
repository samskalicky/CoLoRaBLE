//
//  LocationController.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 7/7/21.
//

import Combine
import SwiftUI
import MapKit

class LocationController : NSObject, ObservableObject, CLLocationManagerDelegate {
    var didChange = PassthroughSubject<Void, Never>()
    @Published var authStatus: CLAuthorizationStatus = .notDetermined
    let locationManager: CLLocationManager = CLLocationManager()
    
    override init() {
        super.init()
//        locationManager.requestWhenInUseAuthorization()
        locationManager.delegate = self
    }
    
    // Invoked when the authorization status changes for this application.
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authStatus = status
        didChange.send(())
    }

    func getLocation() -> CLLocationCoordinate2D {
        if (locationManager.authorizationStatus == .authorizedAlways || locationManager.authorizationStatus == .authorizedWhenInUse),
           let loc = locationManager.location?.coordinate {
            return loc
        } else {
            return CLLocationCoordinate2D(latitude: 37.33456537483293, longitude:  -122.00893963508311)
        }
    }
}
