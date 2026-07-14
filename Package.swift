// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "RcmdLite",
  platforms: [.macOS(.v13)],
  products: [
    .library(name: "RcmdCore", targets: ["RcmdCore"]),
    .library(name: "RcmdMac", targets: ["RcmdMac"]),
    .executable(name: "rcmd-lite", targets: ["RcmdApp"]),
    .executable(name: "rcmd-devtool", targets: ["RcmdDevTool"]),
  ],
  targets: [
    .target(name: "RcmdCore"),
    .target(name: "RcmdMac", dependencies: ["RcmdCore"]),
    .executableTarget(name: "RcmdApp", dependencies: ["RcmdCore", "RcmdMac"]),
    .executableTarget(name: "RcmdDevTool", dependencies: ["RcmdCore", "RcmdMac"]),
    .testTarget(name: "RcmdCoreTests", dependencies: ["RcmdCore"]),
    .testTarget(name: "RcmdMacTests", dependencies: ["RcmdCore", "RcmdMac"]),
  ]
)
