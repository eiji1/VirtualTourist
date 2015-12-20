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

/**
TravelLocationsMapViewController controls displaying and operating a map and dropping new pins on the favorite location. This class should manage their instances persistently using Coredata framework.
*/
class TravelLocationsMapViewController: UIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate {
	
	// consts.
	let DefaultLocation = CLLocationCoordinate2DMake(35.6897,139.6922)
	let DefaultRegionSize = 5.0
	
	// UI
	@IBOutlet weak var mapView: MKMapView!
	var justLongPressStarted: Bool = false  // to enable the drop animation
	var justUserChangedMap: Bool = false    // to store the map region

	// managed objects
	var map: Map!
	
	var pins: NSMutableOrderedSet {
		get{ return map?.valueForKeyPath("pins") as! NSMutableOrderedSet }
	}
	
	// core data
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
		fetchMapObject()
		fetchPinObjects()
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
	}
	
	override func viewDidAppear(animated: Bool) {
		super.viewWillAppear(animated)
		// go to the previous location
		moveTo(map.center, regionSize: map.regionSize)

		// render pins
		for obj in pins {
			if let pin = obj as? Pin {
				pin.show(mapView)
			}
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
		// get the coordinates where was tapped
		let tapPoint: CGPoint = gestureRecognizer.locationInView(mapView)
		let coordinate = mapView.convertPoint(tapPoint, toCoordinateFromView: mapView)
		
		justLongPressStarted = false

		// event handling
		if gestureRecognizer.state == UIGestureRecognizerState.Began {
			onLongPressStarted(coordinate)
		}
		else if gestureRecognizer.state == UIGestureRecognizerState.Changed {
			onLongPressedAndDragging(coordinate)
		}
		else if gestureRecognizer.state == UIGestureRecognizerState.Ended {
			onLongPressFinished(coordinate)
		}
	}
	
	func onLongPressStarted(coordinate: CLLocationCoordinate2D) {
		// disable the map scroll
		mapView.scrollEnabled = false
		justLongPressStarted = true // enables drop animation
		
		// create a new pin
		let newPin = Pin(coordinate: coordinate, context: managedObjectContext)
		newPin.map = map // set relationship
		pins.addObject(newPin)
		
		newPin.show(mapView)
	}
	
	func onLongPressedAndDragging(coordinate: CLLocationCoordinate2D) {
		// update the location of the last created pin
		let pin = pins.lastObject as? Pin
		pin?.coordinate = coordinate
		// and show it on the map
		pin?.show(mapView)
	}
	
	func onLongPressFinished(coordinate: CLLocationCoordinate2D) {
		// update the location of the pin
		let pin = pins.lastObject as? Pin
		pin?.coordinate = coordinate
		
		storeMapObjects() // new pin will be stored on user's finger released
		
		// show it on the map
		pin?.show(mapView)
		
		// allow map scroll again
		mapView.scrollEnabled = true
		
		prefetchImageFromFlickr(pin!)
	}
	
	// on the map tapped
	func onTapGesture(gestureRecognizer: UIGestureRecognizer) {
		if gestureRecognizer.state == UIGestureRecognizerState.Ended {
			justUserChangedMap = true
		}
	}

	// on the map dragging
	func onDragGesture(gestureRecognizer: UIGestureRecognizer) {
		if gestureRecognizer.state == UIGestureRecognizerState.Ended {
			//storeMapObject()
			justUserChangedMap = true
		}
	}
	
	// use gesture recongnizers simultaneously
	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return true // for long press, tap, and pan gestures
	}

	//------------------------------------------------------------------------//
	// MapViewDelegate related methods
	
	// when a pin was selected
	func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
		let selectedPin = view.annotation as! Pin
		self.performSegueWithIdentifier("showPhotoAlbum", sender: selectedPin)
	}
	
	// on render a pin
	func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
		// getting a reusable annotation view
		let reuseIdentifier = "pinView"
		var annotationView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseIdentifier) as? MKPinAnnotationView
		if annotationView == nil {
			annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
		}
		else {
			annotationView!.annotation = annotation
		}
		
		// enables drop animation only on long pressing began
		annotationView!.animatesDrop = justLongPressStarted
		return annotationView
	}
	
	// when the region did changed after animating
	func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
		if justUserChangedMap {
			storeMapObjects() // only when user's changed the map
			justUserChangedMap = false
		}
	}
	
	//------------------------------------------------------------------------//
	// keep map and pin objects persistent
	
	// fetch Pin objects
	private func fetchPinObjects() {
		let fetchRequest = NSFetchRequest(entityName: "Pin")
		do {
			let results = try managedObjectContext.executeFetchRequest(fetchRequest)
			
			let filteredPins = (results as! [Pin]).filter({ (pin) -> Bool in
				return pin.map == self.map
			})
			
			filteredPins.forEach({ (pin) -> () in
				pins.addObject(pin)
			})
			
		} catch let error as NSError {
			errorLog("Could not fetch \(error), \(error.userInfo)")
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
			}
			else {
				map = Map(center: DefaultLocation, regionSize: DefaultRegionSize, context: managedObjectContext)
			}
		} catch let error as NSError {
			errorLog("Could not fetch \(error), \(error.userInfo)")
		}
	}
	
	private func storeMapObjects() {
		// updating map location status
		let regionSize = mapView.region.span.longitudeDelta // rather than latitudeDelata
		let center = mapView.region.center
		map.regionSize = regionSize
		map.center = center
		
		coreDataStack.saveContext()
	}
	
	/// move to the specified location on the map
	private func moveTo(center: CLLocationCoordinate2D, regionSize: Double) {
		let span = MKCoordinateSpanMake(regionSize, regionSize)
		let region = MKCoordinateRegionMake(center, span)
		// enables the animation going to the destination
		let animationOptions : UIViewAnimationOptions = [UIViewAnimationOptions.CurveEaseInOut, UIViewAnimationOptions.AllowUserInteraction, UIViewAnimationOptions.OverrideInheritedDuration]
		UIView.animateWithDuration(2.5, delay: 0.0, options: animationOptions,
			animations: {
				self.mapView.setCenterCoordinate(center, animated: true)
				self.mapView.setRegion(region, animated: true);
			}, completion: nil)
	}
	
	func prefetchImageFromFlickr(pin: Pin) {
		// reusing PhotoAlbumViewController method but do nothing for any view objects
		let photoAlbumViewController = self.storyboard!.instantiateViewControllerWithIdentifier("PhotoAlbumViewController") as! PhotoAlbumViewController
		photoAlbumViewController.getImagesFromFlickr(pin, imageDownloadHandler: onImageDownloaded, searchFinishedHandler: {})
	}
	
	
	func onImageDownloaded(photo:Photo, index: Int, allPhotosDownloaded: Bool) {
		// send notification to the photo album view controller
		let notification : NSNotification = NSNotification(name: "imageDownloadNotification", object: self, userInfo: ["value": index, "downloaded": allPhotosDownloaded])
		NSNotificationCenter.defaultCenter().postNotification(notification)
	}
	
}
