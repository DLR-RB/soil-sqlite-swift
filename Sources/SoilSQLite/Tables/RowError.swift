import Soil

/// Errors occuring during row extraction
enum RowError: Error {

    /// A value is missing from the column indicated by the type.
    case missingValue(ValueType)

    /// A stored path could not be deserialized
    case invalidPath

    /// The row contains an unknown type
    case unknownType(Int)
}

extension RowError: CustomStringConvertible {

    var description: String {
        switch self {
        case .missingValue(let type): "Missing value for \(type)"
        case .invalidPath: "Invalid path"
        case .unknownType(let raw): "Unknown type '\(raw)'"
        }
    }
}
