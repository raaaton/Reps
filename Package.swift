// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Reps",
  platforms: [
    .iOS("26.0")
  ],
  products: [
    // The main product remains Reps; its widget is an embedded app extension.
    .library(
      name: "Reps",
      targets: ["Sport"]
    ),
    .library(name: "RepsRestWidget", targets: ["SportRestWidget"]),
  ],
  // Internal UI/Live Activity module identities stay stable for existing system actions.
  targets: [
    .target(
      name: "Sport", dependencies: ["RepsCore", "SportLiveSupport"], path: "Sources/Reps",
      resources: [.process("Resources")]
    ),
    .target(
      name: "SportRestWidget", dependencies: ["SportLiveSupport"], path: "Sources/RepsRestWidget"),
    .target(name: "SportLiveSupport", dependencies: ["RepsCore"], path: "Sources/RepsLiveSupport"),
    .target(name: "RepsCore", dependencies: ["CSQLite"]),
    .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3"),
  ]
)
