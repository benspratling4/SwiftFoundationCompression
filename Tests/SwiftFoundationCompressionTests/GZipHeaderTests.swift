//
//  GZipHeaderTests.swift
//  SwiftFoundationCompression
//
//  Created by Ben Spratling on 10/11/16.
//
//

import Foundation
import XCTest
@testable import SwiftFoundationCompression


open class GZipHeaderTests : XCTestCase {
	
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
	
	func testHeaderRead() {
		let zipURL = fileInTestSource(named: "Package.swift", withExtension: "gz")
		let data = try! Data(contentsOf: zipURL)
		
		guard let wrapper = try? GZipDataWrapping(compressedData:data) else { return }
		print(wrapper.header?.filename)
	}
	
	
	static var allTests = [
		("testHeaderRead",testHeaderRead),
		]
	
}
