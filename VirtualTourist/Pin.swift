//
//  Pin.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/30.
//  Copyright © 2015 Udacity. All rights reserved.
//

import Foundation

import UIKit
import MapKit
import CoreData

class Pin: NSManagedObject, MKAnnotation {
	@NSManaged var longitude: Double
	@NSManaged var latitude: Double
	@NSManaged var timestamp: String
	@NSManaged var photos: [Photo]
	@NSManaged var map: Map?

	var coordinate: CLLocationCoordinate2D {
		get { return CLLocationCoordinate2DMake(latitude, longitude) }
		set(newCoordinate) {
			latitude = newCoordinate.latitude
			longitude = newCoordinate.longitude
		}
	}
	
	var identifier : String {
		return "id_\(latitude)\(longitude)_\(timestamp)"
		// TODO: Hashing this string is better.
	}
	
	override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
		super.init(entity: entity, insertIntoManagedObjectContext: context)
	}
	
	init(coordinate: CLLocationCoordinate2D, context: NSManagedObjectContext) {
		let entity =  NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
		super.init(entity: entity, insertIntoManagedObjectContext: context)
		self.coordinate = coordinate
		// to identifying this object uniquely
		self.timestamp = "\(NSDate().timeIntervalSince1970 * 1000)"
	}

	func show(mapView: MKMapView) {
		mapView.removeAnnotation(self)
		mapView.addAnnotation(self)
	}
}

