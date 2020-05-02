//
//  WritingZipFiles.swift
//  SwiftFoundationCompression
//
//  Created by Ben Spratling on 10/14/16.
//
//

import XCTest
import SwiftPatterns
@testable import SwiftFoundationCompression

class WritingZipFiles: XCTestCase {
	
	func fileInTestSource(named:String, withExtension:String)->URL {
		let dir:URL = URL(fileURLWithPath: #file).deletingLastPathComponent()
		return dir.appendingPathComponent(named + "." + withExtension)
	}

	func testEmptyZipFile() {
		let eocd = EndOfCentralDirectoryForWriting(numberOfEntriesInTheCentralDirectory:0, sizeOfTheCentralDirectory:0, offsetOfTheBeginningOfTheCentralDirectoryWithRespectToTheStartingDiskNumber:0)
		var data:Data = Data()
		data.append(value:eocd)
		XCTAssertEqual(data.count, 22)
		#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
		let url = Bundle(for: WritingZipFiles.self).bundleURL
		let testZipURL = url.appendingPathComponent("test.zip")
		try! data.write(to: testZipURL)
		print("testZipURL.path")
		#endif
	}
	
	func testRoundTripZipFile() {
		
		let zipURL = fileInTestSource(named: "I Surrender All", withExtension: "mxl")
		let data = try! Data(contentsOf: zipURL)
		guard let zipWrapper = try? ZipDirectoryWrapping(zippedData:data) else {
			XCTAssertTrue(false)
			return
		}
		
		let zippedData = zipWrapper.serializedRepresentation
		XCTAssertGreaterThan(zippedData.count, 22)
		let newURL = zipURL.deletingLastPathComponent().appendingPathComponent("rezipped.zip")
		try! zippedData.write(to: newURL)
		
		//reopen
		guard let owner = try? ZippedDataOwner(data:zippedData) else {
			XCTAssertTrue(false)	//unable to create
			return
		}
		guard let firstEntry = owner.centralDirectoryEntries.filter({ (entry) -> Bool in
			return entry.fileName.hasSuffix("xml")
		}).last else {
			XCTAssertTrue(false)	//unable to create
			return
		}
		print("first entry = \(firstEntry)")
		guard let uncompressed:Data = try? owner.inflated(file:firstEntry) else {
			XCTAssertTrue(false)	//unable to create
			return
		}
		print("found data \(uncompressed)")
		guard let asString = String(data:uncompressed, encoding:.utf8) else {
			XCTAssertTrue(false)	//unable to create
			return
		}
		print("asString = \(asString)")
		
		
	}
	
	
	
	static var allTests = [
		("testRoundTripZipFile",testRoundTripZipFile),
		("testEmptyZipFile",testEmptyZipFile),
		]
}
