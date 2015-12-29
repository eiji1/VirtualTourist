//
//  ImageDownloader.swift
//  VirtualTourist
//
//  Created by eiji on 2015/12/01.
//  Copyright © 2015 eiji & Udacity. All rights reserved.
//

import UIKit

/**
Image downloader class offering synchronous and asynchronous image download APIs
*/
class ImageDownloader {
	
	/// Download image data from specified URL (synchronously)
	///
	/// - returns: None
	/// - parameter urlString: image data location
	/// - parameter handler: a completion handler called on image downloading finished
	func downloadImage(urlString: String, handler:(image: UIImage?, success: Bool)->()) {
		let imageUrl = NSURL(string: urlString)
		// retrieving a blob
		if let imageData = NSData(contentsOfURL: imageUrl!) {
			let image = UIImage(data: imageData)
			handler(image: image, success: true)
		} else {
			print("Image does not exist at \(imageUrl)")
			handler(image: nil, success: false)
		}
	}
	
	/// Asynchronously download image data from specified URL
	///
	/// - returns: None
	/// - parameter urlString: image data location
	/// - parameter handler: a completion handler called on image downloading finished
	func downloadImageAsync(urlString: String, handler:(image: UIImage?, success: Bool)->()) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), {
			self.downloadImage(urlString, handler: handler)
		})
	}
	
}
