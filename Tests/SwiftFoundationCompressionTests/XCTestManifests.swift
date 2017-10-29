import XCTest

#if !os(macOS)
	public func allTests() -> [XCTestCaseEntry] {
		return [
			testCase(FileFormatTest.allTests),
			testCase(ZipDirectoryWrappingTests.allTests),
			testCase(WritingZipFiles.allTests),
			testCase(GunzipTests.allTests),
			testCase(GZipHeaderTests.allTests),
			testCase(DeflateTests.allTests),
		]
	}
#endif
