import AemiProtobufGenerator
import Foundation

// protoc-gen-aemi: protoc runs it with a CodeGeneratorRequest on standard input and reads the response from standard output.
//   protoc --plugin=protoc-gen-aemi --aemi_out=Sources/Generated --aemi_opt=visibility=public file.proto
let request = [UInt8](FileHandle.standardInput.readDataToEndOfFile())
FileHandle.standardOutput.write(Data(ProtocPlugin.run(request: request)))
