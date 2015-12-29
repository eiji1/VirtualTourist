//
//  Photo.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/30.
//  Copyright © 2015 eiji & Udacity. All rights reserved.
//

import CoreData
import UIKit // shared app

/**
Photo class represents pictures in a photo album associated with a specified location. Photo objects should be persistent.
*/
public class Photo : NSManagedObject {
	
	/// Downloading status definitions
	enum Status : Int16 {
		case NotRetrieved = 0
		case Downloading = 1
		case Downloaded = 2
		case DownladFailed = 3
	}
	
	/// A url where image data is stored
	@NSManaged var url: String
	/// An identifier string for photo objects
	@NSManaged var identifier: String
	/// A file path where image data is stored offline
	@NSManaged var path: String
	/// Downloading status
	@NSManaged var downloaded: Int16
	/// A pin object which this photo is associated with
	@NSManaged var pin: Pin?
	
	/// ctor.
	override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
		super.init(entity: entity, insertIntoManagedObjectContext: context)
	}
	
	/// ctor.
	init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
		let entity =  NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
		super.init(entity: entity, insertIntoManagedObjectContext: context)
		url = dictionary[FlickrClient.JSONResponseKeys.Url] as! String
		downloaded = Status.NotRetrieved.rawValue
		identifier = ""
		path = ""
	}

	/// Remove photo object persistently
	func remove(coreDataStack: CoreDataStackManager) {
		trace("photo managed object removed:\(ImageStorage().createFileURL(identifier))")
		// remove photo managed object from core data stack
		coreDataStack.managedObjectContext.deleteObject(self)
		coreDataStack.saveContext()
	}
	
	/// Remove image files from the local storage
	func removeImageFiles() {
		let imageStorage = ImageStorage()
		if imageStorage.imageFileExists(identifier) {
			// delete an image from cache and an underlying file from the Documents directory
			imageStorage.removeImage(identifier)
			trace("image file deleted:\(imageStorage.createFileURL(identifier))")
		}
		else {
			trace("image file has been already deleted:\(imageStorage.createFileURL(identifier))")
		}
	}
	
	override public func prepareForDeletion() {
		removeImageFiles() // automatically delete underlying files (solution 1)
	}
	
	/// Convert Json result to Photo object array
	static func getPhotoFromResults(results: [[String : AnyObject]]) -> [Photo] {
		trace("check current thread at getPhotoFromResults", detail: true) // global gueue
		
		let sharedApp = (UIApplication.sharedApplication().delegate as! AppDelegate)
		let managedObjectContext = sharedApp.coreDataStackManager.managedObjectContext
		
		var photos = [Photo]()
		
		// [core data concurrency] create new managed objects on the main queue
		sharedApp.dispatch_sync_main {
			for result in results {
				photos.append(Photo(dictionary: result, context:managedObjectContext))
			}
		}
		return photos
	}
	
	/// Check all the specified photos are finished downloading.
	///
	/// - returns: result, this function returns true if the input array size is zero.
	/// - parameter photos: An array of photo object
	/// - parameter isIncludeFailures: to accept failure cases or not
	static func checkAllPhotoDownloaded(photos: [Photo]?, isIncludeFailures: Bool = false) -> Bool {
		if let _ = photos {
			var isDownloaded = true
			for photo in photos! {
				isDownloaded = isDownloaded && (photo.downloaded == Status.Downloaded.rawValue || (isIncludeFailures && photo.downloaded == Status.DownladFailed.rawValue) )
			}
			return isDownloaded
		}
		return false
	}
	
	// for debugging
	func checkCoredata() {
		print("id:\(identifier), dl:\(downloaded), url:\(url)")
	}
}