import Foundation
import Soil
import SQLite

extension Path {

    /**
     Convert a path to data for storage.

     The path is stored using the UTF-8 representations of the components, each prefixed with a length indicator of 2 byte length.
     - Returns: The serialized data
     */
    func toBytes() -> [UInt8] {
        var result: [UInt8] = []

        for component in self {
            let utf8Bytes = component.data(using: .utf8)!
            let length = UInt16(utf8Bytes.count)

            // Encode length as 2 bytes (big-endian)
            result.append(UInt8((length >> 8) & 0xFF))
            result.append(UInt8(length & 0xFF))

            // Append string bytes
            result.append(contentsOf: utf8Bytes)
        }

        return result
    }

    /**
     Convert the path to data for storage.

     The path is stored using the UTF-8 representations of the components, each prefixed with a length indicator of 2 byte length.
     - Returns: The serialized data
     */
    func toData() -> Data {
        .init(toBytes())
    }

    /**
     Convert the path to a SQLite blob for storage.

     The path is stored using the UTF-8 representations of the components, each prefixed with a length indicator of 2 byte length.
     */
    var blob: Blob {
        .init(bytes: toBytes())
    }

    /**
     Create a path from serialized data.

     The path isassumed to be stored using the UTF-8 representations of the components, each prefixed with a length indicator of 2 byte length.
     - Parameter data: The serialized data to decode.
     */
    init?(data: Data) {
        var strings: [String] = []
        var index = 0

        while index + 2 <= data.count {
            // Read length (2 bytes, big-endian)
            let length = (Int(data[index]) << 8) | Int(data[index + 1])
            index += 2

            guard index + length <= data.count else {
                return nil // malformed data
            }

            let stringBytes = data[index..<index + length]
            index += length

            guard let string = String(bytes: stringBytes, encoding: .utf8) else {
                return nil
            }
            strings.append(string)
        }

        self = strings
    }
}
