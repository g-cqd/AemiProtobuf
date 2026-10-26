import Benchmark
import ComparisonShared
import Foundation

/// Exits at setup if a codec fails its round trip: timing a codec that does not work would be meaningless.
func requireVerified(_ codecs: Codecs) -> Codecs {
    let verification = codecs.verify()
    guard verification.passed else {
        for finding in verification.findings {
            FileHandle.standardError.write(Data("n=\(codecs.n): \(finding)\n".utf8))
        }
        exit(1)
    }
    return codecs
}

func corpusCodecs(_ n: Int) -> Codecs {
    do { return requireVerified(try Codecs(count: n)) } catch {
        FileHandle.standardError.write(Data("n=\(n): setup threw \(error)\n".utf8))
        exit(1)
    }
}

let foundationEncoder = Foundation.JSONEncoder()
let foundationDecoder = Foundation.JSONDecoder()
