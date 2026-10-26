// swift-tools-version: 6.4
import CompilerPluginSupport
import PackageDescription

// Same strictness as the AemiJSON family: Swift 6 mode (complete concurrency checking), warnings as errors, and the
// upcoming features that tighten existentials and imports. No unsafe flags, so the library can be consumed through a
// version-pinned requirement.
let strictSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .treatAllWarnings(as: .error),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility")
]

// The engine reads attacker-controlled bytes, so every unsafe construct in it must be marked `unsafe`.
let kernelSettings: [SwiftSetting] = strictSettings + [.strictMemorySafety()]

// Benchmarks and their package are dev-only, gated like the siblings' tooling, so a consumer never resolves them.
let isDev = Context.environment["AEMIPROTOBUF_DEV"] != nil

let package = Package(
    name: "AemiProtobuf",
    // The floor matches AemiJSON and Aemi (`Synchronization`'s `Mutex`/`Atomic` need these releases). `Array.span` needs
    // macOS 26, so the core reads through a private `UnsafeRawBufferPointer` behind a `@safe` type (docs/adr/0002).
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .watchOS(.v11), .visionOS(.v2)],
    products: [
        // The umbrella package: ProtobufEncoder, ProtobufDecoder, Fast-path protocols, Data conveniences.
        .library(name: "AemiProtobuf", targets: ["AemiProtobuf"]),
        // Schema definition, descriptor parsing, wire validation, and breaking changes.
        .library(name: "AemiProtobufSchema", targets: ["AemiProtobufSchema"]),
        // The Foundation-free, swift-syntax-free wire engine: tags, varints, zig-zag, bounded reader and writer.
        .library(name: "AemiProtobufCore", targets: ["AemiProtobufCore"])
    ],
    dependencies: [
        // Shared byte kernels (`Varint`, `UTF8Validation` via `AemiKernels`). Pinned to the revision AemiJSON pins:
        // SwiftPM rejects one package identity at two revisions in a graph, so the siblings move together.
        .package(
            url: "https://github.com/Aemi-Studio/aemi.git", revision: "785c6b25cb3f4dc16ca2334fd69428fae4ee0b01"),
        // For `@ProtoMessage` only. The same wide range as AemiJSON, so a consumer of both resolves one swift-syntax.
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "603.0.0" ..< "605.0.0")
    ],
    targets: [
        .target(
            name: "AemiProtobufCore",
            dependencies: [
                .product(name: "AemiKernel", package: "aemi"),
                .product(name: "AemiKernels", package: "aemi")
            ],
            swiftSettings: kernelSettings),
        // The `@ProtoMessage` compiler plugin. It reads syntax and writes source; it links nothing into the library.
        .macro(
            name: "AemiProtobufMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax")
            ],
            swiftSettings: strictSettings),
        .target(
            name: "AemiProtobuf",
            dependencies: [
                "AemiProtobufCore", "AemiProtobufMacros",
                .product(name: "AemiKernel", package: "aemi")
            ],
            swiftSettings: strictSettings),
        .target(
            name: "AemiProtobufSchema",
            dependencies: [
                "AemiProtobufCore",
                .product(name: "AemiKernel", package: "aemi")
            ],
            swiftSettings: strictSettings),
        // The wire core's behaviour. `swift-mutation-testing` runs this target only (.swift-mutation-testing.yml).
        .testTarget(
            name: "AemiProtobufCoreTests",
            dependencies: ["AemiProtobufCore"],
            resources: [.copy("Resources")],
            swiftSettings: strictSettings),
        .testTarget(
            name: "AemiProtobufTests",
            dependencies: ["AemiProtobuf", "AemiProtobufCore"],
            resources: [.copy("Resources")],
            swiftSettings: strictSettings),
        .testTarget(
            name: "AemiProtobufMacrosTests",
            dependencies: [
                "AemiProtobufMacros",
                .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax")
            ],
            swiftSettings: strictSettings),
        .testTarget(
            name: "AemiProtobufSchemaTests",
            dependencies: ["AemiProtobufSchema", "AemiProtobufCore"],
            resources: [.copy("Resources")],
            swiftSettings: strictSettings),
        // The repository's own gates: structure, recursion, documents and hygiene. They read the working tree and run git, so they
        // are kept out of the target that is copied to a sandbox for mutation testing.
        .testTarget(name: "AemiProtobufRepositoryTests", swiftSettings: strictSettings)
    ]
)

if isDev {
    // ordo-one's package-benchmark: percentiles, malloc counts and CI thresholds. `AEMIPROTOBUF_DEV=1 swift package benchmark`.
    package.dependencies.append(.package(url: "https://github.com/ordo-one/benchmark", from: "1.38.0"))
    package.targets.append(
        .executableTarget(
            name: "AemiProtobufSuite",
            dependencies: [
                "AemiProtobufCore",
                "AemiProtobufSchema",
                "AemiProtobuf",
                .product(name: "Benchmark", package: "benchmark")
            ],
            path: "Benchmarks/AemiProtobufSuite",
            swiftSettings: strictSettings,
            plugins: [.plugin(name: "BenchmarkPlugin", package: "benchmark")]))
}
