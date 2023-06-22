// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swiftrobotToolkit",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "swiftrobotToolkit",
            targets: ["swiftrobotToolkit"]),
        .library(
            name: "cvToolkit",
            targets: ["cvToolkit"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "../swiftrobot", from: "0.1.0-alpha")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "cvToolkit",
            dependencies: ["swiftrobot"]),
        .target(
            name: "swiftrobotToolkit",
            dependencies: ["swiftrobot", "cvToolkit"]),
        .testTarget(
            name: "swiftrobotToolkitTests",
            dependencies: ["swiftrobotToolkit", "cvToolkit"]),
    ]
)
