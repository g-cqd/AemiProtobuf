/-!
# Varint (LEB128)

The wire format's unsigned varint over `Nat`: seven bits per byte, least significant group first, bit 7 set on
every byte but the last. `Sources/AemiProtobufCore/WireReader.swift` (`readVarint`) and `WireWriter.swift`
(`appendVarint`, `varintWidth`) implement it over `UInt64`.
-/

namespace Wire

/-- The bytes of `n`. Every byte but the last has its continuation bit (128) set. -/
def encode (n : Nat) : List Nat :=
  if h : n < 128 then [n] else (n % 128 + 128) :: encode (n / 128)
termination_by n
decreasing_by omega

/-- The value of a byte list read as a varint. A list that never ends reads as what it has. -/
def decode : List Nat → Nat
  | [] => 0
  | b :: rest => if b < 128 then b else (b - 128) + 128 * decode rest

/-- The length of the encoding, by the same recursion the writer's loop follows. -/
def width (n : Nat) : Nat :=
  if h : n < 128 then 1 else 1 + width (n / 128)
termination_by n
decreasing_by omega

/-- Reading what was written gives the value back, for every natural number. -/
theorem decode_encode (n : Nat) : decode (encode n) = n := by
  induction n using Nat.strongRecOn with
  | _ n ih =>
    rw [encode]
    split
    · rename_i h
      rw [decode]; simp [h]
    · rename_i h
      have h1 : n / 128 < n := by omega
      have h2 := ih (n / 128) h1
      have h3 : ¬ (n % 128 + 128 < 128) := by omega
      rw [decode]; simp only [h3, ite_false]; rw [h2]
      omega

/-- The encoding is as long as `width` says. -/
theorem length_encode (n : Nat) : (encode n).length = width n := by
  induction n using Nat.strongRecOn with
  | _ n ih =>
    rw [encode, width]
    split
    · rfl
    · rename_i h
      have h1 : n / 128 < n := by omega
      have h2 := ih (n / 128) h1
      rw [List.length_cons, h2]
      omega

/-- No byte exceeds 255, so each fits a `UInt8`. -/
theorem encode_bytes_lt (n : Nat) : ∀ b ∈ encode n, b < 256 := by
  induction n using Nat.strongRecOn with
  | _ n ih =>
    unfold encode
    split
    · intro b hb; simp at hb; omega
    · rename_i h
      have h1 : n / 128 < n := by omega
      intro b hb
      simp at hb
      rcases hb with hb | hb
      · omega
      · exact ih (n / 128) h1 b hb

/-- A value below 2^64 takes at most ten bytes: the bound `Varint.maxEncodedLength` and the reader's tenth-byte rule rest on. -/
theorem width_le_ten (n : Nat) (h : n < 2 ^ 64) : width n ≤ 10 := by
  have key : ∀ k : Nat, ∀ m : Nat, m < 128 ^ (k + 1) → width m ≤ k + 1 := by
    intro k
    induction k with
    | zero => intro m hm; rw [width]; simp at hm; simp [hm]
    | succ k ih =>
      intro m hm
      rw [width]
      split
      · omega
      · rename_i h
        have : m / 128 < 128 ^ (k + 1) := by
          rw [Nat.div_lt_iff_lt_mul (by omega)]
          rw [Nat.pow_succ 128 (k + 1)] at hm; exact hm
        have := ih (m / 128) this
        omega
  have h' : n < 128 ^ (9 + 1) := by
    have h2 : (2 : Nat) ^ 64 ≤ 128 ^ (9 + 1) := by decide
    exact Nat.lt_of_lt_of_le h h2
  have := key 9 n h'
  omega

end Wire
