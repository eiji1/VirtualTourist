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

class PhotoAlbumViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
	let sharedApp = (UIApplication.sharedApplication().delegate as! AppDelegate)

	var pin :Pin!
	var page = 1
	var isDownloadingPhotos: Bool = false
	
	var imageStorage: ImageStorage = ImageStorage()
	var imageDownloader: ImageDownloader = ImageDownloader()
	
	@IBOutlet weak var mapView: MKMapView!
	@IBOutlet weak var collectionView: UICollectionView!
	@IBOutlet weak var newCollectionButton: UIButton!
	
	var photos: NSMutableOrderedSet {
		get{ return pin?.valueForKeyPath("photos") as! NSMutableOrderedSet }
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.collectionView.delegate = self;
	}
	
	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		pin.show(mapView)

		fetchPinObjects()
		
		// no photo was downloaded
		if photos.count == 0 {
			getImagesFromFlickr(pin)
		}
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		collectionView.reloadData()
	}

	@IBAction func onOKButtonPressed(sender: AnyObject) {
		self.dismissViewControllerAnimated(true, completion: nil)
	}
	
	@IBAction func onNewCollectionButtonPressed(sender: AnyObject) {
		page++
		removeAllPhotosFromAlbum()
		getImagesFromFlickr(pin) // again
	}
	
	// fetch Pin objects
	private func fetchPinObjects() {
		let coreData = sharedApp.coreDataStackManager
		
		let fetchRequest = NSFetchRequest(entityName: "Photo")
		do {
			let results = try coreData.managedObjectContext.executeFetchRequest(fetchRequest)
			let filteredPhotos = (results as! [Photo]).filter({ (photo) -> Bool in
				return photo.pin == self.pin
			})
			
			filteredPhotos.forEach({ (photo) -> () in
				photos.addObject(photo)
			})
			
			print(photos)
			
		} catch let error as NSError {
			print("Could not fetch \(error), \(error.userInfo)")
		}
		
	}
	
	private func removeAllPhotosFromAlbum() {
		let coreData = sharedApp.coreDataStackManager
		photos.forEach({ (photo) -> () in
			// delete an image from cache and an underlying file from the Documents directory
			imageStorage.removeImage((photo as! Photo).identifier)
			// remove photo as managed object from core data stack
			coreData.managedObjectContext.deleteObject(photo as! NSManagedObject)
		})
		// delete all elements from local array
		photos.removeAllObjects()
		
		coreData.saveContext()
	}
	
	private func removePhotosFromAlbum(photo:Photo) {
		// delete an image from cache and an underlying file from the Documents directory
		imageStorage.removeImage(photo.identifier)
		
		// remove photo as managed object from core data stack
		let coreData = sharedApp.coreDataStackManager
		coreData.managedObjectContext.deleteObject(photo)
		
		// remove photo from the local array
		photos.removeObject(photo)
		
		coreData.saveContext()
	}
	
	func getImagesFromFlickr(pin: Pin) {
		isDownloadingPhotos = true
		newCollectionButton.enabled = false
		
		FlickrClient().getImagesBySearch(pin.coordinate, page: page) { photos, total , success in
			if success {
				print("getting image scceeded!")
				var count = 0
				photos.forEach({ (photo) -> () in
					photo.pin = pin
					photo.identifier = "id\(count)\(pin.latitude)\(pin.longitude)"
					count++
				})

				self.isDownloadingPhotos = false
				
				self.sharedApp.dispatch_async_main {
					self.collectionView.reloadData()
				}
				
			}
		}
	}
	
	/*
	private func onFinishFetchingPhotos (_photos: [Photo]) {
		print("getting image scceeded!")
		var count = 0
		_photos.forEach({ (photo) -> () in
			photo.pin = self.pin
			photo.identifier = "id\(count)\(self.pin.latitude)\(self.pin.longitude)"
			count++
		})
		
		self.isDownloadingPhotos = false
		
		self.sharedApp.dispatch_async_main {
			self.collectionView.reloadData()
		}
	}*/
	
	// returns the number of collection view cells
	func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		print("getting num cells")
		print(pin.photos.count)
		return pin.photos.count == 0 ? 0 : pin.photos.count
	}
	
	// render a collection cell specified with indexPath
	func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		let rowIndex = indexPath.row
		
		let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCollectionViewCell", forIndexPath: indexPath) as! PhotoCollectionViewCell
		cell.userInteractionEnabled = true
		//cell.imageView.contentMode = UIViewContentMode.ScaleAspectFit

		cell.imageView.image = UIImage(named: "VirtualTourist_76")
		cell.startLoadingAnimation()
		
		if isDownloadingPhotos {
			print("retrieving photos from flickr")
			return cell
		}

		let photo = photos.objectAtIndex(rowIndex) as! Photo
		print("url: \(photo.url)")
		print("id: \(photo.identifier)")
		
		print("retrieving image \(rowIndex)")

		// get image from the storage (memory or fiel system)
		if photo.downloaded {
			if let image = imageStorage.getImage(photo.identifier) {
				print("from storage")
				cell.imageView.image = image
				cell.stopLoadingAnimation()
				return cell
			}
		}

		// show the placeholder on downloading an image
		print("start downloading image \(rowIndex)")
		imageDownloader.downloadImageAsync(photo.url) { (image, success) -> () in
			if let _ = image {
				print("finish downloading image \(indexPath.row)")
				
				self.imageStorage.storeImage(image, identifier: photo.identifier)
				photo.downloaded = true
				
				let coreData = self.sharedApp.coreDataStackManager
				coreData.saveContext()
				
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

		
		return cell
	}
	
	// on selecting a collection view cell
	
	
	func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath:NSIndexPath)
	{
		let rowIndex = indexPath.row
		let photo = photos.objectAtIndex(rowIndex) as! Photo
		
		removePhotosFromAlbum(photo)
		collectionView.deleteItemsAtIndexPaths([indexPath])
	}
	
}


