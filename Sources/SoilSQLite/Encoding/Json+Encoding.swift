import Foundation

public struct JsonEncoding: BlobEncoding {

    private let encoder = JSONEncoder()

    private let decoder = JSONDecoder()

    public init() {

    }

    public func encode<T>(_ value: T) throws -> Data where T : Encodable {
        try encoder.encode(value)
    }

    public func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable {
        try decoder.decode(type, from: data)
    }
}
