//
//  GunzipTests.swift
//  SwiftFoundationCompression
//
//  Created by Ben Spratling on 10/11/16.
//
//

import XCTest
@testable import SwiftFoundationCompression

class GunzipTests: XCTestCase {
	
	var sampleData:Data {
		return "The quick brown fox jumped over the lazy dog. But on the other hand, the lazy dog really isn't up for such an energetic exercise.".data(using: .utf8)!
	}
	
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

	func testGunzip() {
		let zipURL = fileInTestSource(named: "Package.swift", withExtension: "gz")
		let data = try! Data(contentsOf: zipURL)
		
		guard let decompressed = try? data.gunzip() else {
			XCTAssertTrue(false)
			return
		}
		
		let contents = String(data:decompressed, encoding:.utf8)
		print(contents)
		//gunzip
	}
	
	
	func testGzip() {
		guard let compressed:Data = try? sampleData.compressed(using: .gzip) else {
			XCTAssertTrue(false)
			return
		}
		guard let decompressed = try? compressed.decompressed(using: .gzip) else {
			XCTAssertTrue(false)
			return
		}
		XCTAssertEqual(sampleData, decompressed)
	}
	
	//test re-wrapping gzip
	func testRegzip() {
		let zipURL = fileInTestSource(named: "Package.swift", withExtension: "gz")
		let data = try! Data(contentsOf: zipURL)
		
		guard var gzipWrapper = try? GZipDataWrapping(compressedData:data) else {
			XCTAssertTrue(false)
			return
		}
		
		//change the file name
		gzipWrapper.lastPathComponent = "NewPackageFileName.swift"
		//now re-gzip it
		let rezippedData = gzipWrapper.serializedRepresentation
		//and write back to the test directory?
		var dir = zipURL.deletingLastPathComponent()
		dir.appendPathComponent("NewPackageFileName.swift.gz")
		let _ = try? rezippedData.write(to: dir)
		//now go manually gunzip it
	}
	
	
	static var allTests = [
		("testRegzip",testRegzip),
		("testGzip",testGzip),
		("testGunzip", testGunzip),
		]
	
}
