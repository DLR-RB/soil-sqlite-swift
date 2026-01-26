

/**
 An operation performed in a SQLite database
 */
public enum SQLiteOperation {

    /// Reading an interval from the values table
    case readValues

    /// Writing to the values table
    case writeValues

    /// Deleting from the values table
    case deleteValues

    /// Store or read information related to a path (e.g. identifiers)
    case readOrWritePathInformation

}
