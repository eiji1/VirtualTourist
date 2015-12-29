//
//  PhotoCollectionViewCell.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/29.
//  Copyright © 2015 eiji & Udacity. All rights reserved.
//

import UIKit

/**
PhotoCollectionViewCell class controls each cell in the photo album view (collection view).
*/
class PhotoCollectionViewCell: UICollectionViewCell {
	@IBOutlet weak var imageView: UIImageView!

	let sharedApp = (UIApplication.sharedApplication().delegate as! AppDelegate)
	var indicator: UIActivityIndicatorView?
	
	override init(frame: CGRect) {
		super.init(frame: frame)
	}
	
	required init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)!
	}
	
	/// start displaying an indicator before dowloading images starts
	func startLoadingAnimation() {
		if indicator == nil {
			indicator = createIndicator(targetView: imageView)
			
		}
		sharedApp.dispatch_async_main {
			self.indicator?.startAnimating()
		}
	}
	
	/// stop displaying an indicator when dowloading images is completed
	func stopLoadingAnimation() {
		if let indicator = self.indicator {
			if indicator.isAnimating() {
				sharedApp.dispatch_async_main {
					self.indicator?.stopAnimating()
				}
			}
		}
	}
	
	/// create an indicator
	private func createIndicator(targetView view: UIView) -> UIActivityIndicatorView {
		// create a new indicator
		let indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.WhiteLarge)
		indicator.frame = CGRectMake(0.0, 0.0, 30.0, 30.0);
		indicator.center = view.center;
		// set to the view
		view.addSubview(indicator)
		indicator.bringSubviewToFront(view)
		UIApplication.sharedApplication().networkActivityIndicatorVisible = true
		return indicator
	}
}
