//
//  VirtualTouristTests.swift
//  VirtualTouristTests
//
//  Created by eiji on 2015/11/24.
//  Copyright © 2015年 Udacity. All rights reserved.
//

import XCTest
import XCTest
import VirtualTourist
import CoreLocation

@testable import VirtualTourist

class VirtualTouristTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
	
	func testFlickrPhotoSearch() {
		
		let location = CLLocationCoordinate2DMake(35.6897,139.6922)
		
		let expectation = expectationWithDescription("search")
		
		TestingHelper.getImages(location) { photos, total , success in
			if success {
				//let userId = TestingHelper.getImages()
				expectation.fulfill()
			} else {
				print("login failed")
				XCTAssert(false, "failed")
			}
		}
		
		self.waitForExpectationsWithTimeout(10.0, handler:nil)
	}
}
