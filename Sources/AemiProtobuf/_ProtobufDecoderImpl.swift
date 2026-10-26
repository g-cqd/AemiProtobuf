import AemiProtobufCore
import Foundation

/// The `Decoder` for one value: a whole message (the top level), or the occurrences of one field. A field's keyed container
/// reads those occurrences as a nested message, its unkeyed container as a repeated field, its single-value container as a
/// scalar.
struct _ProtobufDecoderImpl: Decoder {
    enum Source {
        case message(ranges: [Range<Int>])
        case field(entries: [_ProtobufFieldEntry])
    }

    let context: _ProtobufDecodeContext
    let source: Source
    /// How many messages deep this decoder's message (or, for a field, its enclosing message) is.
    let depth: Int
    let codingPath: [any CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { context.userInfo }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        let index: _ProtobufMessageIndex
        let messageDepth: Int
        switch source {
            case .message(let ranges):
                messageDepth = depth
                index = try buildIndex(ranges: ranges, depth: messageDepth)
            case .field(let entries):
                // A field read as a message is one level deeper than the message that holds it.
                messageDepth = depth + 1
                var ranges: [Range<Int>] = []
                ranges.reserveCapacity(entries.count)
                for entry in entries {
                    guard entry.wireType == .lengthDelimited else {
                        throw DecodingError.typeMismatch(
                            Key.self,
                            .init(
                                codingPath: codingPath,
                                debugDescription: "a message is length-delimited, found \(entry.wireType)"))
                    }
                    ranges.append(entry.range)
                }
                index = try buildIndex(ranges: ranges, depth: messageDepth)
        }
        let nested = _ProtobufDecoderImpl(
            context: context, source: source, depth: messageDepth, codingPath: codingPath)
        return KeyedDecodingContainer(_ProtobufKeyedDecodingContainer<Key>(decoder: nested, index: index))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        guard case .field(let entries) = source else {
            throw ProtobufDecodingError.unsupported("a top-level value must be a message, not an array")
        }
        return _ProtobufUnkeyedDecodingContainer(decoder: self, entries: entries)
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        guard case .field(let entries) = source else {
            throw ProtobufDecodingError.unsupported("a top-level value must be a message, not a scalar")
        }
        return _ProtobufSingleValueDecodingContainer(decoder: self, entry: entries.last)
    }

    private func buildIndex(ranges: [Range<Int>], depth: Int) throws -> _ProtobufMessageIndex {
        do throws(WireError) {
            return try _ProtobufMessageIndex(bytes: context.bytes, ranges: ranges, depth: depth, limits: context.limits)
        } catch {
            throw ProtobufDecodingError.underlying(error)
        }
    }

    /// A decoder for the occurrences of `key`'s field, one message level below this one.
    func field(_ key: any CodingKey, entries: [_ProtobufFieldEntry]) -> _ProtobufDecoderImpl {
        _ProtobufDecoderImpl(
            context: context, source: .field(entries: entries), depth: depth, codingPath: codingPath + [key])
    }
}
