//
//  ImageCache.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/30.
//  Copyright © 2015 Udacity. All rights reserved.
//
import UIKit

/**
Image storage class offers memory caching and file storing methods for image data with specified identifier.
*/
class ImageStorage {
	
	/// memory cache object
	private var cache = NSCache()
	
	/// Get image data
	///
	/// - returns: image data (UIImage)
	/// - parameter identifier: a photo identifier string (part of the file path)
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
	
	/// Store image data to memory cache and file system
	///
	/// - returns: None
	/// - parameter image: a image data to be stored
	/// - parameter identifier: a photo identifier string (part of the file path)
	func storeImage(image: UIImage?, identifier: String) {
		// store data to memory
		let cacheUrl = createCacheURL(identifier)
		storeImageToMemory(image, path: cacheUrl)

		// store data to file system
		let fileUrl = createFileURL(identifier)
		storeImageToFileSystem(image, path: fileUrl)
	}
	
	/// Delete image data from memory cache and file system
	///
	/// - returns: None
	/// - parameter identifier: a photo identifier string (part of the file path)
	func removeImage(identifier: String) {
		storeImage(nil, identifier: identifier)
	}
	
	/// Check an image file exits with specified identifier
	///
	/// - returns: Whether specified file exists or not
	/// - parameter identifier: a photo identifier string (part of the file path)
	func imageFileExists(identifier: String) -> Bool {
		let filePath = createFileURL(identifier)
		return NSFileManager.defaultManager().fileExistsAtPath(filePath)
	}
	
	/// Create an image file path from a specified identifier
	///
	/// - returns: an image file path
	/// - parameter identifier: a photo identifier string
	func createFileURL(identifier: String) -> String {
		let documentsDirectoryURL: NSURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
		let fullURL = documentsDirectoryURL.URLByAppendingPathComponent(identifier)
		return fullURL.path!
	}
	
	/// Create an image cache url string from a specified identifier (TODO: cache URL can be differed from the file URL)
	///
	/// - returns: an image cache url
	/// - parameter identifier: a photo identifier string
	func createCacheURL(identifier: String) -> String {
		return createFileURL(identifier)
	}
	
	//MARK: private functions
	
	/// get image data from memory cache
	private func getImageFromMemory(path: String) -> UIImage? {
		if let image = cache.objectForKey(path) as? UIImage {
			return image
		}
		return nil
	}

	/// store image data to memory cache
	private func storeImageToMemory(image: UIImage?, path: String) {
		if image == nil {
			removeImageFromMemory(path)
			return
		}
		cache.setObject(image!, forKey: path)
	}

	/// get image data from file system
	private func getImageFromFileSystem(path: String) -> UIImage? {
		if let data = NSData(contentsOfFile: path) {
			return UIImage(data: data)
		}
		return nil
	}
	
	/// store image data to the file system
	private func storeImageToFileSystem(image: UIImage?, path: String) {
		if image == nil {
			removeImageFromFileSystem(path)
			return
		}
		let data = UIImagePNGRepresentation(image!)!
		data.writeToFile(path, atomically: true)
	}
	
	/// remove image data from memory cache
	private func removeImageFromMemory(path: String) {
		cache.removeObjectForKey(path)
	}
	
	/// remove image data from file system
	private func removeImageFromFileSystem(path: String) {
		do {
			try NSFileManager.defaultManager().removeItemAtPath(path)
		} catch _ {}
	}
}

