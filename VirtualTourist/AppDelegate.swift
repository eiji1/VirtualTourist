//
//  AppDelegate.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/24.
//  Copyright © 2015 eiji & Udacity. All rights reserved.
//

import UIKit

// logging
func trace(message: Any..., detail: Bool = false) {
//#if DEBUG
	var str = ""
	if detail {
		str = "\(message) at file: \(__FILE__), func:\(__FUNCTION__), line: \(__LINE__), col: \(__COLUMN__): th:\(NSThread.currentThread())"
	} else {
		str = "\(message)"
	}
	print(str)
//#endif
}

func errorLog(message: Any...) {
#if DEBUG
	print(message)
#else
	// output log
#endif
}


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var coreDataStackManager: CoreDataStackManager = CoreDataStackManager()
	
	var window: UIWindow?

	func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
		// Override point for customization after application launch.
		return true
	}

	func applicationWillResignActive(application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
	}

	func applicationDidEnterBackground(application: UIApplication) {
		// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	}

	func applicationWillEnterForeground(application: UIApplication) {
		// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
	}

	func applicationDidBecomeActive(application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	}

	func applicationWillTerminate(application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
		// Saves changes in the application's managed object context before the application terminates.
		coreDataStackManager.saveContext()
	}

	// async dispatching
	

	/// Execute functional block asynchronously on the global queue
	///
	/// - returns: None
	/// - parameter handler target block which should be executed asynchronously
	func dispatch_async_globally(handler: () -> ()) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), handler)
	}
	
	/// Execute functional block asynchronously on the main thread
	///
	/// - returns: None
	/// - parameter handler target block which should be executed asynchronously
	func dispatch_async_main(handler: () -> ()) {
		dispatch_async(dispatch_get_main_queue(),handler);
	}
	
	/// Execute functional block synchronously on the main queue.
	///
	/// **[core data concurrency]** This method is used for core data objects.
	/// The functional block will be executed in performBlockAndWait method.
	/// Do not run processses with a lot of calculations.
	/// - returns: None
	/// - parameter handler target handler function which should be executed asynchronously
	func dispatch_sync_main(handler: () -> ()) {
		coreDataStackManager.managedObjectContext.performBlockAndWait(handler)
	}
}

