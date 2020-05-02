//
//  ZipDirectoryWrappingTests.swift
//  FoundationZip
//
//  Created by Ben Spratling on 10/10/16.
//
//

import Foundation
import XCTest
import SwiftPatterns
@testable import SwiftFoundationCompression


open class ZipDirectoryWrappingTests : XCTestCase {

	func fileInTestSource(named:String, withExtension:String)->URL {
		let dir:URL = URL(fileURLWithPath: #file).deletingLastPathComponent()
		return dir.appendingPathComponent(named + "." + withExtension)
	}
	
	open func testMusicDirectories() {
		let zipURL = fileInTestSource(named: "I Surrender All", withExtension: "mxl")
		let data = try! Data(contentsOf: zipURL)
		guard let zipWrapper = try? ZipDirectoryWrapping(zippedData:data) else {
			XCTAssertTrue(false)
			return
		}
		guard let metaDir:SubResourceWrapping = zipWrapper["META-INF"] as? SubResourceWrapping else {
			XCTAssertTrue(false)
			return
		}
		guard let _:DataWrapping = metaDir["container.xml"] as? DataWrapping else {
			XCTAssertTrue(false)
			return
		}
		for (_, file) in zipWrapper.subResources {
			if let dataWrapping = file as? DataWrapping {
				let musicData = dataWrapping.contents
				let asString = String(data:musicData, encoding:.utf8)!
				print(asString)
				
			}
			
		}
		
	}
	
	
	static var allTests = [
		("testMusicDirectories",testMusicDirectories),
		]
	
}
