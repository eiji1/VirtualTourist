//
//  Pin.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/30.
//  Copyright © 2015年 Udacity. All rights reserved.
//

import Foundation

import UIKit
import MapKit

final class Pin: NSObject, MKAnnotation {
	
	var coordinate: CLLocationCoordinate2D
	var photos: [Photo] = [Photo]()
	
	init(coordinates: CLLocationCoordinate2D) {
		self.coordinate = coordinates
		super.init()
	}
	
	func show(mapView: MKMapView) {
		mapView.removeAnnotation(self)
		mapView.addAnnotation(self)
	}
	
	func hide(mapView: MKMapView) {
		mapView.removeAnnotation(self)
	}
}

