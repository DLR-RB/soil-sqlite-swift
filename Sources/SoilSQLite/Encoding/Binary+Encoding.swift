import Foundation
import BinaryCodable

/**
 An encoding for complex values using an efficient binary format.
 */
public struct BinaryEncoding: BlobEncoding {

    private let encoder = BinaryEncoder()

    private let decoder = BinaryDecoder()

    public init() {

    }

    public func encode<T>(_ value: T) throws -> Data where T : Encodable {
        try encoder.encode(value)
    }

    public func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable {
        try decoder.decode(type, from: data)
    }
}
