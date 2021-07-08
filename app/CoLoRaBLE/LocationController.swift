//
//  LocationController.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 7/7/21.
//

import Combine
import SwiftUI
import MapKit

class LocationController : ObservableObject {
    var didChange = PassthroughSubject<Void, Never>()

    let locationManager: CLLocationManager = CLLocationManager()
    
    init() {
        locationManager.requestWhenInUseAuthorization()
    }

    func getLocation() -> CLLocationCoordinate2D {
        if let loc = locationManager.location?.coordinate {
            return loc
        } else {
            return CLLocationCoordinate2D(latitude: 37.33456537483293, longitude:  -122.00893963508311)
        }
    }
}
