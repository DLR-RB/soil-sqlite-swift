import Foundation
import Soil

extension Value: @retroactive Encodable {

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(type.columnId)
        switch self {
        case .null: return
        case .integer(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .data(let value): try container.encode(value)
        case .path(let value): try container.encode(value)
        case .list(let value): try container.encode(value)
        case .map(let value): try container.encode(value)
        }
    }
}

extension Value: @retroactive Decodable {

    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let rawType = try container.decode(Int.self)
        guard let type = ValueType(columnId: rawType) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown value type \(rawType)")
        }
        switch type {
        case .null: self = .null
        case .integer:
            let value = try container.decode(Int.self)
            self = .integer(value)
        case .double:
            let value = try container.decode(Double.self)
            self = .double(value)
        case .string:
            let value = try container.decode(String.self)
            self = .string(value)
        case .data:
            let value = try container.decode(Data.self)
            self = .data(value)
        case .path:
            let value = try container.decode([String].self)
            self = .path(value)
        case .list:
            let value = try container.decode([Value].self)
            self = .list(value)
        case .map:
            let value = try container.decode([String: Value].self)
            self = .map(value)
        }
    }
}
