// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "soil-sqlite-swift",
    platforms: [
        .macOS(.v15),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "soil-sqlite-swift",
            targets: ["SoilSQLite"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-toolchain-sqlite.git", from: "1.0.7"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.16.0", traits: ["SQLiteSwiftCSQLite"]),
        .package(url: "https://gitlab.gsoc.dlr.de/gitlab/rb/mit/mcs/luna/soil/soil-core-swift.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "SoilSQLite",
            dependencies: [
                .product(name: "Soil", package: "soil-core-swift"),
                .product(name: "SQLite", package: "SQLite.swift"),
            ]
        ),
        .testTarget(
            name: "SQLiteTests",
            dependencies: [
                .product(name: "Soil", package: "soil-core-swift"),
                "SoilSQLite"
            ]
        ),
    ]
)
