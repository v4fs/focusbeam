// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "focusbeam",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "focusbeam", path: "Sources/focusbeam")
    ]
)
