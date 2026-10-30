/// FieldMask paths between their declared form (`foo_bar.baz`) and their JSON form (`fooBar.baz`). A path that would not come
/// back the same is refused either way.
enum ProtoJSONPaths {
    /// `foo_bar` to `fooBar`; `nil` for an upper-case letter, or an underscore not before a lower-case letter.
    static func camel(_ path: String) -> String? {
        var result = ""
        var upper = false
        for character in path {
            if character == "_" {
                guard !upper else { return nil }
                upper = true
                continue
            }
            guard !character.isUppercase else { return nil }
            if upper {
                guard character.isLowercase else { return nil }
                result += character.uppercased()
                upper = false
            } else {
                result.append(character)
            }
        }
        return upper ? nil : result
    }

    /// `fooBar` to `foo_bar`; `nil` for a path with an underscore.
    static func snake(_ path: String) -> String? {
        var result = ""
        for character in path {
            guard character != "_" else { return nil }
            if character.isUppercase {
                result += "_" + character.lowercased()
            } else {
                result.append(character)
            }
        }
        return result
    }
}
