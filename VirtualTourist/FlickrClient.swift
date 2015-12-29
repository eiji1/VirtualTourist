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
	
	static let BaseSecuredUrl = Const.Flickr.BaseSecuredUrl
	static let BaseMethod = Const.Flickr.BaseMethod
	static let Method = Const.Flickr.Method
	static let ApiKey = Const.Flickr.ApiKey
	static let Extras = Const.Flickr.Extras
	static let SafeSearch = Const.Flickr.SafeSearch
	static let DataFormat = Const.Flickr.DataFormat
	static let NoJsonCallback = Const.Flickr.NoJsonCallback
	static let PhotoNumPerPage = Const.Flickr.PhotoNumPerPage
	
	struct ParameterKeys {
		static let Method = Const.Flickr.ParameterKeys.Method
		static let ApiKey = Const.Flickr.ParameterKeys.ApiKey
		static let Lon = Const.Flickr.ParameterKeys.Lon
		static let Lat = Const.Flickr.ParameterKeys.Lat
		static let SafeSearch = Const.Flickr.ParameterKeys.SafeSearch
		static let Extras = Const.Flickr.ParameterKeys.Extras
		static let Format = Const.Flickr.ParameterKeys.Format
		static let NoJsonCallback = Const.Flickr.ParameterKeys.NoJsonCallback
		static let PerPage = Const.Flickr.ParameterKeys.PerPage
		static let Page = Const.Flickr.ParameterKeys.Page
	}
	
	// not used
	//struct JSONBodyKeys {
	//}
	
	struct JSONResponseKeys {
		static let Photos = Const.Flickr.ResponseKeys.Photos
		static let Total = Const.Flickr.ResponseKeys.Total
		static let Photo = Const.Flickr.ResponseKeys.Photo
		static let Url = Const.Flickr.ResponseKeys.Url
	}
	
	/// Retrieve images from Flickr photo search API (simply returns an array of Photo objects)
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

import UIKit // UIApplication.sharedApplication

/**
This extension offers more applicable methods using photo and pin objects.
*/
extension FlickrClient {

	/// Download pictures using Flickr photos search API. This method runs following processes.
	/// 1. Search photos using Flickr API specified with location and get their images' URL strings
	///
	///    Call searchFinishedHandler when photo search is completed.
	/// 2. Download their image data from the URLs
	///
	///    Call imageDownloadHandler when each image download is completed.
	///
	///   (note) Actual implementation downloading photos are offerred by ImageDownloader and FlickrClient base class
	///
	/// - returns: None
	/// - parameter pin: a pin object which has a location where photos should be searched
	/// - parameter imageDownloadedHandler: a completion handler called on image downloading finished
	/// - parameter searchFinishedHandler: a completion handler called on the photo search finished
	func downloadPicturesByFlickrPhotosSearch(pin: Pin, page: Int, imageDownloadHandler: (photoIndex: Int)->(),
		searchFinishedHandler: (success: Bool)->()) {
			trace("chech thread at getImagesFromFlickr", detail: true) // main queue
			
			// search image urls from Flickr
			FlickrClient.sharedInstance().getImagesBySearch(pin.coordinate, page: page) { _photos, total , success in
				trace("chech thread after getImagesBySearch", detail: true) // global queue
				
				if success {
					trace("got images from Flikcr!", detail: true)
					
					// no image is retrieved
					if _photos.count == 0 {
						imageDownloadHandler(photoIndex: -1) // with invalid index
					}
					else {
						for (index, photo) in _photos.enumerate() {
							
							// [core data concurrency] update managed objects on main queue
							let sharedApp = (UIApplication.sharedApplication().delegate as! AppDelegate)
							sharedApp.dispatch_sync_main {
								photo.pin = pin // set an inverse relationship
								photo.identifier = "\(pin.identifier)_\(index)" // creating an identifier by index
							}
							
							trace("start downloading an image \(index)", detail: true)
							self.downloadImageFromServer(photo) { image in
								imageDownloadHandler(photoIndex: index)
							}
						}
					}
				}
				searchFinishedHandler(success: success)
			}
	}
	
	/// Download image data from specified Url
	///
	/// - returns: None
	/// - parameter photo: a photo object to be downloaded
	/// - parameter completionHandler: a completion handler called on the download finished
	private func downloadImageFromServer(photo: Photo, completionHandler: (image: UIImage?) -> ()) {
		trace("check thread at downloadImageFromServer", detail: true) // global queue
		let sharedApp = (UIApplication.sharedApplication().delegate as! AppDelegate)
		
		// [core data concurrency] access managed objects on main queue
		var url = ""
		sharedApp.dispatch_sync_main {
			photo.downloaded = Photo.Status.Downloading.rawValue
			url = photo.url
		}
		
		ImageDownloader().downloadImageAsync(url) { (image, success) -> () in
			trace("check thread after downloadImageAsync", detail: true) // global queue
			
			// [core data concurrency] update managed objects on main queue
			
			sharedApp.dispatch_sync_main {
				
				if success {
					if let _ = image {
						trace("finished downloading the image: photo id:\(photo.identifier)", detail: true)
						// save the downloaded data to the image storage
						ImageStorage().storeImage(image, identifier: photo.identifier)
						photo.path = ImageStorage().createFileURL(photo.identifier)
						photo.downloaded = Photo.Status.Downloaded.rawValue
					}
					else {
						photo.downloaded = Photo.Status.DownladFailed.rawValue
					}
				}
				else {
					photo.downloaded = Photo.Status.DownladFailed.rawValue
				}
				
				sharedApp.coreDataStackManager.saveContext()
				
			} // dispatch
			
			
			completionHandler(image: image)
		}
	}
}



