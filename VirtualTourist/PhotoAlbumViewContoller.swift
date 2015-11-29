//
//  PhotoAlbumViewContoller.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/24.
//  Copyright © 2015 Udacity. All rights reserved.
//

import Foundation
import MapKit

class PhotoAlbumViewController: UIViewController, UICollectionViewDataSource {
	let sharedApp = (UIApplication.sharedApplication().delegate as! AppDelegate)

	var pin :Pin!
	var page = 1
	
	@IBOutlet weak var mapView: MKMapView!
	@IBOutlet weak var collectionView: UICollectionView!
	@IBOutlet weak var newCollectionButton: UIButton!
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		pin.show(mapView)

		getImagesFromFlickr()
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
		getImagesFromFlickr()
	}
	
	private func getImagesFromFlickr() {
		newCollectionButton.enabled = false
		
		FlickrClient().getImagesBySearch(pin.coordinate, page: page) { photos, total , success in
			if success {
				print("getting image scceeded!")
				self.pin.photos = photos
				self.sharedApp.dispatch_async_main {
					self.collectionView.reloadData()
				}
				
			}
		}
	}
	
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
		cell.imageView.contentMode = UIViewContentMode.ScaleAspectFit

		print("start downloading image \(rowIndex)")
		let photo = pin.photos[rowIndex]
		
		if !photo.downloaded {
			// show the placeholder on downloading an image
			cell.imageView.image = UIImage(named: "VirtualTourist_76")
			cell.startLoadingAnimation()
			
			FlickrClient().downloadPhotoImageAsync(photo) { (imageData, success) -> () in
				if let _ = imageData {
					print("finish downloading an image \(indexPath.row)")
					photo.downloaded = true
					
					self.sharedApp.dispatch_async_main {
						cell.imageView.image = UIImage(data: imageData!)
						if Photo.checkAllPhotoDownloaded(self.pin.photos) {
							self.newCollectionButton.enabled = true
						}
					}
					
					cell.stopLoadingAnimation()
				}
			}
		}
		
		return cell
	}

}


