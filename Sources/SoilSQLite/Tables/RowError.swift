import Soil

/// Errors occuring during row extraction
enum RowError: Error {

    /// A value is missing from the column indicated by the type.
    case missingValue(ValueType)

    /// A stored path/list/map could not be deserialized
    case invalidData(String)

    /// The row contains an unknown type
    case unknownType(Int)
}

extension RowError: CustomStringConvertible {

    var description: String {
        switch self {
        case .missingValue(let type): "Missing value for \(type)"
        case .invalidData(let error): "Invalid data stored, failed to decode: \(error)"
        case .unknownType(let raw): "Unknown type '\(raw)'"
        }
    }
}
