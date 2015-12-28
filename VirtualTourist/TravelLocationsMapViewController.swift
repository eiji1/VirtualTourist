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
LongPressDelegate class defines handlers on starting the long press gesture, on finger dragging and released a finger from the map.
*/
protocol LongPressDelegate {
	func onLongPressStarted(coordinate: CLLocationCoordinate2D)
	func onLongPressedAndDragging(coordinate: CLLocationCoordinate2D)
	func onLongPressFinished(coordinate: CLLocationCoordinate2D)
}

/**
PinCreateDelegate class controls pin creation operations using long press gestures.
*/
class PinCreateDelegate : NSObject,  LongPressDelegate {
	/// Context class
	var ctx: TravelLocationsMapViewController!
	/// Whether logn press gesture is just started or not
	var justStarted :Bool = false
	
	/// ctor.
	init(context: TravelLocationsMapViewController) {
		self.ctx = context
	}
	
	/**
	When long press gesture is started, a new pin should be created and render it on the map.
	*/
	func onLongPressStarted(coordinate: CLLocationCoordinate2D) {
		// disable the map scroll
		ctx.mapView.scrollEnabled = false
		//cxt.justLongPressStarted = true // enables drop animation
		justStarted = true
		
		// create a new pin
		let newPin = Pin(coordinate: coordinate, context: ctx.managedObjectContext)
		newPin.map = ctx.map // set relationship
		ctx.pins.addObject(newPin)
		
		newPin.show(ctx.mapView)
	}
	
	/**
	While user's finger is lifting, the created pin should be moved to the touched point.
	*/
	func onLongPressedAndDragging(coordinate: CLLocationCoordinate2D) {
		justStarted = false
		// update the location of the last created pin
		let pin = ctx.pins.lastObject as? Pin
		pin?.coordinate = coordinate
		// and show it on the map
		pin?.show(ctx.mapView)
	}
	
	/**
	In the end of the long press gesture, the pin's location should be stored and begin prefetching images at the location.
	*/
	func onLongPressFinished(coordinate: CLLocationCoordinate2D) {
		justStarted = false

		// update the location of the pin
		let pin = ctx.pins.lastObject as? Pin
		pin?.coordinate = coordinate
		
		ctx.storeMapObjects() // new pin will be stored on user's finger released
		
		// show it on the map
		pin?.show(ctx.mapView)
		
		// allow map scroll again
		ctx.mapView.scrollEnabled = true
		
		ctx.prefetchImageFromFlickr(pin!)
	}
	
}

/**
PinDeleteDelegate class controls pin deletion operations using long press gestures.
*/
class PinDeleteDelegate : NSObject,  LongPressDelegate {
	/// Context class
	var ctx: TravelLocationsMapViewController!
	/// Long pressed coordinate
	var startPos: CLLocationCoordinate2D!
	/// polygon overlay
	var polygon : MKPolygon?
	var vertices : [CLLocationCoordinate2D] = [CLLocationCoordinate2D]()
	var isPressing :Bool = false
	
	/// ctor.
	init(context: TravelLocationsMapViewController) {
		self.ctx = context
	}
	
	/// Store the start position
	func onLongPressStarted(coordinate: CLLocationCoordinate2D) {
		isPressing = true
		ctx.mapView.scrollEnabled = false
		
		if let _ = polygon {
			ctx.mapView.removeOverlay(polygon!)
		}
		
		startPos = coordinate
		let p0 = startPos!
		vertices = [p0, p0, p0, p0]
		polygon = MKPolygon(coordinates: &vertices, count: vertices.count)
		
		ctx.mapView.addOverlay(polygon!, level: MKOverlayLevel.AboveLabels)
	}
	
	/// Draw an overlay rentangle whose digonal line is from start position to the current position.
	func onLongPressedAndDragging(coordinate: CLLocationCoordinate2D) {
		ctx.mapView.removeOverlay(polygon!)
		
		let p1 = startPos!
		let p3 = coordinate
		let p2 = CLLocationCoordinate2DMake(p3.latitude, p1.longitude)
		let p4 = CLLocationCoordinate2DMake(p1.latitude, p3.longitude)
		vertices = [p1, p2, p3, p4]
		polygon = MKPolygon(coordinates: &vertices, count: vertices.count)
		ctx.mapView.addOverlay(polygon!, level: MKOverlayLevel.AboveLabels)
	}
	
	/// Remove all the registered pins in the rectangle area.
	func onLongPressFinished(coordinate: CLLocationCoordinate2D) {
		isPressing = false

		// remove overlays
		if ctx.mapView.overlays.count > 0 {
			ctx.mapView.removeOverlays(ctx.mapView.overlays)
		}
		
		// add dummy layer
		let p0 = coordinate
		vertices = [p0, p0, p0, p0]
		polygon = MKPolygon(coordinates: &vertices, count: vertices.count)
		ctx.mapView.addOverlay(polygon!, level: MKOverlayLevel.AboveLabels)

		// delete pins in the selected region
		let pins = ctx.selectPinsInRegion(from: startPos, to: coordinate)
		pins.forEach { (pin) -> () in
			ctx.deletePin(pin)
		}
		
		// allow map scroll again
		ctx.mapView.scrollEnabled = true
	}
	
}

/**
TravelLocationsMapViewController controls displaying and operating a map and dropping new pins on the favorite location. This class should manage their instances persistently using Coredata framework.
*/
class TravelLocationsMapViewController: UIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate
{
	// consts.
	
	/// the first location
	let DefaultLocation = CLLocationCoordinate2DMake(35.6897,139.6922)
	/// the first region size
	let DefaultRegionSize = 0.3
	
	// UI
	
	@IBOutlet weak var mapView: MKMapView!
	/// Top view becomes visible when the edit button is pressed.
	@IBOutlet weak var topView: UIView!
	/// A Vertical constraint between map view and the top of the entier view.
	@IBOutlet weak var heightConstraint: NSLayoutConstraint!
	
	/// While the edit mode, the user can delete any pins.
	var isEditMode: Bool {
		get { return !topView.hidden }
	}
	
	/// To check and store map status (region or center coordinate) only when users change the parameters.
	var justUserChangedMap: Bool = false

	// managed objects
	
	/// map object
	var map: Map!
	
	/// An order set of pins as managed objects
	var pins: NSMutableOrderedSet {
		get{ return map?.valueForKeyPath("pins") as! NSMutableOrderedSet }
	}
	
	// core data
	
	/// the core data stack manager instance
	var coreDataStack: CoreDataStackManager {
		get { return (UIApplication.sharedApplication().delegate as! AppDelegate).coreDataStackManager }
	}
	
	/// the managed object context instance
	var managedObjectContext: NSManagedObjectContext {
		get { return coreDataStack.managedObjectContext }
	}
	
	// long press event handlers

	/// long press handlers that create a new pin
	var createPinOperation: PinCreateDelegate!
	
	/// long press handlers that delete pins
	var deletePinOperation: PinDeleteDelegate!
	
	//------------------------------------------------------------------------//
	// UIViewController related methods
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// initialize UI
		mapView.delegate = self
		topView.hidden = true
		heightConstraint.constant = 0

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
		
		// prepare UI handlers
		createPinOperation = PinCreateDelegate(context: self)
		deletePinOperation = PinDeleteDelegate(context: self)
		
		// fetch managed objects from the core data DB
		fetchMapObject()
		fetchPinObjects()
		
		resumeDownloadingImages()
	}

	override func viewDidAppear(animated: Bool) {
		super.viewWillAppear(animated)
		// go to the previous location
		moveTo(map.center, regionSize: map.regionSize)

		// render pins
		pins.forEach { (obj) -> () in
			let pin = obj as! Pin
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
	// button actions
	
	/// A handler on pressed edit button
	@IBAction func onEditButtonPressed(sender: AnyObject) {
		if topView.hidden {
			// visible top view
			topView.hidden = false
			heightConstraint.constant = topView.frame.size.height
		}
		else { // invisible
			topView.hidden  = true
			heightConstraint.constant = 0
		}
	}
	
	//------------------------------------------------------------------------//
	// GestureRecognizer related methods

	/// A handler on long Pressed gesture
	func onLongPressedGesture(gestureRecognizer: UIGestureRecognizer) {
		// get the coordinates where was tapped
		let tapPoint: CGPoint = gestureRecognizer.locationInView(mapView)
		let coordinate = mapView.convertPoint(tapPoint, toCoordinateFromView: mapView)

		/// choose long press controller according to the current mode (creat or edit).
		let longPressDelegate: LongPressDelegate = isEditMode ? deletePinOperation : createPinOperation
		
		// event handling
		if gestureRecognizer.state == UIGestureRecognizerState.Began {
			longPressDelegate.onLongPressStarted(coordinate)
		}
		else if gestureRecognizer.state == UIGestureRecognizerState.Changed {
			longPressDelegate.onLongPressedAndDragging(coordinate)
		}
		else if gestureRecognizer.state == UIGestureRecognizerState.Ended {
			longPressDelegate.onLongPressFinished(coordinate)
		}
	}
	
	/// A handler on tap gesture
	func onTapGesture(gestureRecognizer: UIGestureRecognizer) {
		if gestureRecognizer.state == UIGestureRecognizerState.Ended {
			justUserChangedMap = true
		}
	}

	/// A handler on drag gesture
	func onDragGesture(gestureRecognizer: UIGestureRecognizer) {
		if gestureRecognizer.state == UIGestureRecognizerState.Ended {
			justUserChangedMap = true
		}
	}
	
	/// Use gesture recongnizers simultaneously
	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return true // for long press, tap, and pan gestures
	}
	
	//------------------------------------------------------------------------//
	// MapViewDelegate methods
	
	/// When a pin was selected
	func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
		let selectedPin = view.annotation as! Pin
		if isEditMode {
			deletePin(selectedPin)
		}
		else {
			self.performSegueWithIdentifier("showPhotoAlbum", sender: selectedPin)
		}
	}
	
	/// When the region did changed after animating
	func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
		if justUserChangedMap {
			storeMapObjects() // only when user's changed the map
			justUserChangedMap = false
		}
	}
	
	/// Render a pin (annotation)
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
		annotationView!.animatesDrop = createPinOperation.justStarted
		return annotationView
	}
	
	/// Render a custom overlay
	func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
		if overlay is MKPolygon {
			let polygonView = MKPolygonRenderer(overlay: overlay)
			polygonView.strokeColor = UIColor.magentaColor()
			if deletePinOperation.isPressing == false {
				return MKPolygonRenderer()
			}
			else {
				return polygonView
			}
		}
		return MKPolygonRenderer()
	}
	
	// map operation helpers
	
	/// Move to the specified location
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
	
	
	/// Select multiple pins located in specified region.
	private func selectPinsInRegion(from from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> [Pin] {
		var ret = [Pin]()
		for obj in pins {
			if let pin = obj as? Pin {
				let x = pin.coordinate.longitude
				let y = pin.coordinate.latitude
				let w = abs(from.longitude - to.longitude)
				let h = abs(from.latitude - to.latitude)
				let isIncludeX = (w >= abs(x - from.longitude) + abs(x - to.longitude))
				let isIncludeY = (h >= abs(y - from.latitude) + abs(y - to.latitude))
				if isIncludeX && isIncludeY {
					ret.append(pin)
				}
			}
		}
		return ret
	}
	
	//------------------------------------------------------------------------//
	// core data and managed objects related methods
	
	/// Fetch pin objects from core data stack.
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
	
	/// Fetch map object from core data stack.
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
	
	/// Store map and pin objects.
	private func storeMapObjects() {
		// updating map location status
		let regionSize = mapView.region.span.longitudeDelta // rather than latitudeDelata
		let center = mapView.region.center
		map.regionSize = regionSize
		map.center = center
		
		coreDataStack.saveContext()
	}
	
	/// Delete a pin and its photo objects persisitently
	private func deletePin(pin: Pin) {
		mapView.removeAnnotation(pin)
		pin.remove(coreDataStack)
		// remove pin from the local array
		pins.removeObject(pin)
	}
	
	//------------------------------------------------------------------------//
	// prefetching image data helpers
	
	/// Prefetch image data from Flickr photo search API. This function starts when user's finger is lift off the map and the new location is decided.
	private func prefetchImageFromFlickr(pin: Pin) {
		// reusing PhotoAlbumViewController method but do nothing for any view objects
		let photoAlbumViewController = self.storyboard!.instantiateViewControllerWithIdentifier("PhotoAlbumViewController") as! PhotoAlbumViewController
		photoAlbumViewController.getImagesFromFlickr(pin, imageDownloadHandler: onImageDownloaded, searchFinishedHandler: { success in /* do nothing */ } )
	}
	
	/// Notifying the completion of image downloads to the PhotoAlbumViewController
	private func onImageDownloaded(photoIndex: Int) {
		// send notification to the photo album view controller
		let notification : NSNotification = NSNotification(name: "imageDownloadNotification", object: self, userInfo: ["value": photoIndex])
		NSNotificationCenter.defaultCenter().postNotification(notification)
	}
	/*
	asynchronous downloading mechanism
	
	[TravelLocationsMapViewController]  [PhotoAlbumViewContoller]
				|                                  |
				|start downloading images          |
				|                                  |
				|  image1 image2  ...              |
				|    |      |                      |
				|    |      |                      |
				|    |      |   notification       |
				|    | --------------------------> |onDownloadNotified:
				|           |     notification     | photo1 = downloaded, check all photos downloaded
				|           |--------------------> |onDownloadNotified:
				|                                  | photo2 = downloaded, check all photos downloaded
	*/

	/*
	resume downloading mechanism
	
	[TravelLocationsMapViewController]  [PhotoAlbumViewContoller]
				|                                  |
				|start downloading images          |
				|all photo = downloading           |
				|                                  |
				|  image1 image2  ...              |
				|    |      |                      |
				|    |      |                      |
				|    |      |   notification       |
				|    | --------------------------> |onDownloadNotified:
				|           |                      | photo1 = downloaded or download failed
		======================= terminate app here =====================
				|                                  |
				|viewDidLoad --> resume downloading images
				|for all downloading or download failed photos,
				|restart downlading
				|  image2  ...                     |
				|    |                             |
				|    |                             |
				|    |         notification        |
				|    |-------------------------->  |onDownloadNotified:
				|                                  | photo2 = downloaded or download failed
	*/

	/// resume downloading images
	private func resumeDownloadingImages() {
		// search pins whose photos are not completely downloaded
		let unpreparedPins = pins.filter { (obj) -> Bool in
			let pin = obj as! Pin
			// fix allPhotoDownloaded flag
			if !pin.allPhotoDownloaded {
				// check successfully downloaded or not
				if Photo.checkAllPhotoDownloaded(pin.photos, isIncludeFailures: false) {
					pin.allPhotoDownloaded = true
					coreDataStack.saveContext()
				}
			}
			return !pin.allPhotoDownloaded
		}
		
		// search photos not completely downloaded
		let unpreparedPhotos = unpreparedPins.reduce([Photo]()) { (var photos, elem) -> [Photo] in
			let pin = elem as! Pin
			// pin.checkCoredata()
			let allPhotoSet = pin.valueForKeyPath("photos") as! NSMutableOrderedSet
			let nondownloadedPhotos = allPhotoSet.reduce([Photo](), combine: { (var ret, elem) -> [Photo] in
				let photo = elem as! Photo
				if (photo.downloaded == Photo.Status.DownladFailed.rawValue ||
					photo.downloaded == Photo.Status.Downloading.rawValue) {
					ret.append(photo)
				}
				return ret
			})
			photos += nondownloadedPhotos
			return photos
		}
		
		// resume downloading images
		unpreparedPhotos.forEach { (photo) -> () in
			trace("resume downloading the image: photo id:\(photo.identifier)")
			let pin = photo.pin!
			
			// restart downloading
			photo.downloaded = Photo.Status.Downloading.rawValue
			
			ImageDownloader().downloadImageAsync(photo.url) { image, success in
				if success {
					if let _ = image {
						trace("finished downloading the image: photo id:\(photo.identifier)")
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
				
				// check all photos are successfully downloaded
				if Photo.checkAllPhotoDownloaded(pin.photos, isIncludeFailures: false) {
					pin.allPhotoDownloaded = true
				}
				
				self.coreDataStack.saveContext()
			}
		}
		
	}
}
