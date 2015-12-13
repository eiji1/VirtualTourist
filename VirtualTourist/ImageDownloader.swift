//
//  ImageDownloader.swift
//  VirtualTourist
//
//  Created by eiji on 2015/12/01.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit

class ImageDownloader {
	
	func downloadImage(urlString: String, handler:(image: UIImage?, success: Bool)->()) {
		let imageUrl = NSURL(string: urlString)
		// retrieving a blob object
		if let imageData = NSData(contentsOfURL: imageUrl!) {
			let image = UIImage(data: imageData)
			handler(image: image, success: true)
		} else {
			print("Image does not exist at \(imageUrl)")
			handler(image: nil, success: false)
		}
	}
	
	func downloadImageAsync(urlString: String, handler:(image: UIImage?, success: Bool)->()) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), {
			self.downloadImage(urlString, handler: handler)
		})
	}
}
