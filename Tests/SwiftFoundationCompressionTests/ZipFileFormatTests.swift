//
//  ZipFileFormatTests.swift
//  FoundationZip
//
//  Created by Ben Spratling on 10/9/16.
//
//

import Foundation
import XCTest
@testable import SwiftFoundationCompression


open class FileFormatTest : XCTestCase {
	
	open func testDiscoverAZipFile() {
		let bundle:Bundle = Bundle(for:FileFormatTest.self)
		let zipURL = bundle.url(forResource: "Package.swift", withExtension: "zip")!
		let data = try! Data(contentsOf: zipURL)
		let index = EndOfCentralDirectoryRecord.offsetToStart(in: data)
		XCTAssertEqual(index, 721)
	}
	
	open func testCreateEndOfCentralDirectoryRecord() {
		let bundle:Bundle = Bundle(for:FileFormatTest.self)
		let zipURL = bundle.url(forResource: "Package.swift", withExtension: "zip")!
		let data = try! Data(contentsOf: zipURL)
		guard let eocd = try? EndOfCentralDirectoryRecord(data:data) else {
			XCTAssertTrue(false)
			return
		}
		XCTAssertEqual(eocd.numberOfRecords, 3)
	}
	
	open func testAllCentralDirectoryEntries() {
		let bundle:Bundle = Bundle(for:FileFormatTest.self)
		let zipURL = bundle.url(forResource: "Package.swift", withExtension: "zip")!
		let data = try! Data(contentsOf: zipURL)
		guard let eocd = try? EndOfCentralDirectoryRecord(data:data) else {
			XCTAssertTrue(false)
			return
		}
		XCTAssertEqual(eocd.numberOfRecords, 3)
		
		var entries:[CentralDirectoryEntry] = []
		var entryOffset:Int = eocd.offsetToCentralDirectory
		for i in 0..<eocd.numberOfRecords {
			guard let entry = try? CentralDirectoryEntry(data:data, at:entryOffset) else {
				XCTAssertTrue(false)	//unable to create
				continue
			}
			print("found file = \(entry.fileName)")
			//uh... hmmmm....  check the entries somehow?
			entryOffset += entry.nextEntryIndex
		}
	}
	
	open func testZipOwnerCreation() {
		let bundle:Bundle = Bundle(for:FileFormatTest.self)
		let zipURL = bundle.url(forResource: "Package.swift", withExtension: "zip")!
		let data = try! Data(contentsOf: zipURL)
		
		guard let owner = try? ZippedDataOwner(data:data) else {
			XCTAssertTrue(false)	//unable to create
			return
		}
		//asert something about the file
		XCTAssertEqual(owner.centralDirectoryEntries.count, 3)
	}
	
	open func testDeflateMusicXML() {
		let bundle:Bundle = Bundle(for:FileFormatTest.self)
		let zipURL = bundle.url(forResource: "I Surrender All", withExtension: "mxl")!
		let data = try! Data(contentsOf: zipURL)
		guard let owner = try? ZippedDataOwner(data:data) else {
			XCTAssertTrue(false)	//unable to create
			return
		}
		guard let firstEntry = owner.centralDirectoryEntries.filter({ (entry) -> Bool in
			return entry.fileName.hasSuffix("xml") ?? false
		}).first else {
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
		//asert something about the file
		//XCTAssertEqual(owner.centralDirectoryEntries.count, 3)
	}
	
	open func testOpenMusicXML() {
		let bundle:Bundle = Bundle(for:FileFormatTest.self)
		let zipURL = bundle.url(forResource: "I Surrender All", withExtension: "mxl")!
		let data = try! Data(contentsOf: zipURL)
		guard let owner = try? ZippedDataOwner(data:data) else {
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
		//asert something about the file
		//XCTAssertEqual(owner.centralDirectoryEntries.count, 3)
	}
	
}
