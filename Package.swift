// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ActiveBrowser",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "ActiveBrowser", path: "Sources/ActiveBrowser")
    ]
)
