// `@ProtoMessage` expands to code that names `WireReader`, `WireWriter`, `WireError` and `ZigZag`. Re-export the core so a file that
// imports only `AemiProtobuf` can use the macro.
@_exported public import AemiProtobufCore
