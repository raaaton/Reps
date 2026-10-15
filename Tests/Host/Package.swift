// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "SportHostTests",
  targets: [
    .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3"),
    .target(name: "SportCore", dependencies: ["CSQLite"]),
    .testTarget(name: "SportCoreTests", dependencies: ["SportCore", "CSQLite"]),
  ]
)
