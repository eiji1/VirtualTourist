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
	
	enum Status : Int16 {
		case NotRetrieved = 0
		case Downloading = 1
		case Downloaded = 2
	}
	
	@NSManaged var url: String
	@NSManaged var identifier: String
	@NSManaged var path: String
	@NSManaged var downloaded: Int16
	@NSManaged var pin: Pin?
	
	override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
		super.init(entity: entity, insertIntoManagedObjectContext: context)
	}
	
	init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
		let entity =  NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
		super.init(entity: entity, insertIntoManagedObjectContext: context)
		url = dictionary[FlickrClient.JSONResponseKeys.Url] as! String
		downloaded = Status.NotRetrieved.rawValue
		identifier = ""
		path = ""
	}

	func remove(coreDataStack: CoreDataStackManager) {
		// delete an image from cache and an underlying file from the Documents directory
		//ImageStorage().removeImage(identifier)
		trace("photo managed object removed:\(ImageStorage().createFileURL(identifier))")
		// remove photo managed object from core data stack
		coreDataStack.managedObjectContext.deleteObject(self)
		coreDataStack.saveContext()
	}
	
	func removeImageFiles() {
		let imageStorage = ImageStorage()
		if imageStorage.imageFileExists(identifier) {
			// delete an image from cache and an underlying file from the Documents directory
			imageStorage.removeImage(identifier)
			trace("image file deleted:\(imageStorage.createFileURL(identifier))")
		}
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
	
	static func checkAllPhotoDownloaded(photos: [Photo]?) -> Bool {
		if let _ = photos {
			var isDownloaded = true
			for photo in photos! {
				isDownloaded = isDownloaded && (photo.downloaded == Status.Downloaded.rawValue)
			}
			return isDownloaded
		}
		return false
	}
	
	static func toPhotoArray(photoSet: NSMutableOrderedSet) -> [Photo] {
		var photoArray: [Photo] = []
		for elem in photoSet {
			let photo = elem as! Photo
			photoArray.append(photo)
		}
		return photoArray
	}
	
	func checkCoredata() {
		print("id:\(identifier), dl:\(downloaded), url:\(url)")
	}
}