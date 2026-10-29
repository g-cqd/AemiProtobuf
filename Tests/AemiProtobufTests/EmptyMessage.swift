import AemiProtobuf

/// A message that declares nothing, as `google.protobuf.Empty` does: it still reads, keeps unknown fields and writes them.
@ProtoMessage
struct EmptyMessage: Equatable {}
