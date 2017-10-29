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
		#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
		let bundle:Bundle = Bundle(for:FileFormatTest.self)
		if let zipURL = bundle.url(forResource: named, withExtension: withExtension) {
			return zipURL
		}
			#endif
		let path = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
		return path.appendingPathComponent("Tests").appendingPathComponent("SwiftFoundationCompressionTests").appendingPathComponent(named + "." + withExtension)
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
		guard let container:DataWrapping = metaDir["container.xml"] as? DataWrapping else {
			XCTAssertTrue(false)
			return
		}
		for (key, file) in zipWrapper.subResources {
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
