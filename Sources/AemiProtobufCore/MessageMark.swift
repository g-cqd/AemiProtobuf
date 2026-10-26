/// An open nested message in a ``WireWriter``: where to roll back to and where its length slot sits.
public struct MessageMark: Sendable {
    let rollback: Int
    let slot: Int
}
