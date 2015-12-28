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
	
	// private ctor. (make this instance as singleton)
	private init(){}
	
	/// singleton
	class func sharedInstance() -> FlickrClient {
		struct Singleton {
			static let instance = FlickrClient()
		}
		return Singleton.instance
	}

	/// web client instance
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
	static let PhotoNumPerPage = 15
	
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
	
	/// Retrieve images from Flickr photo search API
	/// - returns: None (using completion handler)
	/// - parameter coordinates: a place where photos are taken
	/// - parameter page: a number identifying the set of photo groups
	/// - parameter handler: completion handler
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
				errorLog("Sending Http request has failed")
				handler(photos: [Photo](), total: 0, success: false)
				return
			}
			
			let photos = self.parseResult(result)
			handler(photos: photos, total: 0, success: true)
		}
	}
	
	/// parse JSON object result in the Http response
	private func parseResult(result: AnyObject) -> [Photo] {
		var photos: [Photo] = [Photo]()
		
		if let result = result.valueForKey(JSONResponseKeys.Photos) as? [String:AnyObject] {
			
			var totalPhotos = 0
			if let _total = result[JSONResponseKeys.Total] as? String {
				totalPhotos = (_total as NSString).integerValue
			}
			
			if totalPhotos < 0 {
				errorLog("No photo error")
				return photos
			}
			
			if let _photos = result[JSONResponseKeys.Photo] as? [[String: AnyObject]] {
				photos = Photo.getPhotoFromResults(_photos)
			}
		}
		errorLog("JSON parse error")
		return photos
	}
}