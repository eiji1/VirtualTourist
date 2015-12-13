//
//  ImageCache.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/30.
//  Copyright © 2015 Udacity. All rights reserved.
//
import UIKit

class ImageStorage {
	
	private var cache = NSCache()
	
	func getImage(identifier: String?) -> UIImage? {
		
		// checking invalid inputs
		if identifier == nil {
			return nil
		}
		if identifier == "" {
			return nil
		}
		
		// get data from memory
		let cacheUrl = createCacheURL(identifier!)
		if let image = getImageFromMemory(cacheUrl) {
			return image
		}
		
		// get data from file system
		let fileUrl = createFileURL(identifier!)
		if let image = getImageFromFileSystem(fileUrl) {
			return image
		}
		
		return nil
	}
	
	func storeImage(image: UIImage?, identifier: String) {
		// store data to memory
		let cacheUrl = createCacheURL(identifier)
		storeImageToMemory(image, path: cacheUrl)

		// store data to file system
		let fileUrl = createFileURL(identifier)
		storeImageToFileSystem(image, path: fileUrl)
	}
	
	func removeImage(identifier: String) {
		storeImage(nil, identifier: identifier)
	}
	
	func getImageFromMemory(path: String) -> UIImage? {
		if let image = cache.objectForKey(path) as? UIImage {
			return image
		}
		return nil
	}
	
	func storeImageToMemory(image: UIImage?, path: String) {
		if image == nil {
			removeImageFromMemory(path)
			return
		}
		cache.setObject(image!, forKey: path)
	}
	
	func removeImageFromMemory(path: String) {
		cache.removeObjectForKey(path)
	}
	
	func getImageFromFileSystem(path: String) -> UIImage? {
		if let data = NSData(contentsOfFile: path) {
			return UIImage(data: data)
		}
		return nil
	}
	
	func storeImageToFileSystem(image: UIImage?, path: String) {
		if image == nil {
			removeImageFromFileSystem(path)
			return
		}
		let data = UIImagePNGRepresentation(image!)!
		data.writeToFile(path, atomically: true)
	}
	
	func removeImageFromFileSystem(path: String) {
		do {
			try NSFileManager.defaultManager().removeItemAtPath(path)
		} catch _ {}
	}
	
	func createFileURL(identifier: String) -> String {
		let documentsDirectoryURL: NSURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
		let fullURL = documentsDirectoryURL.URLByAppendingPathComponent(identifier)
		return fullURL.path!
	}
	
	// enabling cache URL differed from the file URL
	func createCacheURL(identifier: String) -> String {
		return createFileURL(identifier)
	}
}

