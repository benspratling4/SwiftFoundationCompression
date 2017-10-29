// swift-tools-version:4.0
import PackageDescription
let package = Package(
	name: "SwiftFoundationCompression",
	products: [
		.library(
			name: "SwiftFoundationCompression",
			targets: ["SwiftFoundationCompression"]),
		],
	dependencies: [
		.package(url: "https://github.com/IBM-Swift/CZlib.git", from:"0.1.2"),
		.package(url: "https://github.com/benspratling4/SwiftPatterns.git", from:"2.1.0"),
	],
	targets:[
		.target(
			name: "SwiftFoundationCompression",
			dependencies: ["SwiftPatterns", "CZlib"]),
		.testTarget(
			name: "SwiftFoundationCompressionTests",
			dependencies: ["SwiftFoundationCompression"]),
		],
	swiftLanguageVersions:[4]
)

