import XCTest
@testable import SwiftFoundationCompression

func testAssertDoesNotThrow(_ work:()throws->()) {
	do {
		try work()
	} catch {
		XCTAssertNil(error)
	}
}


class DeflateTests : XCTestCase {
	
	var sampleData:Data {
		return "The quick brown fox jumped over the lazy dog. But on the other hand, the lazy dog really isn't up for such an energetic exercise.".data(using: .utf8)!
	}
	
	func testCompression() {
		let compressed = try? sampleData.compressed()
		XCTAssertNotNil(compressed)
	}
	
	func testRoundTrip() {
		testAssertDoesNotThrow {
			let compressed = try sampleData.compressed()
			let decompressed:Data = try compressed.decompressed(using: .deflate)
			XCTAssertEqual(decompressed, sampleData)
		}
	}
	
}
