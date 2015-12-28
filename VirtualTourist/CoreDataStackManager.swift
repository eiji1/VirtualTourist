//
//  CoreDataStackManager.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/30.
//  Copyright © 2015 Udacity. All rights reserved.
//

import Foundation
import CoreData

/**
CoreDataStackManager class has a managed object model and controls managed object context using SQLite data storing system.
*/
class CoreDataStackManager {
	
	lazy var applicationDocumentsDirectory: NSURL = {
		let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
		return urls[urls.count-1]
	}()
	
	lazy var managedObjectModel: NSManagedObjectModel = {
		let modelUrl = NSBundle.mainBundle().URLForResource("VirtualTourist", withExtension: "momd")!
		return NSManagedObjectModel(contentsOfURL: modelUrl)!
	}()
	
	lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
		let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
		let sqliteUrl = self.applicationDocumentsDirectory.URLByAppendingPathComponent("VirtualTouristCoreData.sqlite")
		var failureReason = "There was an error creating or loading the application's saved data."
		do {
			try persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: sqliteUrl, options: nil)
		} catch {
			var dict = [String: AnyObject]()
			dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
			dict[NSLocalizedFailureReasonErrorKey] = failureReason
			
			dict[NSUnderlyingErrorKey] = error as NSError
			let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
			NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
#if DEBUG
			abort() // for debugging
#endif
		}
		
		return persistentStoreCoordinator
	}()
	
	lazy var managedObjectContext: NSManagedObjectContext = {
		var managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
		managedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator
		return managedObjectContext
	}()
	
	func saveContext () {
		if managedObjectContext.hasChanges {
			managedObjectContext.performBlockAndWait({
			do {
				try self.managedObjectContext.save()
			} catch {
				let nserror = error as NSError
				NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
#if DEBUG
				abort() // for debugging
#endif
			}
			})
		}
	}

}