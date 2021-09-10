// swift-tools-version:5.3
import PackageDescription
let package = Package(
	name: "SwiftFoundationCompression",
	products: [
		.library(
			name: "SwiftFoundationCompression",
			type:.dynamic,
			targets: ["SwiftFoundationCompression"]),
		],
	dependencies: [
		.package(url: "https://github.com/benspratling4/SwiftPatterns.git", from:"4.0.0"),
	],
	targets:[
		.target(
			name: "SwiftFoundationCompression",
			dependencies: ["SwiftPatterns"]),
		.testTarget(
			name: "SwiftFoundationCompressionTests",
			dependencies: ["SwiftFoundationCompression"]),
		],
	swiftLanguageVersions:[.v5]
)

