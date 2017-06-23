// swift-tools-version:3.1

import PackageDescription

let package = Package(
  name: "VertxEventBusExample",
  dependencies: [
    .Package(url: "https://github.com/IBM-Swift/Kitura.git", majorVersion: 1, minor: 7),
    .Package(url: "https://github.com/IBM-Swift/Kitura-StencilTemplateEngine.git", "1.8.1"),
    .Package(url: "../", "0.2.0")
  ])
