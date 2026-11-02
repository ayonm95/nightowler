// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Nightowler",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "NightowlerCore", targets: ["NightowlerCore"]),
        .executable(name: "nightowler", targets: ["NightowlerCLI"]),
        .executable(name: "NightowlerApp", targets: ["NightowlerApp"]),
        .executable(name: "NightowlerHelper", targets: ["NightowlerHelper"]),
        .executable(name: "NightowlerTestRunner", targets: ["NightowlerTestRunner"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NightowlerCore",
            dependencies: [],
            path: "Sources/NightowlerCore"
        ),
        .executableTarget(
            name: "NightowlerCLI",
            dependencies: ["NightowlerCore"],
            path: "Sources/NightowlerCLI"
        ),
        .executableTarget(
            name: "NightowlerApp",
            dependencies: ["NightowlerCore"],
            path: "Sources/NightowlerApp"
        ),
        .executableTarget(
            name: "NightowlerHelper",
            dependencies: ["NightowlerCore"],
            path: "Sources/NightowlerHelper"
        ),
        .executableTarget(
            name: "NightowlerTestRunner",
            dependencies: ["NightowlerCore"],
            path: "Sources/NightowlerTestRunner"
        )
    ]
)
