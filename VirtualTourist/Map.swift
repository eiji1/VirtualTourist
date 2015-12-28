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
Map class stores currently displayed region. Application users can start map operations from the previous location whenever they finish this application. The region related values are stored in the additional map entity in the object model.
*/
class Map: NSManagedObject {
	@NSManaged var regionSize :Double
	@NSManaged var centerLat: Double
	@NSManaged var centerLon: Double
	@NSManaged var pins: [Pin] // TODO: Realize customized maps with different but persistent pin objects
	
	var center: CLLocationCoordinate2D {
		get { return CLLocationCoordinate2DMake(centerLat, centerLon) }
		set(newCenter) {
			centerLat = newCenter.latitude
			centerLon = newCenter.longitude
		}
	}
	
	override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
		super.init(entity: entity, insertIntoManagedObjectContext: context)
	}
	
	init(center: CLLocationCoordinate2D, regionSize: Double, context: NSManagedObjectContext) {
		let entity =  NSEntityDescription.entityForName("Map", inManagedObjectContext: context)!
		super.init(entity: entity, insertIntoManagedObjectContext: context)
		self.center = center
		self.regionSize = regionSize
	}
}