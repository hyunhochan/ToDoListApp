//
//  MapViewController.swift
//  ToDoListApp
//
//  Created by hyunho on 6/17/24.
//

import Foundation
import UIKit
import MapKit

class MapViewController: UIViewController {
    var latitude: Double?
    var longitude: Double?
    @IBOutlet weak var mapView: MKMapView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMap()
    }

    func setupMap() {
        guard let lat = latitude, let lon = longitude else { return }
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        mapView.setRegion(region, animated: true)
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
    }
}
