
/**
 An operation performed in a SQLite database
 */
public enum SQLiteOperation: Sendable {

    /// Reading an interval from the values table
    case readSamples

    /// Writing to the values table
    case writeSamples

    /// Deleting from the values table
    case deleteSamples

    /// Store or read information related to a path (e.g. identifiers)
    case readOrWritePathInformation

    /// Executing a transaction
    case transaction
}

extension SQLiteOperation: CustomStringConvertible {

    public var description: String {
        switch self {
        case .readSamples: "Reading from samples table"
        case .writeSamples: "Writing to samples table"
        case .deleteSamples: "Deleting from samples table"
        case .readOrWritePathInformation: "Read/write path table"
        case .transaction: "Executing a transaction"
        }
    }
}