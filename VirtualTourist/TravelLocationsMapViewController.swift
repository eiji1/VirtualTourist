//
//  ViewController.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/24.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit
import MapKit

class TravelLocationsMapViewController: UIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate {
	
	let DefaultLocation = CLLocationCoordinate2DMake(35.6897,139.6922)
	
	var pinArray :[Pin] = [Pin]()
	
	@IBOutlet weak var mapView: MKMapView!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.mapView.delegate = self

		// register the gesture recognizer
		let longTap: UILongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: "onLongTapping:")
		longTap.delegate = self
		longTap.numberOfTapsRequired = 0
		longTap.minimumPressDuration = 1.0
		mapView.addGestureRecognizer(longTap)
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
	}
	
	override func viewDidAppear(animated: Bool) {
		super.viewWillAppear(animated)
		moveToALocation(DefaultLocation)
	}
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if segue.identifier == "showPhotoAlbum" {
			let photoAlbumViewController = segue.destinationViewController as? PhotoAlbumViewController
			let selectedPin = sender as! Pin
			photoAlbumViewController?.pin = selectedPin
		}
	}
	
	// go to the specified location
	private func moveToALocation(coordinate: CLLocationCoordinate2D) {
		let coordDelta = 5.0
		let span = MKCoordinateSpanMake(coordDelta, coordDelta)
		let region = MKCoordinateRegionMake(coordinate, span)
		let animationOptions : UIViewAnimationOptions = [UIViewAnimationOptions.CurveEaseInOut, UIViewAnimationOptions.AllowUserInteraction, UIViewAnimationOptions.OverrideInheritedDuration]
		UIView.animateWithDuration(2.5, delay: 0.0, options: animationOptions,
			animations: {
				self.mapView.setCenterCoordinate(coordinate, animated: true)
				self.mapView.setRegion(region, animated: true);
			}, completion: nil)
	}
	
	// on the map tapped
	func onLongTapping(gestureRecognizer: UIGestureRecognizer) {
		// get the coordinates that was tapped
		let tapPoint: CGPoint = gestureRecognizer.locationInView(mapView)
		let coordinates = mapView.convertPoint(tapPoint, toCoordinateFromView: mapView)
		
		if gestureRecognizer.state == UIGestureRecognizerState.Began {
			let pin = Pin(coordinates: coordinates)
			pinArray.append(pin)
		}
		else if gestureRecognizer.state == UIGestureRecognizerState.Changed {
			let pin = pinArray.last
			pin!.coordinate = coordinates
		}
		
		pinArray.forEach { (pin) -> () in
			pin.show(mapView)
		}
	}
	
	// on the pin selected
	func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
		let selectedPin = view.annotation as! Pin
		self.performSegueWithIdentifier("showPhotoAlbum", sender: selectedPin)
	}
	
}

