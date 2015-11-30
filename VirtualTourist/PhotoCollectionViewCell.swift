//
//  PhotoCollectionViewCell.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/29.
//  Copyright © 2015 Udacity. All rights reserved.
//

import Foundation

import UIKit

class PhotoCollectionViewCell: UICollectionViewCell {
	@IBOutlet weak var imageView: UIImageView!

	let sharedApp = (UIApplication.sharedApplication().delegate as! AppDelegate)
	var indicator: UIActivityIndicatorView!
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		
	}
	
	required init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)!
	}
	
	func startLoadingAnimation() {
		if indicator == nil {
			indicator = createIndicator(targetView: imageView)
			
		}
		self.sharedApp.dispatch_async_main {
			self.indicator.startAnimating()
		}
	}
	
	func stopLoadingAnimation() {
		self.sharedApp.dispatch_async_main {
			self.indicator.stopAnimating()
		}
	}
	
	private func createIndicator(targetView view: UIView) -> UIActivityIndicatorView {
		let indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.WhiteLarge)
		indicator.frame = CGRectMake(0.0, 0.0, 30.0, 30.0);
		indicator.center = view.center;
		view.addSubview(indicator)
		indicator.bringSubviewToFront(view)
		UIApplication.sharedApplication().networkActivityIndicatorVisible = true
		return indicator
	}
}
