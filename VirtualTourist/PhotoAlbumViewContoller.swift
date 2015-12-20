//
//  PhotoAlbumViewContoller.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/24.
//  Copyright © 2015 Udacity. All rights reserved.
//

import Foundation
import MapKit
import CoreData

/**
PhotoAlbumViewController shows a photo album associated with the selected pin's location. The photo images are downloaded from Flickr's photo search API and should be displayed on offline. The photo images can be removed by selecting cells in the collection view. This class should handle the photo objects persistently.
*/
class PhotoAlbumViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

	// flickr related parameters
	var page = 1

	// helper classes
	var imageStorage: ImageStorage = ImageStorage()
	var imageDownloader: ImageDownloader = ImageDownloader()
	let sharedApp = (UIApplication.sharedApplication().delegate as! AppDelegate)
	
	// UI
	@IBOutlet weak var mapView: MKMapView!
	@IBOutlet weak var collectionView: UICollectionView!
	@IBOutlet weak var newCollectionButton: UIButton!
	
	// managed objects
	var pin :Pin!
	
	var photos: NSMutableOrderedSet {
		get{ return pin?.valueForKeyPath("photos") as! NSMutableOrderedSet }
	}
	
	private var _didAllPhotoDownloaded: Bool? = nil
	var didAllPhotoDownloaded: Bool {
		get {
			if let _ = _didAllPhotoDownloaded {
				return _didAllPhotoDownloaded!
			}
			else {
				_didAllPhotoDownloaded = Photo.checkAllPhotoDownloaded(pin?.photos)
				return _didAllPhotoDownloaded!
			}
		}
		set(val) { _didAllPhotoDownloaded = val }
	}
	
	// coredata
	var coreDataStack: CoreDataStackManager {
		get { return sharedApp.coreDataStackManager }
	}
	var managedObjectContext: NSManagedObjectContext {
		get { return coreDataStack.managedObjectContext }
	}
	
	//------------------------------------------------------------------------//
	// UIViewController related methods
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.collectionView.delegate = self;
		
		//dispatch_semaphore_signal(semaphore)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "onImageDownloaded:", name: "imageDownloadNotification", object: nil)
		
		newCollectionButton.enabled = false
	}
	
	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		
		showMap()
		fetchPhotoObjects()
		
		// no photo is downloaded
		if photos.count == 0 {
			getImagesFromFlickr(pin, imageDownloadHandler: onImageDownloaded, searchFinishedHandler: onPhotoURLsRetrieved)
		}
		collectionView.reloadData()
		
		if didAllPhotoDownloaded {
			newCollectionButton.enabled = true
		}
		else {
			// resume downloading
		}
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
	}
	
	//------------------------------------------------------------------------//
	// UI actions
	
	@IBAction func onOKButtonPressed(sender: AnyObject) {
		self.dismissViewControllerAnimated(true, completion: nil)
	}
	
	@IBAction func onNewCollectionButtonPressed(sender: AnyObject) {
		// reset
		removeAllPhotosFromAlbum()
		newCollectionButton.enabled = false
		didAllPhotoDownloaded = false
		
		// new image data set
		page++
		getImagesFromFlickr(pin, imageDownloadHandler: onImageDownloaded, searchFinishedHandler: onPhotoURLsRetrieved)
		
	}

	/// show a currently selected pin on the map
	private func showMap() {
		if let map = pin.map {
			let regionSize = map.regionSize
			let span = MKCoordinateSpanMake(regionSize, regionSize)
			let region = MKCoordinateRegionMake(pin.coordinate, span)
			mapView.setRegion(region, animated: false);
		}
		
		pin.show(mapView)
	}
	
	//------------------------------------------------------------------------//
	// helper methods for managed objects
	
	/// fetch Pin objects
	private func fetchPhotoObjects() {
		let fetchRequest = NSFetchRequest(entityName: "Photo")
		do {
			let results = try managedObjectContext.executeFetchRequest(fetchRequest)
			let filteredPhotos = (results as! [Photo]).filter({ (photo) -> Bool in
				return photo.pin == self.pin
			})
			
			filteredPhotos.forEach({ (photo) -> () in
				photos.addObject(photo)
			})
			
			print(photos)
			
		} catch let error as NSError {
			errorLog("Could not fetch \(error), \(error.userInfo)")
		}
		
	}
	
	private func removeAllPhotosFromAlbum() {
		photos.forEach({ (photo) -> () in
			// delete an image from cache and an underlying file from the Documents directory
			imageStorage.removeImage((photo as! Photo).identifier)
			// remove photo as managed object from core data stack
			managedObjectContext.deleteObject(photo as! NSManagedObject)
		})
		// delete all elements from local array
		photos.removeAllObjects()
		
		coreDataStack.saveContext()
	}
	
	private func removePhotosFromAlbum(photo:Photo) {
		// delete an image from cache and an underlying file from the Documents directory
		imageStorage.removeImage(photo.identifier)
		
		// remove photo as managed object from core data stack
		managedObjectContext.deleteObject(photo)
		
		// remove photo from the local array
		photos.removeObject(photo)
		
		coreDataStack.saveContext()
	}
	
	//------------------------------------------------------------------------//
	// UICollectionViewDataSource, UICollectionViewDelegate related methods
	
	// returns the number of collection view cells
	func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		trace(pin.photos.count)
		return pin.photos.count
	}
	
	// render a collection cell specified with indexPath
	func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		let rowIndex = indexPath.row
		
		let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCollectionViewCell", forIndexPath: indexPath) as! PhotoCollectionViewCell
		cell.userInteractionEnabled = true

		
		let photo = photos.objectAtIndex(rowIndex) as! Photo
		trace("url: \(photo.url)")
		trace("id: \(photo.identifier)")
		trace("downloaded: \(photo.downloaded)")
		trace("retrieving image \(rowIndex)")
		
		if photo.downloaded == Photo.Status.Downloaded.rawValue {
			if let image = imageStorage.getImage(photo.identifier) {
				print("from storage: index:\(rowIndex), photo id:\(photo.identifier)")
				cell.imageView.image = image
				
				cell.stopLoadingAnimation()
				return cell
			}
		}
		else {
			// show the placeholder on downloading an image
			cell.imageView.image = UIImage(named: "VirtualTourist_76")
			cell.startLoadingAnimation()
		}

		return cell
	}
	
	// on selecting a collection view cell
	func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath:NSIndexPath)
	{
		// do nothing until the downloading ends.
		if !didAllPhotoDownloaded {
			return
		}
		
		let rowIndex = indexPath.row
		let photo = photos.objectAtIndex(rowIndex) as! Photo
		
		removePhotosFromAlbum(photo)
		collectionView.deleteItemsAtIndexPaths([indexPath])
	}

	// helper methods

	func onAllImagesDownloaded() {
		sharedApp.dispatch_async_main {
			self.newCollectionButton.enabled = true
		}
	}

	func onImageDownloaded(photo: Photo, index: Int, allPhotosDownloaded: Bool) {
		trace("downloaded: \(photo.downloaded)")
		
		sharedApp.dispatch_async_main {
			if let collectionView = self.collectionView {
					self.collectionView.reloadItemsAtIndexPaths([NSIndexPath(forRow: index, inSection: 0)])
				if allPhotosDownloaded {
					collectionView.reloadData()
				}
			}
		}
		if allPhotosDownloaded {
			self.onAllImagesDownloaded()
		}
	}
	
	func onImageDownloaded(notification: NSNotification)  {
		if let userInfo = notification.userInfo {
			let index = userInfo["value"] as! Int
			let didDownloaded = userInfo["downloaded"] as! Bool
			sharedApp.dispatch_async_main {
				if let collectionView = self.collectionView {
					collectionView.reloadItemsAtIndexPaths([NSIndexPath(forRow: index, inSection: 0)])
				}
				if didDownloaded {
					self.onAllImagesDownloaded()
				}
			}
		}

	}
	
	func onPhotoURLsRetrieved() {
		sharedApp.dispatch_async_main {
			if let collectionView = self.collectionView {
				collectionView.reloadData()
			}
		}
	}
	
	/// Download images using Flickr photo search web API. This method runs following processes.
	/// 1. Search photos using Flickr API specified with location and get their images' URL strings
	///
	///    Call searchFinishedHandler when photo search is completed.
	/// 2. Download their image data from the URLs
	///
	///    Call imageDownloadHandler when each image download is completed.
	///
	/// - returns: None
	/// - parameter pin: a pin object which has a location where photos should be searched
	/// - parameter imageDownloadHandler: a completion handler called on image downloading finished
	/// - parameter searchFinishedHandler: a completion handler called on the photo search finished
	func getImagesFromFlickr(pin: Pin, imageDownloadHandler: (photo:Photo, index: Int, allPhotosDownloaded: Bool)->(),
		searchFinishedHandler: ()->()) {
		if FlickrClient.sharedInstance().isSearchingImages {
			trace("searching images now")
			return
		}
		
		// search image urls from Flickr
		FlickrClient.sharedInstance().getImagesBySearch(pin.coordinate, page: page) { photos, total , success in
			if success {
				trace("got images from Flikcr!")
				for (index, photo) in photos.enumerate() {
					photo.pin = pin // set relationship
					photo.identifier = "\(pin.identifier)_\(index)" // creating an identifier by index
					
					trace("start downloading an image \(index)")
					self.downloadImageFromServer(photo) { image in
						let didAllPhotosDownload = Photo.checkAllPhotoDownloaded(photos)
						imageDownloadHandler(photo: photo, index: index, allPhotosDownloaded: didAllPhotosDownload)
					}
				}
			}
			searchFinishedHandler()
		}
	}
	
	/// download image data from specified Url
	private func downloadImageFromServer(photo: Photo, completionHandler: (image: UIImage?) -> ()) {
		imageDownloader.downloadImageAsync(photo.url) { (image, success) -> () in
			if let _ = image {
				trace("finished downloading the image: photo id:\(photo.identifier)")
				// save the downloaded data
				self.imageStorage.storeImage(image, identifier: photo.identifier)
				photo.path = self.imageStorage.createFileURL(photo.identifier)
				photo.downloaded = Photo.Status.Downloaded.rawValue
				
				self.coreDataStack.saveContext()
				
				completionHandler(image: image)
			}
		}
	}
}


