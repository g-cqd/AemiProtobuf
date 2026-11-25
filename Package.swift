// swift-tools-version: 6.4
import CompilerPluginSupport
import PackageDescription

let strictSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .treatAllWarnings(as: .error),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility")
]

let kernelSettings: [SwiftSetting] = strictSettings + [.strictMemorySafety()]

let isDev = Context.environment["AEMIPROTOBUF_DEV"] != nil

let package = Package(
    name: "AemiProtobuf",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .watchOS(.v11), .visionOS(.v2)],
    products: [
        .library(name: "AemiProtobuf", targets: ["AemiProtobuf"]),
        .library(name: "AemiProtobufSchema", targets: ["AemiProtobufSchema"]),
        .library(name: "AemiProtobufJSON", targets: ["AemiProtobufJSON"]),
        .library(name: "AemiProtobufCore", targets: ["AemiProtobufCore"]),
        .library(name: "AemiProtobufGenerator", targets: ["AemiProtobufGenerator"]),
        .executable(name: "protoc-gen-aemi", targets: ["ProtocGenAemi"]),
        .executable(name: "aemi-proto-check", targets: ["aemi-proto-check"]),
        .plugin(name: "ProtobufCheck", targets: ["ProtobufCheck"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/Aemi-Studio/aemi.git",
            revision: "9e38d1bee60d5d65acffef4538c671b49860c6af"
        ),
        .package(url: "https://github.com/g-cqd/AemiJSON.git", revision: "9144b71be7714e15db293197b47edcc55ffde71b"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "603.0.0" ..< "605.0.0")
    ],
    targets: [
        .target(
            name: "AemiProtobufCore",
            dependencies: [
                .product(name: "AemiKernel", package: "aemi"),
                .product(name: "AemiKernels", package: "aemi")
            ],
            swiftSettings: kernelSettings
        ),
        .macro(
            name: "AemiProtobufMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax")
            ],
            swiftSettings: strictSettings
        ),
        .target(
            name: "AemiProtobuf",
            dependencies: [
                "AemiProtobufCore", "AemiProtobufMacros",
                .product(name: "AemiKernel", package: "aemi")
            ],
            swiftSettings: strictSettings
        ),
        .target(
            name: "AemiProtobufSchema",
            dependencies: [
                "AemiProtobufCore",
                .product(name: "AemiKernel", package: "aemi")
            ],
            swiftSettings: strictSettings
        ),
        .target(
            name: "AemiProtobufJSON",
            dependencies: [
                "AemiProtobufCore",
                "AemiProtobufSchema",
                .product(name: "AemiJSONCore", package: "AemiJSON"),
                .product(name: "AemiKernel", package: "aemi")
            ],
            swiftSettings: strictSettings
        ),
        .target(
            name: "AemiProtobufGenerator",
            dependencies: ["AemiProtobufSchema", "AemiProtobufCore"],
            swiftSettings: strictSettings
        ),
        .executableTarget(
            name: "ProtocGenAemi",
            dependencies: ["AemiProtobufGenerator"],
            swiftSettings: strictSettings
        ),
        .executableTarget(
            name: "aemi-proto-check",
            dependencies: ["AemiProtobufSchema"],
            path: "Sources/AemiProtoCheck",
            swiftSettings: strictSettings
        ),
        .plugin(
            name: "ProtobufCheck",
            capability: .command(
                intent: .custom(
                    verb: "protobuf-check",
                    description: "Lint a descriptor set, or compare two for breaking changes"
                )
            ),
            dependencies: ["aemi-proto-check"]
        ),
        .testTarget(
            name: "AemiProtobufGeneratorTests",
            dependencies: ["AemiProtobufGenerator", "AemiProtobufSchema"],
            resources: [.copy("Resources")],
            swiftSettings: strictSettings
        ),
        .testTarget(
            name: "AemiProtobufGeneratedTests",
            dependencies: ["AemiProtobuf"],
            resources: [.copy("Resources")],
            swiftSettings: strictSettings
        ),
        .testTarget(
            name: "AemiProtobufCoreTests",
            dependencies: ["AemiProtobufCore", .product(name: "AemiKernel", package: "aemi")],
            resources: [.copy("Resources")],
            swiftSettings: strictSettings
        ),
        .testTarget(
            name: "AemiProtobufTests",
            dependencies: ["AemiProtobuf", "AemiProtobufCore", "AemiProtobufSchema"],
            resources: [.copy("Resources")],
            swiftSettings: strictSettings
        ),
        .testTarget(
            name: "AemiProtobufMacrosTests",
            dependencies: [
                "AemiProtobufMacros",
                .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax")
            ],
            swiftSettings: strictSettings
        ),
        .testTarget(
            name: "AemiProtobufJSONTests",
            dependencies: ["AemiProtobufJSON", "AemiProtobufSchema", "AemiProtobufCore"],
            resources: [.copy("Resources")],
            swiftSettings: strictSettings
        ),
        .testTarget(
            name: "AemiProtobufSchemaTests",
            dependencies: ["AemiProtobufSchema", "AemiProtobufCore"],
            resources: [.copy("Resources")],
            swiftSettings: strictSettings
        ),
        .testTarget(name: "AemiProtobufRepositoryTests", swiftSettings: strictSettings)
    ]
)

if isDev {
    package.dependencies.append(.package(url: "https://github.com/ordo-one/benchmark", from: "1.38.0"))
    package.targets.append(
        .executableTarget(
            name: "AemiProtobufSuite",
            dependencies: [
                "AemiProtobufCore",
                "AemiProtobufSchema",
                "AemiProtobufJSON",
                "AemiProtobuf",
                .product(name: "Benchmark", package: "benchmark")
            ],
            path: "Benchmarks/AemiProtobufSuite",
            swiftSettings: strictSettings,
            plugins: [.plugin(name: "BenchmarkPlugin", package: "benchmark")]
        )
    )
}

if Context.environment["AEMIPROTOBUF_FUZZ"] != nil {
    package.targets.append(
        .executableTarget(
            name: "AemiProtobufFuzz",
            dependencies: ["AemiProtobuf", "AemiProtobufCore", "AemiProtobufSchema"],
            swiftSettings: strictSettings + [.unsafeFlags(["-parse-as-library", "-sanitize=fuzzer"])],
            linkerSettings: [.unsafeFlags(["-sanitize=fuzzer"])]
        )
    )
    package.products.append(.executable(name: "AemiProtobufFuzz", targets: ["AemiProtobufFuzz"]))
}

if Context.environment["AEMIPROTOBUF_NIO"] != nil {
    package.dependencies.append(.package(url: "https://github.com/apple/swift-nio.git", from: "2.104.0"))
    let nioCore: Target.Dependency = .product(name: "NIOCore", package: "swift-nio")
    package.products.append(.library(name: "AemiProtobufNIO", targets: ["AemiProtobufNIO"]))
    package.targets.append(
        .target(
            name: "AemiProtobufNIO",
            dependencies: ["AemiProtobuf", "AemiProtobufCore", nioCore],
            swiftSettings: strictSettings
        )
    )
    package.targets.append(
        .testTarget(
            name: "AemiProtobufNIOTests",
            dependencies: ["AemiProtobufNIO", nioCore, .product(name: "NIOEmbedded", package: "swift-nio")],
            swiftSettings: strictSettings
        )
    )
}
