//
//  Const.swift
//  VirtualTourist
//
//  Created by eiji on 2015/12/30.
//  Copyright © 2015 eiji & Udacity. All rights reserved.
//

import Foundation
import CoreLocation

/**
Cosntant values for application settings
*/
struct Const {
	
	struct HttpRequest {
		static let TimeoutIntervalInSec = 5.0
	}
	
	struct Flickr {
		static let BaseSecuredUrl = "https://api.flickr.com/"
		static let BaseMethod = "services/rest/"
		static let Method = "flickr.photos.search"
		static let ApiKey = "2d1989834346d011702cd3994d731ef3"
		static let Extras = "url_m"
		static let SafeSearch = 1
		static let DataFormat = "json"
		static let NoJsonCallback = 1
		static let PhotoNumPerPage = 25
		
		static let DefaultPage = 1
		
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
		
		struct ResponseKeys {
			static let Photos = "photos"
			static let Total = "total"
			static let Photo = "photo"
			static let Url = "url_m"
		}
	}
	
	struct Map {
		static let DefaultLocation = CLLocationCoordinate2DMake(35.6897,139.6922)
		static let DefaultRegionSize = 0.3
	}
}

