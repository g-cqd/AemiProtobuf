import AemiProtobufSchema
import Foundation
import Testing

struct SchemaComparatorTests {
    @Test func `identical schemas report zero breaking changes`() {
        let file = FileDescriptor(
            name: "test.proto",
            messages: [
                MessageDescriptor(
                    name: "Msg",
                    fields: [
                        FieldDescriptor(name: "id", number: 1, label: .optional, type: .int64),
                        FieldDescriptor(name: "name", number: 2, label: .optional, type: .string)
                    ]
                )
            ]
        )
        let s1 = FileDescriptorSet(files: [file])
        let s2 = FileDescriptorSet(files: [file])

        let comp = SchemaComparator()
        let changes = comp.compare(old: s1, new: s2)
        #expect(changes.isEmpty)
    }

    @Test func `wire compatible type change (int32 to int64) is not breaking`() {
        let f1 = FileDescriptor(
            messages: [
                MessageDescriptor(
                    name: "Msg", fields: [FieldDescriptor(name: "id", number: 1, label: .optional, type: .int32)])
            ])
        let f2 = FileDescriptor(
            messages: [
                MessageDescriptor(
                    name: "Msg", fields: [FieldDescriptor(name: "id", number: 1, label: .optional, type: .int64)])
            ])

        let comp = SchemaComparator()
        let changes = comp.compare(old: FileDescriptorSet(files: [f1]), new: FileDescriptorSet(files: [f2]))
        #expect(changes.isEmpty)
    }

    @Test func `incompatible type change (int32 to string) is reported as breaking`() {
        let f1 = FileDescriptor(
            messages: [
                MessageDescriptor(
                    name: "Msg", fields: [FieldDescriptor(name: "id", number: 1, label: .optional, type: .int32)])
            ])
        let f2 = FileDescriptor(
            messages: [
                MessageDescriptor(
                    name: "Msg", fields: [FieldDescriptor(name: "id", number: 1, label: .optional, type: .string)])
            ])

        let comp = SchemaComparator()
        let changes = comp.compare(old: FileDescriptorSet(files: [f1]), new: FileDescriptorSet(files: [f2]))
        #expect(changes.count == 1)
        #expect(
            changes.first?.kind
                == .fieldTypeIncompatible(message: "Msg", field: "id", oldType: .int32, newType: .string))
    }

    @Test func `renumbering a field is reported as breaking`() {
        let f1 = FileDescriptor(
            messages: [
                MessageDescriptor(
                    name: "Msg", fields: [FieldDescriptor(name: "id", number: 1, label: .optional, type: .int32)])
            ])
        let f2 = FileDescriptor(
            messages: [
                MessageDescriptor(
                    name: "Msg", fields: [FieldDescriptor(name: "id", number: 2, label: .optional, type: .int32)])
            ])

        let comp = SchemaComparator()
        let changes = comp.compare(old: FileDescriptorSet(files: [f1]), new: FileDescriptorSet(files: [f2]))
        #expect(changes.count == 1)
        #expect(changes.first?.kind == .fieldRenumbered(message: "Msg", field: "id", oldNumber: 1, newNumber: 2))
    }
}
