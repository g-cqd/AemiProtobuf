import AemiJSON
import AemiProtobuf
import ComparisonShared
import Darwin
import Foundation
import SwiftProtobuf

// Peak and retained memory of ONE decode of 20,000 records, one process per codec.
//   ComparisonMemory prepare DIR        writes users.json and users.pb
//   ComparisonMemory run DIR CODEC      prints  codec, peak growth, retained growth   (bytes)
// The input is read from a file so the process starts small: the peak after the decode, minus the peak before it, is then the
// decode's own transient high-water mark, and the footprint difference is what the result keeps.

func footprint() -> Int {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    let status = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return status == KERN_SUCCESS ? Int(info.phys_footprint) : -1
}

func peak() -> Int {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    return Int(usage.ru_maxrss)  // bytes on Darwin
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else { fail("usage: ComparisonMemory prepare DIR | run DIR CODEC") }
let directory = URL(fileURLWithPath: arguments[2])

if arguments[1] == "prepare" {
    do {
        let codecs = try Codecs(count: 20_000)
        try codecs.jsonAemi.write(to: directory.appending(path: "users.json"))
        try Data(codecs.protoFast).write(to: directory.appending(path: "users.pb"))
    } catch { fail("prepare failed: \(error)") }
    exit(0)
}

guard arguments.count == 4 else { fail("usage: ComparisonMemory run DIR CODEC") }
let codec = arguments[3]
let json: Data
let pbData: Data
do {
    json = try Data(contentsOf: directory.appending(path: "users.json"))
    pbData = try Data(contentsOf: directory.appending(path: "users.pb"))
} catch { fail("run: cannot read the inputs: \(error)") }
let pb = [UInt8](pbData)

let peakBefore = peak()
let footprintBefore = footprint()
var retained: Any
do {
    switch codec {
        case "json.AemiJSON.codable": retained = try AemiJSON.JSONDecoder().decode([JSONUser].self, from: json)
        case "json.AemiJSON.macro": retained = try AemiJSON.JSONDecoder().decode([MacroJSONUser].self, from: json)
        case "json.AemiJSON.tape": retained = try AemiJSON.parse(json)
        case "json.Foundation": retained = try Foundation.JSONDecoder().decode([JSONUser].self, from: json)
        case "json.Foundation.JSONSerialization": retained = try JSONSerialization.jsonObject(with: json)
        case "pb.AemiProtobuf.fast": retained = try ProtobufDecoder().decode(ProtoUsers.self, fromBytes: pb)
        case "pb.AemiProtobuf.codable": retained = try ProtobufDecoder().decode(CodableProtoUsers.self, fromBytes: pb)
        case "pb.SwiftProtobuf": retained = try Users(serializedBytes: pb)
        default: fail("unknown codec \(codec)")
    }
} catch { fail("\(codec) failed: \(error)") }
let peakAfter = peak()
let footprintAfter = footprint()
withExtendedLifetime(retained) {}
print("\(codec)\t\(peakAfter - peakBefore)\t\(footprintAfter - footprintBefore)")
