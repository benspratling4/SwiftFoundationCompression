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
	
	func testHeaderRead() {
		let bundle:Bundle = Bundle(for:FileFormatTest.self)
		let zipURL = bundle.url(forResource: "Package.swift", withExtension: "gz")!
		let data = try! Data(contentsOf: zipURL)
		
		guard let wrapper = try? GZipDataWrapping(compressedData:data) else { return }
		print(wrapper.header?.filename)
	}
	
	
}
