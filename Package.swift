// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MouseGestures",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MouseGestures", targets: ["MouseGestures"])
    ],
    targets: [
        .executableTarget(
            name: "MouseGestures",
            path: "Sources/MouseGestures",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MouseGesturesTests",
            dependencies: ["MouseGestures"],
            path: "Tests/MouseGesturesTests"
        )
    ]
)
