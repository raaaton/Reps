// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Sport",
  platforms: [
    .iOS("26.0")
  ],
  products: [
    // The main product remains Sport; its widget is an embedded app extension.
    .library(
      name: "Sport",
      targets: ["Sport"]
    ),
    .library(name: "SportRestWidget", targets: ["SportRestWidget"]),
  ],
  targets: [
    .target(
      name: "Sport", dependencies: ["SportCore", "SportLiveSupport"],
      resources: [.process("Resources")]
    ),
    .target(name: "SportRestWidget", dependencies: ["SportLiveSupport"]),
    .target(name: "SportLiveSupport", dependencies: ["SportCore"]),
    .target(name: "SportCore", dependencies: ["CSQLite"]),
    .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3"),
  ]
)
