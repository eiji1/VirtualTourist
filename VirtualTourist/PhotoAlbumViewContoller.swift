//
//  PhotoAlbumViewContoller.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/24.
//  Copyright © 2015 eiji & Udacity. All rights reserved.
//

import MapKit
import CoreData

/**
PhotoAlbumViewController shows a photo album associated with the selected pin's location. The photo images are downloaded from Flickr's photo search API and should be displayed on offline. The photo images can be removed by selecting cells in the collection view. This class should handle the photo objects persistently.
*/
class PhotoAlbumViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, NSFetchedResultsControllerDelegate
{
	// flickr related parameters
	
	/// A parameter specifing a group of photo data
	var page = Const.Flickr.DefaultPage

	// helper classes
	let sharedApp = (UIApplication.sharedApplication().delegate as! AppDelegate)
	
	// UI
	@IBOutlet weak var mapView: MKMapView!
	@IBOutlet weak var collectionView: UICollectionView!
	@IBOutlet weak var newCollectionButton: UIButton!
	
	// managed objects
	
	/// A selected pin before transition
	var pin :Pin!

	/// Check all image downloads are finished (some downloads might be failed or timeout because of network issues)
	var allPhotoDownloadsFinished: Bool {
		get {
			return Photo.checkAllPhotoDownloaded(pin?.photos, isIncludeFailures: true)
		}
	}
	
	/// Check all pictures has been successfully downloaded
	var allPhotoDownloadsSuccessfullyFinished: Bool {
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
	//MARK: UIViewController related methods
	
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
		if allPhotoDownloadsFinished {
			newCollectionButton.enabled = true
		}
	}
	
	//------------------------------------------------------------------------//
	//MARK: Button actions
	
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
		FlickrClient.sharedInstance().downloadPhotos(pin, page: page, imageDownloadHandler: onImageDownloaded, searchFinishedHandler: onPhotoURLsRetrieved)
	}

	//------------------------------------------------------------------------//
	//MARK: Map helper function
	
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
	//MARK: Helper methods for managed objects
	
	/// Delete all pictures associated with selected pin object
	private func removeAllPhotosFromAlbum() {
		trace("check thread at removeAllPhotosFromAlbum", detail: true) // main thread
		
		pin.allPhotoDownloaded = false
		
		// delete all elements from local array
		while fetchedResultsController.sections![0].numberOfObjects > 0 {
			let photo = fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: 0, inSection: 0)) as! Photo
			photo.remove(coreDataStack)
			collectionView.deleteItemsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)])
		}
	}
	
	//------------------------------------------------------------------------//
	//MARK: NSFetchedResultsControllerDelegate methods
	
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
				// automatically delete underlying files (solution 2)
				photo.removeImageFiles()
				pin.checkCoredata()
				break
			case .Update:
				let index = indexPath!.row
				sharedApp.dispatch_async_main() {
					if index < self.collectionView.numberOfItemsInSection(0) {
						self.collectionView.reloadItemsAtIndexPaths([NSIndexPath(forRow: index, inSection: 0)])
					}
					self.pin.checkCoredata()
				}
				break
			default: break
			}
	}
	
	/// at the end of changing managed objects
	func controllerDidChangeContent(controller: NSFetchedResultsController) {
		trace("end changing photo objcts")
	}
	
	//------------------------------------------------------------------------//
	//MARK: UICollectionViewDataSource, UICollectionViewDelegate related methods
	
	// returns the number of collection view cells
	func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		let sectionInfo = self.fetchedResultsController.sections![section]
		trace(sectionInfo.numberOfObjects)
		return sectionInfo.numberOfObjects
	}
	
	// render a collection cell specified with indexPath
	func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		trace("check thread at collectionView", detail: true) // global queue and main queue!!
		
		let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCollectionViewCell", forIndexPath: indexPath) as! PhotoCollectionViewCell
		
		// [core data concurrency] update managed objects and UIs on main thread
		sharedApp.dispatch_sync_main {
		
			cell.userInteractionEnabled = true
			
			let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
			if photo.downloaded == Photo.Status.Downloaded.rawValue {
				// display an image in the storage, new download is not necessary
				if let image = ImageStorage().getImage(photo.identifier) {
					cell.imageView.image = image
					cell.stopLoadingAnimation()
				}
			}
			else if photo.downloaded == Photo.Status.DownladFailed.rawValue {
				cell.imageView.image = UIImage(named: "VirtualTourist_76")
				cell.stopLoadingAnimation() // hide loading animation
			}
			else if photo.downloaded == Photo.Status.Downloading.rawValue {
				// show the placeholder on downloading an image
				cell.imageView.image = UIImage(named: "VirtualTourist_76")
				cell.startLoadingAnimation()
			}
			else {
				// nothing displayed
			}

		} // dispatch
		
		return cell
	}
	
	// on selecting a collection view cell
	func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath:NSIndexPath)
	{
		// Do nothing until the downloading ends.
		// But after finished the downloads, the app should be able to delete any cells.
		if !allPhotoDownloadsFinished {
			return
		}
		
		let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
		photo.remove(coreDataStack)
		
		collectionView.deleteItemsAtIndexPaths([indexPath])
	}
	
	//------------------------------------------------------------------------//
	//MARK: Helper methods for image downloads

	/// Download completion handler
	///
	/// - returns: None
	/// - parameter photoIndex: An index of photo object, photoIndex is -1 if no photo was retrieved.
	private func onImageDownloaded(photoIndex: Int) {
		trace("check thread is image download thread", detail: true) // global queue

		// [core data concurrency] update managed objects on main thread
		self.sharedApp.dispatch_async_main {
			
			// if some download results are failed, pin status should not be updated,
			// so that their downloads could restarts after launching the app next time.
			if self.allPhotoDownloadsSuccessfullyFinished {
				self.pin.allPhotoDownloaded = true
				self.coreDataStack.saveContext()
			}
			
			if let _ = self.collectionView {
				// valid index
				if photoIndex >= 0 {
					// reload the corresponding cell
					self.collectionView.reloadItemsAtIndexPaths([NSIndexPath(forRow: photoIndex, inSection: 0)])
				}
				// After finished the downloads, the app should enables new collection button anyway.
				if self.allPhotoDownloadsFinished {
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
}


