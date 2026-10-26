import Std.Tactic.BVDecide

/-!
# Zig-zag

`Sources/AemiProtobufCore/ZigZag.swift`, over fixed-width bit vectors, the type Swift's `Int32` and `Int64` are.
The Swift code is `(v << 1) ^ (v >> 31)` (arithmetic shift) to encode and `(z >> 1) ^ -(z & 1)` to decode.
-/

namespace Wire

def zigzag32 (v : BitVec 32) : BitVec 32 := (v <<< 1) ^^^ (v.sshiftRight 31)
def unzigzag32 (z : BitVec 32) : BitVec 32 := (z >>> 1) ^^^ (0 - (z &&& 1))
def zigzag64 (v : BitVec 64) : BitVec 64 := (v <<< 1) ^^^ (v.sshiftRight 63)
def unzigzag64 (z : BitVec 64) : BitVec 64 := (z >>> 1) ^^^ (0 - (z &&& 1))

/-- Decoding undoes encoding for every 32-bit value. -/
theorem unzigzag32_zigzag32 (v : BitVec 32) : unzigzag32 (zigzag32 v) = v := by
  unfold unzigzag32 zigzag32; bv_decide

/-- Encoding undoes decoding: the map is a bijection, so no two `sint32` values share a wire value. -/
theorem zigzag32_unzigzag32 (z : BitVec 32) : zigzag32 (unzigzag32 z) = z := by
  unfold unzigzag32 zigzag32; bv_decide

theorem unzigzag64_zigzag64 (v : BitVec 64) : unzigzag64 (zigzag64 v) = v := by
  unfold unzigzag64 zigzag64; bv_decide

theorem zigzag64_unzigzag64 (z : BitVec 64) : zigzag64 (unzigzag64 z) = z := by
  unfold unzigzag64 zigzag64; bv_decide

/-- Small magnitudes stay small: a value in `-64 .. 63` encodes below 128, one varint byte. -/
theorem zigzag32_small (v : BitVec 32) (h1 : BitVec.sle (-64) v = true) (h2 : BitVec.sle v 63 = true) :
    (zigzag32 v).ult 128 = true := by
  unfold zigzag32; bv_decide

end Wire
