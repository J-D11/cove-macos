// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "QuietDeck",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "QuietDeck", targets: ["QuietDeck"])
    ],
    targets: [
        .executableTarget(
            name: "QuietDeck",
            path: "Sources/QuietDeck",
            exclude: ["Support"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("Vision")
            ]
        ),
        .testTarget(
            name: "QuietDeckTests",
            dependencies: ["QuietDeck"],
            path: "Tests/QuietDeckTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
