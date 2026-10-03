// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MathPad",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MathPad", targets: ["MathPad"])
    ],
    targets: [
        .executableTarget(
            name: "MathPad",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
