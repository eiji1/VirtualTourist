//
//  PhotoAlbumViewContoller.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/24.
//  Copyright © 2015 Udacity. All rights reserved.
//

import Foundation
import MapKit

public class Photo : NSObject {
	var url: String = ""
	var downloaded = false
	
	public init(dictionary: [String : AnyObject]) {
		url = dictionary[FlickrClient.JSONResponseKeys.Url] as! String
		
		super.init()
	}
	
	static func getPhotoFromResults(results: [[String : AnyObject]]) -> [Photo] {
		var photos = [Photo]()
		for result in results {
			photos.append(Photo(dictionary: result))
		}
		return photos
	}
	
	static func checkAllPhotoDownloaded(photos: [Photo]) -> Bool {
		var isDownloaded = true
		for photo in photos {
			isDownloaded = isDownloaded && photo.downloaded
		}
		return isDownloaded
	}
}


class PhotoAlbumViewController: UIViewController, UICollectionViewDataSource {
	let sharedApp = (UIApplication.sharedApplication().delegate as! AppDelegate)

	var location :CLLocationCoordinate2D!
	var photos: [Photo] = []
	var page = 1
	
	@IBOutlet weak var mapView: MKMapView!
	@IBOutlet weak var collectionView: UICollectionView!
	@IBOutlet weak var newCollectionButton: UIButton!
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		let newPin = Pin(coordinates: location)
		newPin.show(mapView)

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
		
		FlickrClient().getImagesBySearch(location, page: page) { photos, total , success in
			if success {
				print("getting image scceeded!")
				self.photos = photos
				self.sharedApp.dispatch_async_main {
					self.collectionView.reloadData()
				}
				
			}
		}
	}
	
	// returns the number of collection view cells
	func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		print("getting num cells")
		print(photos.count)
		return photos.count == 0 ? 0 : photos.count
	}
	
	// render a collection cell specified with indexPath
	func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		let rowIndex = indexPath.row
		
		let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCollectionViewCell", forIndexPath: indexPath) as! PhotoCollectionViewCell
		cell.imageView.contentMode = UIViewContentMode.ScaleAspectFit

		print("start downloading image \(rowIndex)")
		let photo = photos[rowIndex]
		
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
						if Photo.checkAllPhotoDownloaded(self.photos) {
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


