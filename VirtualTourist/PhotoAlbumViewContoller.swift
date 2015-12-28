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
class PhotoAlbumViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, NSFetchedResultsControllerDelegate
{
	// flickr related parameters
	
	/// A parameter specifing a group of photo data
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
	
	/// A selected pin before transition
	var pin :Pin!

	/// Check all pictures has been downloaded and stored to the storage
	var didAllPhotoDownloaded: Bool {
		get {
			return Photo.checkAllPhotoDownloaded(pin?.photos)
		}
	}
	
	// coredata
	
	/// the core data stack manager instance
	var coreDataStack: CoreDataStackManager {
		get { return sharedApp.coreDataStackManager }
	}
	
	/// the managed object context instance
	var managedObjectContext: NSManagedObjectContext {
		get { return coreDataStack.managedObjectContext }
	}
	
	/// fethced result controller for photo objects
	lazy var fetchedResultsController: NSFetchedResultsController = {
		let fetchRequest = NSFetchRequest(entityName: "Photo")
		// associated
		fetchRequest.sortDescriptors = [NSSortDescriptor(key: "identifier", ascending: true)]
		fetchRequest.predicate = NSPredicate(format: "pin == %@", self.pin);
		
		let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
			managedObjectContext: self.managedObjectContext,
			sectionNameKeyPath: nil,
			cacheName: nil)
		
		return fetchedResultsController
	}()
	
	//------------------------------------------------------------------------//
	// UIViewController related methods
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// setting up UIs
		collectionView.delegate = self;
		newCollectionButton.enabled = false
		
		// setting up download notifications
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "onDownloadNotified:", name: "imageDownloadNotification", object: nil)

		// fetch photo managed objects
		do {
			try fetchedResultsController.performFetch()
		} catch {}
		fetchedResultsController.delegate = self
	}
	
	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		
		// render a map
		showMap()
		
		// update UIs
		collectionView.reloadData()
		if didAllPhotoDownloaded {
			newCollectionButton.enabled = true
		}
	}
	
	//------------------------------------------------------------------------//
	// UI actions
	
	@IBAction func onOKButtonPressed(sender: AnyObject) {
		self.dismissViewControllerAnimated(true, completion: nil)
	}
	
	@IBAction func onNewCollectionButtonPressed(sender: AnyObject) {
		// reset album data
		newCollectionButton.enabled = false
		removeAllPhotosFromAlbum()
		
		// new image set
		page++
		// download new images and replace current photos with them
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
	
	/// Delete all pictures associated with selected pin object
	private func removeAllPhotosFromAlbum() {
		// delete all elements from local array
		while fetchedResultsController.sections![0].numberOfObjects > 0 {
			let photo = fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: 0, inSection: 0)) as! Photo
			photo.remove(coreDataStack)
			collectionView.deleteItemsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)])
		}
	}
	
	//------------------------------------------------------------------------//
	// NSFetchedResultsControllerDelegate methods
	
	/// on start to change managed objects
	func controllerWillChangeContent(controller: NSFetchedResultsController) {
		trace("start to change photo objcts")
	}
	
	/// when a section is changed
	func controller(controller: NSFetchedResultsController,
		didChangeSection sectionInfo: NSFetchedResultsSectionInfo,
		atIndex sectionIndex: Int,
		forChangeType type: NSFetchedResultsChangeType) {
		// do nothing
	}
	
	/// when a managed object is changed
	func controller(controller: NSFetchedResultsController,
		didChangeObject anObject: AnyObject,
		atIndexPath indexPath: NSIndexPath?,
		forChangeType type: NSFetchedResultsChangeType,
		newIndexPath: NSIndexPath?) {
			switch type {
			case .Insert: break
			case .Delete:
				let photo = anObject as! Photo
				// automatically delete underlying files
				photo.removeImageFiles()
				pin.checkCoredata()
				break
			case .Update:
				let index = indexPath!.row
				sharedApp.dispatch_async_main() {
					self.collectionView.reloadItemsAtIndexPaths([NSIndexPath(forRow: index, inSection: 0)])
				}
				pin.checkCoredata()
				break
			default: break
			}
	}
	
	/// at the end of changing managed objects
	func controllerDidChangeContent(controller: NSFetchedResultsController) {
		trace("end changing photo objcts")
	}
	
	//------------------------------------------------------------------------//
	// UICollectionViewDataSource, UICollectionViewDelegate related methods
	
	// returns the number of collection view cells
	func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		let sectionInfo = self.fetchedResultsController.sections![section]
		trace(sectionInfo.numberOfObjects)
		return sectionInfo.numberOfObjects
	}
	
	// render a collection cell specified with indexPath
	func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCollectionViewCell", forIndexPath: indexPath) as! PhotoCollectionViewCell
		cell.userInteractionEnabled = true

		let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
		
		if photo.downloaded == Photo.Status.Downloaded.rawValue {
			// display an image in the storage, new download is not necessary
			if let image = imageStorage.getImage(photo.identifier) {
				cell.imageView.image = image
				
				cell.stopLoadingAnimation()
				return cell
			}
		}
		else if photo.downloaded == Photo.Status.DownladFailed.rawValue {
			cell.imageView.image = UIImage(named: "VirtualTourist_76")
			cell.stopLoadingAnimation()
		}
		else if photo.downloaded == Photo.Status.Downloading.rawValue {
			// show the placeholder on downloading an image
			cell.imageView.image = UIImage(named: "VirtualTourist_76")
			cell.startLoadingAnimation()
		}
		else {
			// nothing displayed
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
		
		let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
		photo.remove(coreDataStack)
		
		collectionView.deleteItemsAtIndexPaths([indexPath])
	}

	// helper methods

	/// download completion handler
	private func onImageDownloaded(photoIndex: Int) {
		sharedApp.dispatch_async_main {
			if let _ = self.collectionView {
				// reload the corresponding cell
				self.collectionView.reloadItemsAtIndexPaths([NSIndexPath(forRow: photoIndex, inSection: 0)])
				if self.didAllPhotoDownloaded {
					self.collectionView.reloadData()
					self.newCollectionButton.enabled = true
				}
			}
		}
	}
	
	/// A selector notifying download completion (not defined as private method)
	func onDownloadNotified(notification: NSNotification)  {
		if let userInfo = notification.userInfo {
			let photoIndex = userInfo["value"] as! Int
			onImageDownloaded(photoIndex)
		}
	}
	
	/// This handler is called when Photo urls are successfully retrieved from Flickr.
	private func onPhotoURLsRetrieved(success: Bool) {
		if success {
			sharedApp.dispatch_async_main {
				if let collectionView = self.collectionView {
					collectionView.reloadData()
				}
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
	func getImagesFromFlickr(pin: Pin, imageDownloadHandler: (photoIndex: Int)->(),
		searchFinishedHandler: (success: Bool)->()) {
		if FlickrClient.sharedInstance().isSearchingImages {
			trace("searching images now")
			return
		}
		
		// search image urls from Flickr
		FlickrClient.sharedInstance().getImagesBySearch(pin.coordinate, page: page) { _photos, total , success in
			if success {
				trace("got images from Flikcr!")
				for (index, photo) in _photos.enumerate() {
					photo.pin = pin // set an inverse relationship
					photo.identifier = "\(pin.identifier)_\(index)" // creating an identifier by index
					
					trace("start downloading an image \(index)")
					self.downloadImageFromServer(photo) { image in
						imageDownloadHandler(photoIndex: index)
					}
				}
			}
			searchFinishedHandler(success: success)
		}
	}
	
	/// download image data from specified Url
	private func downloadImageFromServer(photo: Photo, completionHandler: (image: UIImage?) -> ()) {
		photo.downloaded = Photo.Status.Downloading.rawValue
		
		imageDownloader.downloadImageAsync(photo.url) { (image, success) -> () in
			if success {
				if let _ = image {
					trace("finished downloading the image: photo id:\(photo.identifier)")
					// save the downloaded data to the image storage
					self.imageStorage.storeImage(image, identifier: photo.identifier)
					photo.path = self.imageStorage.createFileURL(photo.identifier)
					photo.downloaded = Photo.Status.Downloaded.rawValue
				}
				else {
					photo.downloaded = Photo.Status.DownladFailed.rawValue
				}
			}
			else {
				photo.downloaded = Photo.Status.DownladFailed.rawValue
			}
			
			self.coreDataStack.saveContext()
			completionHandler(image: image)
		}
	}
}


