// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MedEditAI",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MedEditAI",
            path: "Sources/MedEditAIApp"
        ),
        .testTarget(
            name: "MedEditAITests",
            dependencies: ["MedEditAI"],
            path: "Tests/MedEditAITests"
        )
    ]
)
