// swift-tools-version: 6.4
import PackageDescription

// The conformance testee (roadmap 0011): its own package, as Benchmarks/Comparison is, so no library depends on it. Its
// sources are what protoc-gen-aemi writes for the conformance messages, and their descriptor set for the JSON tests
// (Scripts/conformance.sh regenerates both).
let package = Package(
    name: "AemiProtobufConformance",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: "..")],
    targets: [
        .executableTarget(
            name: "AemiConformanceTestee",
            dependencies: [
                .product(name: "AemiProtobuf", package: "AemiProtobuf"),
                .product(name: "AemiProtobufSchema", package: "AemiProtobuf"),
                .product(name: "AemiProtobufJSON", package: "AemiProtobuf")
            ],
            swiftSettings: [.swiftLanguageMode(.v6), .treatAllWarnings(as: .error)])
    ]
)
