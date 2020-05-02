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
		let dir:URL = URL(fileURLWithPath: #file).deletingLastPathComponent()
		return dir.appendingPathComponent(named + "." + withExtension)
	}
	
	func testHeaderRead() {
		let zipURL = fileInTestSource(named: "Package.swift", withExtension: "gz")
		let data = try! Data(contentsOf: zipURL)
		
		guard let wrapper = try? GZipDataWrapping(compressedData:data) else { return }
		print(wrapper.header?.filename as Any)
	}
	
	
	static var allTests = [
		("testHeaderRead",testHeaderRead),
		]
	
}
