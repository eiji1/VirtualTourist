//
//  ViewController.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/24.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class TravelLocationsMapViewController: UIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate {
	let sharedApp = (UIApplication.sharedApplication().delegate as! AppDelegate)
	
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
		
		fetchPinObjects()
		
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
	}
	
	override func viewDidAppear(animated: Bool) {
		super.viewWillAppear(animated)
		moveToALocation(DefaultLocation)
		pinArray.forEach { (pin) -> () in
			pin.show(mapView)
		}
	}
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if segue.identifier == "showPhotoAlbum" {
			let photoAlbumViewController = segue.destinationViewController as? PhotoAlbumViewController
			let selectedPin = sender as! Pin
			photoAlbumViewController?.pin = selectedPin
		}
	}
	
	// fetch Pin objects
	private func fetchPinObjects() {
		let coreData = sharedApp.coreDataStackManager
		
		let fetchRequest = NSFetchRequest(entityName: "Pin")
		do {
		let results = try coreData.managedObjectContext.executeFetchRequest(fetchRequest)
			pinArray = results as! [Pin]
			print(pinArray)
		} catch let error as NSError {
			print("Could not fetch \(error), \(error.userInfo)")
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
		let coordinate = mapView.convertPoint(tapPoint, toCoordinateFromView: mapView)
		
		if gestureRecognizer.state == UIGestureRecognizerState.Began {
			// create a new pin
			let coreData = sharedApp.coreDataStackManager
			
			let pin = Pin(coordinate: coordinate, context: coreData.managedObjectContext)
			pinArray.append(pin)
		}
		else if gestureRecognizer.state == UIGestureRecognizerState.Changed {
			let pin = pinArray.last
			pin?.coordinate = coordinate
		}
		else if gestureRecognizer.state == UIGestureRecognizerState.Ended {
			// save the new pin
			let coreData = sharedApp.coreDataStackManager
			coreData.saveContext()
			
			//prefetchImageFromFlickr(pinArray.last!)
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
	
	
	func prefetchImageFromFlickr(pin: Pin) {
		let photoAlbumViewController = self.storyboard!.instantiateViewControllerWithIdentifier("PhotoAlbumViewController") as! PhotoAlbumViewController
		
		photoAlbumViewController.getImagesFromFlickr(pin)
	}
}
