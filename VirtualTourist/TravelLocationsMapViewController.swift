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
	let DefaultRegionSize = 5.0
	
	var map: Map!
	var pinArray :[Pin] = [Pin]()
	
	@IBOutlet weak var mapView: MKMapView!
	
	var coreDataStack: CoreDataStackManager {
		get { return (UIApplication.sharedApplication().delegate as! AppDelegate).coreDataStackManager }
	}
	
	var managedObjectContext: NSManagedObjectContext {
		get { return coreDataStack.managedObjectContext }
	}

	//------------------------------------------------------------------------//
	// UIViewController related methods
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.mapView.delegate = self

		// register gesture recognizers
		let longTap: UILongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: "onLongPressedGesture:")
		longTap.delegate = self
		longTap.numberOfTapsRequired = 0
		longTap.minimumPressDuration = 1.0
		mapView.addGestureRecognizer(longTap)
		
		let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: "onTapGesture:")
		tap.delegate = self
		tap.numberOfTapsRequired = 1
		tap.numberOfTouchesRequired = 1
		mapView.addGestureRecognizer(tap)
		
		let pan: UIPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: "onDragGesture:")
		pan.delegate = self
		mapView.addGestureRecognizer(pan)
		
		// fetch managed objects from the core data DB
		fetchPinObjects()
		fetchMapObject()
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
	}
	
	override func viewDidAppear(animated: Bool) {
		super.viewWillAppear(animated)
		// go to the previous location
		moveTo(map.center, regionSize: map.regionSize)
		// render pins
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

	//------------------------------------------------------------------------//
	// GestureRecognizer related methods
	
	// long Pressed gesture
	func onLongPressedGesture(gestureRecognizer: UIGestureRecognizer) {
		// get the coordinates that was tapped
		let tapPoint: CGPoint = gestureRecognizer.locationInView(mapView)
		let coordinate = mapView.convertPoint(tapPoint, toCoordinateFromView: mapView)
		
		if gestureRecognizer.state == UIGestureRecognizerState.Began {
			// create a new pin
			let pin = Pin(coordinate: coordinate, context: managedObjectContext)
			pinArray.append(pin)
		}
		else if gestureRecognizer.state == UIGestureRecognizerState.Changed {
			let pin = pinArray.last
			pin?.coordinate = coordinate
		}
		else if gestureRecognizer.state == UIGestureRecognizerState.Ended {
			storeMapObject() // and new Pin will be stored here
			
			//prefetchImageFromFlickr(pinArray.last!)
		}
		
		pinArray.forEach { (pin) -> () in
			pin.show(mapView)
		}
	}
	
	// on the map tapped
	func onTapGesture(gestureRecognizer: UIGestureRecognizer) {
		if gestureRecognizer.state == UIGestureRecognizerState.Ended {
			storeMapObject()
		}
	}

	// on the map dragging
	func onDragGesture(gestureRecognizer: UIGestureRecognizer) {
		if gestureRecognizer.state == UIGestureRecognizerState.Ended {
			storeMapObject()
		}
	}
	
	// use gesture recongnizers simultaneously
	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return true
	}
	
	//------------------------------------------------------------------------//
	// MapViewDelegate related methods
	
	// on the pin selected
	func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
		let selectedPin = view.annotation as! Pin
		self.performSegueWithIdentifier("showPhotoAlbum", sender: selectedPin)
	}
	
	//------------------------------------------------------------------------//
	// keep objects persistent
	
	// fetch Pin objects
	private func fetchPinObjects() {
		let fetchRequest = NSFetchRequest(entityName: "Pin")
		do {
			let results = try managedObjectContext.executeFetchRequest(fetchRequest)
			pinArray = results as! [Pin]
		} catch let error as NSError {
			print("Could not fetch \(error), \(error.userInfo)")
		}
		
	}
	
	// fetch map object
	private func fetchMapObject() {
		let fetchRequest = NSFetchRequest(entityName: "Map")
		do {
			let results = try managedObjectContext.executeFetchRequest(fetchRequest)
			let maps = results as! [Map]
			if maps.count > 0 {
				map = maps[0]
				return
			}
		} catch let error as NSError {
			print("Could not fetch \(error), \(error.userInfo)")
		}
		map = Map(center: DefaultLocation, regionSize: DefaultRegionSize, context: managedObjectContext)
	}
	
	private func storeMapObject() {
		let regionSize = mapView.region.span.latitudeDelta // same as longitudeDelata
		let center = mapView.region.center
		map.regionSize = regionSize
		map.centerLat = center.latitude
		map.centerLon = center.longitude
		
		coreDataStack.saveContext()
	}
	
	// go to the specified location
	private func moveTo(center: CLLocationCoordinate2D, regionSize: Double) {
		let span = MKCoordinateSpanMake(regionSize, regionSize)
		let region = MKCoordinateRegionMake(center, span)
		let animationOptions : UIViewAnimationOptions = [UIViewAnimationOptions.CurveEaseInOut, UIViewAnimationOptions.AllowUserInteraction, UIViewAnimationOptions.OverrideInheritedDuration]
		UIView.animateWithDuration(2.5, delay: 0.0, options: animationOptions,
			animations: {
				self.mapView.setCenterCoordinate(center, animated: true)
				self.mapView.setRegion(region, animated: true);
			}, completion: nil)
	}
	
	func prefetchImageFromFlickr(pin: Pin) {
		let photoAlbumViewController = self.storyboard!.instantiateViewControllerWithIdentifier("PhotoAlbumViewController") as! PhotoAlbumViewController
		photoAlbumViewController.getImagesFromFlickr(pin)
	}
}
