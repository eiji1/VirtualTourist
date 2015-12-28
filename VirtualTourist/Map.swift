//
//  Map.swift
//  VirtualTourist
//
//  Created by eiji on 2015/12/01.
//  Copyright © 2015 Udacity. All rights reserved.
//

import CoreData
import CoreLocation

/**
Map class stores currently displayed region. Users can start app from the previous location whenever they finish the app. The region related values are stored in the additional map entity in the object model.
*/
class Map: NSManagedObject {
	
	/// Displaying region size
	@NSManaged var regionSize :Double
	/// Center location (latitude)
	@NSManaged var centerLat: Double
	/// Center location (longitude)
	@NSManaged var centerLon: Double
	/// Created pin objects on this map
	@NSManaged var pins: [Pin] // TODO: Realize customized maps with different pin objects
	
	/// center coordinate
	var center: CLLocationCoordinate2D {
		get { return CLLocationCoordinate2DMake(centerLat, centerLon) }
		set(newCenter) {
			centerLat = newCenter.latitude
			centerLon = newCenter.longitude
		}
	}
	
	/// ctor.
	override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
		super.init(entity: entity, insertIntoManagedObjectContext: context)
	}
	
	/// ctor.
	init(center: CLLocationCoordinate2D, regionSize: Double, context: NSManagedObjectContext) {
		let entity =  NSEntityDescription.entityForName("Map", inManagedObjectContext: context)!
		super.init(entity: entity, insertIntoManagedObjectContext: context)
		self.center = center
		self.regionSize = regionSize
	}
}