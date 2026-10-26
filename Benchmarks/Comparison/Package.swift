// swift-tools-version: 6.4
import PackageDescription

// A dev-only package that puts AemiJSON and AemiProtobuf side by side on the same logical data. It lives apart from both
// manifests so neither gains a dependency on the other. Both packages must pin the same Aemi revision (SwiftPM rejects one
// identity at two revisions). Paths default to the sibling checkouts; override with AEMIJSON_PATH / AEMIPROTOBUF_PATH.
let env = Context.environment
let jsonPath = env["AEMIJSON_PATH"] ?? "../../../AemiJSON"
let protobufPath = env["AEMIPROTOBUF_PATH"] ?? "../.."

let settings: [SwiftSetting] = [.swiftLanguageMode(.v6), .treatAllWarnings(as: .error)]

let package = Package(
    name: "AemiComparison",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: jsonPath),
        .package(path: protobufPath),
        .package(url: "https://github.com/ordo-one/benchmark", from: "1.38.0"),
        // The incumbent. Its generated code (Sources/ComparisonShared/Generated) comes from comparison.proto through its own plugin.
        .package(url: "https://github.com/apple/swift-protobuf", exact: "1.39.0")
    ],
    targets: [
        // The record generator and both wire models, shared by the benchmarks and the size report.
        .target(
            name: "ComparisonShared",
            dependencies: [
                .product(name: "AemiJSON", package: "AemiJSON"),
                .product(name: "AemiProtobuf", package: "AemiProtobuf"),
                .product(name: "AemiProtobufCore", package: "AemiProtobuf"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf")
            ],
            // The generated file is not ours to hold to warnings-as-errors.
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .executableTarget(
            name: "ComparisonSuite",
            dependencies: [
                "ComparisonShared",
                .product(name: "AemiJSON", package: "AemiJSON"),
                .product(name: "AemiProtobuf", package: "AemiProtobuf"),
                .product(name: "AemiProtobufCore", package: "AemiProtobuf"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "Benchmark", package: "benchmark")
            ],
            path: "Benchmarks/ComparisonSuite",
            swiftSettings: settings,
            plugins: [.plugin(name: "BenchmarkPlugin", package: "benchmark")]),
        // Peak and retained memory of one decode per process, because a benchmark process has one peak for all its benchmarks.
        .executableTarget(
            name: "ComparisonMemory",
            dependencies: [
                "ComparisonShared",
                .product(name: "AemiJSON", package: "AemiJSON"),
                .product(name: "AemiProtobuf", package: "AemiProtobuf"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf")
            ],
            swiftSettings: settings),
        .executableTarget(
            name: "ComparisonSizes",
            dependencies: [
                "ComparisonShared",
                .product(name: "AemiJSON", package: "AemiJSON"),
                .product(name: "AemiProtobuf", package: "AemiProtobuf")
            ],
            swiftSettings: settings)
    ]
)
