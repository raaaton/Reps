// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "RepsHostTests",
  targets: [
    .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3"),
    .target(name: "RepsCore", dependencies: ["CSQLite"]),
    .testTarget(name: "RepsCoreTests", dependencies: ["RepsCore", "CSQLite"]),
  ]
)
