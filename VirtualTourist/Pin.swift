//
//  Pin.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/30.
//  Copyright © 2015 eiji & Udacity. All rights reserved.
//

import MapKit
import CoreData

/**
Pin class represents a marker dropped on the map. This Pin object should be persistent data.
*/
class Pin: NSManagedObject, MKAnnotation {
	
	/// Where this pin is located
	@NSManaged var longitude: Double
	/// Where this pin is located
	@NSManaged var latitude: Double
	/// When this pin has been created
	@NSManaged var timestamp: String
	/// Photo objects associated with this location
	@NSManaged var photos: [Photo]
	/// A map object in which this pin is included
	@NSManaged var map: Map?
	/// true: if all photos are successfully downloaded, false otherwise
	@NSManaged var allPhotoDownloaded: Bool
	
	/// Where this pin is located
	var coordinate: CLLocationCoordinate2D {
		get { return CLLocationCoordinate2DMake(latitude, longitude) }
		set(newCoordinate) {
			latitude = newCoordinate.latitude
			longitude = newCoordinate.longitude
		}
	}
	
	/// An identifier string for this object
	var identifier : String {
		return "id_\(latitude)\(longitude)_\(timestamp)"
		// TODO: Hashing this string is better.
	}
	
	/// ctor.
	override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
		super.init(entity: entity, insertIntoManagedObjectContext: context)
	}
	
	/// ctor.
	init(coordinate: CLLocationCoordinate2D, context: NSManagedObjectContext) {
		let entity =  NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
		super.init(entity: entity, insertIntoManagedObjectContext: context)
		self.coordinate = coordinate
		// to identifying this object uniquely
		self.timestamp = "\(NSDate().timeIntervalSince1970 * 1000)"
		allPhotoDownloaded = false
	}

	func show(mapView: MKMapView) {
		mapView.removeAnnotation(self)
		mapView.addAnnotation(self)
	}
	
	func remove(coreDataStack: CoreDataStackManager) {
		// delete photos
		let photoSet = valueForKeyPath("photos") as! NSMutableOrderedSet
		while photoSet.count > 0 {
			let photo = photoSet.objectAtIndex(0) as! Photo
			photo.removeImageFiles()
			photo.remove(coreDataStack)
		}
		// delete pin
		coreDataStack.managedObjectContext.deleteObject(self)
		coreDataStack.saveContext()
	}
	
	// for debugging
	func checkCoredata() {
		print("lon:\(longitude), lat:\(latitude)")
		for photo in photos {
			photo.checkCoredata()
		}
	}
}

