//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/29.
//  Copyright © 2015 Udacity. All rights reserved.
//

import Foundation
import CoreLocation

/**
 An encapsulated class downloading images from Flickr
*/
class FlickrClient{
	
	private let httpClient = WebClient()
	
	// constants
	static let BaseSecuredUrl = "https://api.flickr.com/"
	static let BaseMethod = "services/rest/"
	static let Method = "flickr.photos.search"
	static let ApiKey = "2d1989834346d011702cd3994d731ef3"
	static let Extras = "url_m"
	static let SafeSearch = 1
	static let DataFormat = "json"
	static let NoJsonCallback = 1
	static let PhotoNumPerPage = 20
	
	struct ParameterKeys {
		static let Method = "method"
		static let ApiKey = "api_key"
		static let Lon = "lon"
		static let Lat = "lat"
		static let SafeSearch = "safe_search"
		static let Extras = "extras"
		static let Format = "format"
		static let NoJsonCallback = "nojsoncallback"
		static let PerPage = "per_page"
		static let Page = "page"
	}
	
	// not used
	//struct JSONBodyKeys {
	//}
	
	struct JSONResponseKeys {
		static let Photos = "photos"
		static let Total = "total"
		static let Photo = "photo"
		static let Url = "url_m"
	}
	
	func getImagesBySearch(coordinates: CLLocationCoordinate2D, page: Int, handler: (photos: [Photo], total: Int, success: Bool) -> ()) {
		
		let arguments : WebClient.JSONBody = [
			ParameterKeys.Method: FlickrClient.Method,
			ParameterKeys.ApiKey: FlickrClient.ApiKey,
			ParameterKeys.Lon: coordinates.longitude,
			ParameterKeys.Lat: coordinates.latitude,
			ParameterKeys.SafeSearch: "\(FlickrClient.SafeSearch)",
			ParameterKeys.Extras: FlickrClient.Extras,
			ParameterKeys.Format: FlickrClient.DataFormat,
			ParameterKeys.NoJsonCallback: "\(FlickrClient.NoJsonCallback)",
			ParameterKeys.PerPage: "\(FlickrClient.PhotoNumPerPage)",
			ParameterKeys.Page: "\(page)",
		]
		
		let url = httpClient.createURL(FlickrClient.BaseSecuredUrl, method: FlickrClient.BaseMethod, parameters: arguments)
		let request = httpClient.createRequest(url, method: WebClient.Method.GET)
		
		httpClient.sendRequest(request, jsonBody: nil) { (result, success, downloadError) -> Void in
			if !success {
				// error
				handler(photos: [Photo](), total: 0, success: false)
				return
			}
			
			let photos = self.parseResult(result)
			handler(photos: photos, total: 0, success: true)
		}
	}
	
	private func parseResult(result: AnyObject) -> [Photo] {
		var photos: [Photo] = [Photo]()
		
		if let result = result.valueForKey(JSONResponseKeys.Photos) as? [String:AnyObject] {
			
			var totalPhotos = 0
			if let _total = result[JSONResponseKeys.Total] as? String {
				totalPhotos = (_total as NSString).integerValue
			}
			
			if totalPhotos < 0 {
				return photos
			}
			
			if let _photos = result[JSONResponseKeys.Photo] as? [[String: AnyObject]] {
				photos = Photo.getPhotoFromResults(_photos)
			}
		}
		return photos
	}
	
	
	func downloadPhotoImage(photo: Photo, handler:(imageData: NSData?, success: Bool)->()) {
		let imageURL = NSURL(string: photo.url)
		if let imageData = NSData(contentsOfURL: imageURL!) {
			handler(imageData: imageData, success: true)
		} else {
			print("Image does not exist at \(imageURL)")
			handler(imageData: nil, success: false)
		}
	}
	
	func downloadPhotoImageAsync(photo: Photo, handler:(imageData: NSData?, success: Bool)->()) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), {
			self.downloadPhotoImage(photo, handler: handler)
		})
	}
	
}