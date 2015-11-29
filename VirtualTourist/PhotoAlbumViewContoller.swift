//
//  PhotoAlbumViewContoller.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/24.
//  Copyright © 2015 Udacity. All rights reserved.
//

import Foundation
import MapKit

class PhotoAlbumViewController: UIViewController {
	
	var location :CLLocationCoordinate2D!
	@IBOutlet weak var mapView: MKMapView!
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	override func viewDidAppear(animated: Bool) {
		super.viewWillAppear(animated)
		let newPin = Pin(coordinates: location)
		newPin.show(mapView)
	}
}


