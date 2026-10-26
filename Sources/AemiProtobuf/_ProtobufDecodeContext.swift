import AemiProtobufCore
import Foundation

/// What every decoder of one decode call shares: the bytes (a copy-on-write reference, never copied), the limits and the
/// caller's `userInfo`.
struct _ProtobufDecodeContext {
    let bytes: [UInt8]
    let limits: WireLimits
    let userInfo: [CodingUserInfoKey: Any]
}
