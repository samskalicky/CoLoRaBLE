//
//  MapPoint.swift
//  CoLoRaBLE
//
//  Created by Skalicky, Sam on 7/2/21.
//

import MapKit

// Class to hold an annotation to show on the map
class Position: MKPointAnnotation {
    var id = UUID()
    var name: String
    var color: UIColor
    
    init(coordinate: CLLocationCoordinate2D, name: String, color: UIColor) {
        self.name = name
        self.color = color
        super.init()
        self.coordinate = coordinate
        self.title = name
        self.subtitle = name
    }
}
