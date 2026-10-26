import AemiProtobufSchema
import Testing

struct SchemaComparatorDepthTests {
    private func set(
        package: String = "p", messages: [MessageDescriptor] = [], enums: [EnumDescriptor] = []
    ) -> FileDescriptorSet {
        FileDescriptorSet(files: [FileDescriptor(name: "a.proto", package: package, messages: messages, enums: enums)])
    }

    private func field(_ name: String, _ number: Int32, _ type: FieldType = .int32, typeName: String = "")
        -> FieldDescriptor
    {
        FieldDescriptor(name: name, number: number, type: type, typeName: typeName)
    }

    @Test func `a nested message is compared under its qualified name`() {
        let before = set(messages: [
            MessageDescriptor(
                name: "Outer",
                nestedMessages: [
                    MessageDescriptor(name: "Inner", fields: [field("a", 1), field("b", 2)])
                ])
        ])
        let after = set(messages: [
            MessageDescriptor(
                name: "Outer", nestedMessages: [MessageDescriptor(name: "Inner", fields: [field("a", 1, .string)])])
        ])
        let kinds = SchemaComparator().compare(old: before, new: after).map(\.kind)
        #expect(
            kinds == [
                .fieldTypeIncompatible(message: "p.Outer.Inner", field: "a", oldType: .int32, newType: .string),
                .fieldRemoved(message: "p.Outer.Inner", field: "b", number: 2)
            ])
        let gone = set(messages: [MessageDescriptor(name: "Outer")])
        #expect(SchemaComparator().compare(old: before, new: gone).map(\.kind) == [.messageRemoved("p.Outer.Inner")])
    }

    @Test func `fields are matched by number so a rename is not a wire break`() {
        let before = set(messages: [MessageDescriptor(name: "M", fields: [field("old", 1)])])
        let after = set(messages: [MessageDescriptor(name: "M", fields: [field("new", 1)])])
        let changes = SchemaComparator().compare(old: before, new: after)
        #expect(changes.map(\.kind) == [.fieldRenamed(message: "p.M", number: 1, oldName: "old", newName: "new")])
        #expect(changes.allSatisfy { !$0.breaksTheWire })
        let removed = SchemaComparator().compare(old: before, new: set(messages: []))
        #expect(!removed.isEmpty && removed.allSatisfy { $0.breaksTheWire })
    }

    @Test func `reordering fields or messages is not a change`() {
        let a = MessageDescriptor(name: "A", fields: [field("x", 1), field("y", 2)])
        let b = MessageDescriptor(name: "B", fields: [field("z", 1)])
        let reordered = [b, MessageDescriptor(name: "A", fields: [field("y", 2), field("x", 1)])]
        #expect(SchemaComparator().compare(old: set(messages: [a, b]), new: set(messages: reordered)).isEmpty)
    }

    @Test
    func
        `a message field that names another type is reported and the same type under another spelling of the number is not`()
    {
        let before = set(messages: [MessageDescriptor(name: "M", fields: [field("m", 1, .message, typeName: ".p.A")])])
        let after = set(messages: [MessageDescriptor(name: "M", fields: [field("m", 1, .message, typeName: ".p.B")])])
        #expect(
            SchemaComparator().compare(old: before, new: after).map(\.kind) == [
                .fieldTypeNameChanged(message: "p.M", field: "m", oldTypeName: ".p.A", newTypeName: ".p.B")
            ])
        #expect(SchemaComparator().compare(old: before, new: before).isEmpty)
    }

    @Test func `enum changes are removal of the enum, of a value, and of a value's number`() {
        let before = set(enums: [
            EnumDescriptor(
                name: "E",
                values: [
                    EnumValueDescriptor(name: "A", number: 0), EnumValueDescriptor(name: "B", number: 1),
                    EnumValueDescriptor(name: "C", number: 2)
                ]),
            EnumDescriptor(name: "Gone", values: [EnumValueDescriptor(name: "X", number: 0)])
        ])
        let after = set(enums: [
            EnumDescriptor(
                name: "E",
                values: [
                    EnumValueDescriptor(name: "A", number: 0), EnumValueDescriptor(name: "B", number: 5),
                    EnumValueDescriptor(name: "D", number: 3)
                ])
        ])
        #expect(
            SchemaComparator().compare(old: before, new: after).map(\.kind) == [
                .enumValueRenumbered(enumName: "p.E", value: "B", oldNumber: 1, newNumber: 5),
                .enumValueRemoved(enumName: "p.E", value: "C", number: 2), .enumRemoved("p.Gone")
            ])
    }

    @Test(arguments: [
        (FieldType.int32, FieldType.uint64, true), (.int64, .bool, true), (.sint32, .sint64, true),
        (.sint32, .int32, false),
        (.fixed32, .sfixed32, true), (.fixed32, .fixed64, false), (.string, .bytes, true), (.message, .bytes, true),
        (.message, .string, false), (.double, .float, false), (.enum, .int32, true), (.double, .double, true)
    ])
    func `wire compatibility follows the protobuf compatibility classes`(
        old: FieldType, new: FieldType, compatible: Bool
    ) {
        let before = set(messages: [MessageDescriptor(name: "M", fields: [field("f", 1, old)])])
        let after = set(messages: [MessageDescriptor(name: "M", fields: [field("f", 1, new)])])
        let incompatible = SchemaComparator().compare(old: before, new: after)
            .contains {
                if case .fieldTypeIncompatible = $0.kind { return true }
                return false
            }
        #expect(incompatible == !compatible)
    }

    @Test func `the order of the result is the same on every run`() {
        let messages = (0 ..< 20).map { MessageDescriptor(name: "M\($0)", fields: [field("f", 1)]) }
        let runs = (0 ..< 5)
            .map { _ in SchemaComparator().compare(old: set(messages: messages), new: set()).map(\.kind) }
        #expect(Set(runs.map { "\($0)" }).count == 1)
        #expect(runs[0].count == 20)
    }
}
