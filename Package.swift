// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QueensSolverApp",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "QueensSolverApp",
            targets: ["QueensSolverApp"]
        )
    ],
    targets: [
        .target(
            name: "QueensSolverApp",
            path: "QueensSolverApp"
        ),
        .testTarget(
            name: "QueensSolverAppTests",
            dependencies: ["QueensSolverApp"],
            path: "QueensSolverAppTests"
        )
    ]
)
