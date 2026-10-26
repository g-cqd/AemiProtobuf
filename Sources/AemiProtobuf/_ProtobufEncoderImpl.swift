import AemiProtobufCore
import Foundation

/// The `Encoder` for one value. At the top level (`field == nil`) it can only make a keyed container, because a protobuf
/// message is a set of numbered fields. Below the top, `field` is the number the value is written under: a keyed container
/// opens a nested message, an unkeyed container writes a repeated field, a single-value container writes a scalar.
///
/// The creator calls ``finish()`` after `value.encode(to:)`: that closes the message and writes the packed run.
final class _ProtobufEncoderImpl: Encoder {
    let state: _ProtobufEncoderState
    let codingPath: [any CodingKey]
    let userInfo: [CodingUserInfoKey: Any]
    let field: FieldNumber?
    /// `true` writes a zero scalar too: the field has explicit presence, or is an element of a repeated field.
    let writesDefaults: Bool
    private var openMessage: MessageMark?
    private(set) var packed: [UInt8] = []
    private(set) var elementCount = 0

    init(
        state: _ProtobufEncoderState, codingPath: [any CodingKey], userInfo: [CodingUserInfoKey: Any],
        field: FieldNumber? = nil, writesDefaults: Bool = false
    ) {
        self.state = state
        self.codingPath = codingPath
        self.userInfo = userInfo
        self.field = field
        self.writesDefaults = writesDefaults
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        if let field, openMessage == nil {
            do throws(WireError) { openMessage = try state.writer.beginMessage(field: field) } catch {
                state.fail(ProtobufEncodingError.underlying(error))
            }
        }
        return KeyedEncodingContainer(_ProtobufKeyedEncodingContainer<Key>(encoder: self))
    }

    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        if field == nil {
            state.fail(ProtobufEncodingError.unsupported("a top-level value must be a message, not an array"))
        }
        return _ProtobufUnkeyedEncodingContainer(encoder: self)
    }

    func singleValueContainer() -> any SingleValueEncodingContainer {
        if field == nil {
            state.fail(ProtobufEncodingError.unsupported("a top-level value must be a message, not a scalar"))
        }
        return _ProtobufSingleValueEncodingContainer(encoder: self)
    }

    /// An encoder for the value of `key`'s field.
    func child(_ key: any CodingKey, field: FieldNumber, writesDefaults: Bool) -> _ProtobufEncoderImpl {
        _ProtobufEncoderImpl(
            state: state, codingPath: codingPath + [key], userInfo: userInfo, field: field,
            writesDefaults: writesDefaults)
    }

    /// Adds a scalar to the packed run of this repeated field.
    func appendPacked(_ scalar: _WireScalar) throws {
        try state.check()
        scalar.append(to: &packed)
        elementCount += 1
    }

    func noteElement() { elementCount += 1 }

    /// Closes the nested message this encoder opened and writes the packed run it collected.
    func finish() throws {
        try state.check()
        if let mark = openMessage {
            openMessage = nil
            try state.perform { w throws(WireError) in try w.endMessage(mark) }
        }
        if !packed.isEmpty, let field {
            let payload = packed
            packed = []
            try state.perform { w throws(WireError) in
                w.appendTag(field, .lengthDelimited)
                w.appendBytes(payload)
            }
        }
    }
}
