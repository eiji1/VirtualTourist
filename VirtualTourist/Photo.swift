//
//  Photo.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/30.
//  Copyright © 2015年 Udacity. All rights reserved.
//

import Foundation

public class Photo : NSObject {
	var url: String = ""
	var downloaded = false
	
	public init(dictionary: [String : AnyObject]) {
		url = dictionary[FlickrClient.JSONResponseKeys.Url] as! String
		
		super.init()
	}
	
	static func getPhotoFromResults(results: [[String : AnyObject]]) -> [Photo] {
		var photos = [Photo]()
		for result in results {
			photos.append(Photo(dictionary: result))
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