/// An open enumeration, as proto3's are: `init(rawValue:)` never fails, so a number with no case survives in `unrecognized`.
enum OpenColor: RawRepresentable, Equatable, Codable {
    case red, green, blue
    case unrecognized(Int32)

    init(rawValue: Int32) {
        switch rawValue {
            case 0: self = .red
            case 1: self = .green
            case 2: self = .blue
            default: self = .unrecognized(rawValue)
        }
    }

    var rawValue: Int32 {
        switch self {
            case .red: 0
            case .green: 1
            case .blue: 2
            case .unrecognized(let value): value
        }
    }

    init(from decoder: any Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(Int32.self))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
