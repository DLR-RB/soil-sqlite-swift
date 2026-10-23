import Foundation

/**
 A generic encoding for complex values stored in blobs
 */
public protocol BlobEncoding {

    func encode<T: Encodable>(_ value: T) throws -> Data

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}
