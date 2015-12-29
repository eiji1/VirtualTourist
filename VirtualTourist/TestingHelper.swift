//
//  TestingHelper.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/29.
//  Copyright © 2015 eiji. All rights reserved.
//

import Foundation
import CoreLocation

public class TestingHelper {

	public class func getImages(coordinate: CLLocationCoordinate2D, handler: (photos: [Photo], total: Int, success: Bool) -> ()) {
		FlickrClient.sharedInstance().getImagesBySearch(coordinate, page:1, handler: handler)
	}
	
}