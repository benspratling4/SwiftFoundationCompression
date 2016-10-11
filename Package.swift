import PackageDescription
let package = Package(
	name: "SwiftFoundationCompression",
	targets: [],
	dependencies: [
		.Package(url: "https://github.com/IBM-Swift/CZlib.git", majorVersion: 0, minor: 1)
		,.Package(url: "https://github.com/benspratling4/SwiftPatterns.git", majorVersion: 1, minor: 0)
	]
)
