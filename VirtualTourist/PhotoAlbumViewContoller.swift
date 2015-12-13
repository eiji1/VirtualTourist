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
	var isDownloadingPhotos: Bool = false
	
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
	}
	
	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		
		showMap()
		fetchPhotoObjects()
		
		// no photo is downloaded
		if photos.count == 0 && !isDownloadingPhotos {
			newCollectionButton.enabled = false
			getImagesFromFlickr(pin) {
				self.sharedApp.dispatch_async_main {
					self.collectionView.reloadData()
				}
			}
		}
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		collectionView.reloadData()
	}
	
	//------------------------------------------------------------------------//
	// UI actions
	
	@IBAction func onOKButtonPressed(sender: AnyObject) {
		self.dismissViewControllerAnimated(true, completion: nil)
	}
	
	@IBAction func onNewCollectionButtonPressed(sender: AnyObject) {
		removeAllPhotosFromAlbum()
		
		// new image data set
		page++
		newCollectionButton.enabled = false
		getImagesFromFlickr(pin) { // again
			self.sharedApp.dispatch_async_main {
				self.collectionView.reloadData()
			}
		}
	}

	/// show a map
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
	
	// fetch Pin objects
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
		return pin.photos.count
	}
	
	// render a collection cell specified with indexPath
	func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		let rowIndex = indexPath.row
		
		let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCollectionViewCell", forIndexPath: indexPath) as! PhotoCollectionViewCell
		cell.userInteractionEnabled = true
		
		// show the placeholder on downloading an image
		cell.imageView.image = UIImage(named: "VirtualTourist_76")
		cell.startLoadingAnimation()
		
		if isDownloadingPhotos {
			trace("retrieving photos from flickr")
			return cell
		}

		let photo = photos.objectAtIndex(rowIndex) as! Photo
		trace("url: \(photo.url)")
		trace("id: \(photo.identifier)")
		trace("retrieving image \(rowIndex)")
		
		if photo.downloaded {
			if let image = imageStorage.getImage(photo.identifier) {
				print("from storage: index:\(rowIndex), photo id:\(photo.identifier)")
				cell.imageView.image = image
				cell.stopLoadingAnimation()
				return cell
			}
		}

		/*
		// get image from the storage (memory or file system)
		let gotImage = getImageFromStorage(photo) { image in
			cell.imageView.image = image
			cell.stopLoadingAnimation()
		}
		if gotImage {
			return cell
		}
		*/
		
		
		trace("start downloading an image \(rowIndex)")
		
		downloadImageFromServer(photo) { image in
			// update the image view in the cell and the new collection button
			self.sharedApp.dispatch_async_main {
				cell.imageView.image = image
				if Photo.checkAllPhotoDownloaded(self.pin.photos) {
					self.newCollectionButton.enabled = true
				}
			}
			cell.stopLoadingAnimation()
		}
		
		/*
		imageDownloader.downloadImageAsync(photo.url) { (image, success) -> () in
			if let _ = image {
				print("finished downloading the image \(indexPath.row)")
				
				// save the downloaded image data
				self.imageStorage.storeImage(image, identifier: photo.identifier)
				photo.path = self.imageStorage.createFileURL(photo.identifier)
				photo.downloaded = true
				
				self.coreDataStack.saveContext()
				
				// update the image view in the cell and the new collection button
				self.sharedApp.dispatch_async_main {
					cell.imageView.image = image
					if Photo.checkAllPhotoDownloaded(self.pin.photos) {
						self.newCollectionButton.enabled = true
					}
				}
				
				cell.stopLoadingAnimation()
			}
		}
		*/
		
		return cell
	}
	
	// on selecting a collection view cell
	func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath:NSIndexPath)
	{
		// check all images have been downloaded
		if !Photo.checkAllPhotoDownloaded(pin.photos) {
			return
		}
		
		let rowIndex = indexPath.row
		let photo = photos.objectAtIndex(rowIndex) as! Photo
		
		removePhotosFromAlbum(photo)
		collectionView.deleteItemsAtIndexPaths([indexPath])
	}
	
	// helper methods
	
	func getImagesFromFlickr(pin: Pin, handler: () -> ()) {
		isDownloadingPhotos = true
		FlickrClient().getImagesBySearch(pin.coordinate, page: page) { photos, total , success in
			if success {
				trace("getting images from Flikcr!")
				
				for (index, photo) in photos.enumerate() {
					photo.pin = pin // set relationship
					photo.identifier = "\(pin.identifier)_\(index)" // creating an identifier by index
				}
				
				self.isDownloadingPhotos = false
				handler()
			}
		}
	}
	
	func downloadImageFromServer(photo: Photo, handler: (image: UIImage?) -> ()) {
		imageDownloader.downloadImageAsync(photo.url) { (image, success) -> () in
			if let _ = image {
				trace("finished downloading the image: photo id:\(photo.identifier)")
				// save the downloaded data
				self.imageStorage.storeImage(image, identifier: photo.identifier)
				photo.path = self.imageStorage.createFileURL(photo.identifier)
				photo.downloaded = true
				
				self.coreDataStack.saveContext()
				
				handler(image: image)
			}
		}
	}
}


