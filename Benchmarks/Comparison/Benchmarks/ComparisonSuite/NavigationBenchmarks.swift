import AemiJSON
import AemiProtobuf
import AemiProtobufCore
import Benchmark
import ComparisonShared
import Foundation
import SwiftProtobuf

/// Untyped work: parse or index only, read two fields, and walk every value. No model type is built.
func registerNavigationBenchmarks() {
    for n in [2_000, 20_000] {
        let c = corpusCodecs(n)
        let tag = "n\(n)"

        Benchmark("parse/\(tag)/json.Foundation.JSONSerialization") { bm in
            for _ in bm.scaledIterations { blackHole(try JSONSerialization.jsonObject(with: c.jsonAemi)) }
        }
        Benchmark("parse/\(tag)/json.AemiJSON.tape") { bm in
            for _ in bm.scaledIterations { blackHole(try AemiJSON.parse(c.jsonAemi)) }
        }
        Benchmark("parse/\(tag)/pb.AemiProtobuf.countRecords") { bm in
            for _ in bm.scaledIterations { blackHole(try protobufCountRecords(c.protoFast)) }
        }

        Benchmark("read2/\(tag)/json.AemiJSON.tape") { bm in
            for _ in bm.scaledIterations {
                let root = try AemiJSON.parse(c.jsonAemi).root
                var acc = 0
                for user in root.arrayValue {
                    acc &+= user.id.intValue
                    acc &+= user.login.stringValue.utf8.count
                }
                blackHole(acc)
            }
        }
        Benchmark("read2/\(tag)/pb.AemiProtobuf.reader") { bm in
            for _ in bm.scaledIterations { blackHole(try protobufReadTwoFields(c.protoFast)) }
        }

        // swift-protobuf has no lazy view: reading anything means decoding the whole message first.
        Benchmark("read2/\(tag)/pb.SwiftProtobuf.decodeThenRead") { bm in
            for _ in bm.scaledIterations {
                let users = try Users(serializedBytes: c.protoFast)
                var acc = 0
                for u in users.users {
                    acc &+= Int(u.id)
                    acc &+= u.login.utf8.count
                }
                blackHole(acc)
            }
        }
        Benchmark("walk/\(tag)/pb.SwiftProtobuf.decodeThenWalk") { bm in
            for _ in bm.scaledIterations {
                let users = try Users(serializedBytes: c.protoFast)
                var sum = 0
                for u in users.users {
                    sum &+= Int(u.id) &+ Int(u.followers) &+ Int(u.following) &+ Int(u.isAdmin ? 1 : 0)
                    sum &+= Int(u.score) &+ u.login.utf8.count &+ u.name.utf8.count &+ u.email.utf8.count
                    for t in u.tags { sum &+= t.utf8.count }
                    sum &+= u.profile.bio.utf8.count &+ u.profile.company.utf8.count &+ u.profile.location.utf8.count
                    sum &+= Int(u.profile.publicRepos)
                }
                blackHole(sum)
            }
        }
        Benchmark("decode/\(tag)/pb.AemiProtobuf.fastFromData") { bm in
            let data = Data(c.protoFast)
            for _ in bm.scaledIterations { blackHole(try ProtobufDecoder().decode(ProtoUsers.self, from: data)) }
        }
        Benchmark("walk/\(tag)/json.AemiJSON.tape") { bm in
            for _ in bm.scaledIterations { blackHole(jsonWalk(try AemiJSON.parse(c.jsonAemi).root)) }
        }
        Benchmark("walk/\(tag)/pb.AemiProtobuf.reader") { bm in
            for _ in bm.scaledIterations { blackHole(try protobufWalk(c.protoFast)) }
        }
    }
}
