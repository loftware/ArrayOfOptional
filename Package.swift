// swift-tools-version:5.5
import PackageDescription

let auxilliaryFiles = ["README.md", "LICENSE"]
let package = Package(
  name: "LoftDataStructures_ArrayOfOptional",
  products: [
    .library(
      name: "LoftDataStructures_ArrayOfOptional",
      targets: ["LoftDataStructures_ArrayOfOptional"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/loftware/StandardLibraryProtocolChecks",
      from: "0.1.2"
    ),
    .package(
      url: "https://github.com/loftware/BitVector",
      from: "0.1.0"
    ),
  ],
  targets: [
    .target(
      name: "LoftDataStructures_ArrayOfOptional",
      dependencies: [
        .product(name: "LoftDataStructures_BitVector", package: "BitVector"),
      ],
      path: ".",
      exclude: auxilliaryFiles + ["Tests.swift"],
      sources: ["ArrayOfOptional.swift"]),

    .testTarget(
      name: "Test",
      dependencies: [
        "LoftDataStructures_ArrayOfOptional",
        .product(name: "LoftTest_StandardLibraryProtocolChecks",
                 package: "StandardLibraryProtocolChecks"),
      ],
      path: ".",
      exclude: auxilliaryFiles + ["ArrayOfOptional.swift"],
      sources: ["Tests.swift"]
    ),
  ]
)
