import PackageDescription

let package = Package(
        name: "VertxEventBus",
        dependencies: [
          .Package(url: "https://github.com/IBM-Swift/BlueSocket.git", majorVersion: 0, minor: 5),
          .Package(url: "https://github.com/IBM-Swift/SwiftyJSON.git", majorVersion: 8, minor: 0)
        ])
