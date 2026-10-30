/// The largest field number, as the schema module states it without importing the wire core's type everywhere.
enum FieldNumberLimit {
    static let maximum: UInt32 = 536_870_911
}
