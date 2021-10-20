// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "PagerTabStrip",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v13)
  ],
  products: [
    .library(
      name: "PagerTabStrip",
      type: .static,
      targets: ["PagerTabStrip"]
    ),
  ],
  dependencies: [
    .package(
      name: "swift-standard-extensions",
      url: "https://github.com/edudo-inc/swift-standard-extensions",
      .branch("develop")
    )
  ],
  targets: [
    .target(
      name: "PagerTabStrip",
      dependencies: [
        .target(name: "PagerTabStripCore")
      ]
    ),
    .target(
      name: "PagerTabStripCore",
      dependencies: [
        .target(name: "FXPageControl"),
        .product(
          name: "CocoaExtensions",
          package: "swift-standard-extensions"
        )
      ]
    ),
    .target(
      name: "FXPageControl",
      publicHeadersPath: "include"
    )
  ]
)
