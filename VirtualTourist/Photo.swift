//
//  Photo.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/30.
//  Copyright © 2015 Udacity. All rights reserved.
//

import Foundation
import CoreData
import UIKit // shared app

public class Photo : NSManagedObject {
	@NSManaged var url: String
	@NSManaged var identifier: String
	@NSManaged var downloaded: Bool
	@NSManaged var pin: Pin?
	
	override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
		super.init(entity: entity, insertIntoManagedObjectContext: context)
	}
	
	init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
		let entity =  NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
		super.init(entity: entity, insertIntoManagedObjectContext: context)
		url = dictionary[FlickrClient.JSONResponseKeys.Url] as! String
		downloaded = false
		identifier = ""
	}

	static func getPhotoFromResults(results: [[String : AnyObject]]) -> [Photo] {
		
		let sharedApp = (UIApplication.sharedApplication().delegate as! AppDelegate)
		let coreData = sharedApp.coreDataStackManager
		
		var photos = [Photo]()
		for result in results {
			photos.append(Photo(dictionary: result, context:coreData.managedObjectContext))
		}
		return photos
	}
	
	static func checkAllPhotoDownloaded(photos: [Photo]) -> Bool {
		var isDownloaded = true
		for photo in photos {
			isDownloaded = isDownloaded && photo.downloaded
		}
		return isDownloaded
	}
}