//
//  ViewController.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/24.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit
import MapKit

final class Pin: NSObject, MKAnnotation {
	var coordinate: CLLocationCoordinate2D
	
	init(coordinates: CLLocationCoordinate2D) {
		self.coordinate = coordinates
		super.init()
	}
	
	func show(mapView: MKMapView) {
		mapView.removeAnnotation(self)
		mapView.addAnnotation(self)
	}
	
	func hide(mapView: MKMapView) {
		mapView.removeAnnotation(self)
	}
}

class TravelLocationsMapViewController: UIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate {
	
	let DefaultLocation = CLLocationCoordinate2DMake(35.6897,139.6922)
	
	var pin :Pin?
	
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
			photoAlbumViewController?.location = selectedPin.coordinate
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
			pin = Pin(coordinates: coordinates)
			pin?.coordinate = coordinates
		}
		else if gestureRecognizer.state == UIGestureRecognizerState.Changed {
			pin?.coordinate = coordinates
		}
		
		pin?.show(mapView)
	}
	
	// on the pin selected
	func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
		let selectedPin = view.annotation as! Pin
		self.performSegueWithIdentifier("showPhotoAlbum", sender: selectedPin)
	}
	
}

