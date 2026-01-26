import Soil

/**
 A type that can be notified about errors occuring in a SQLite database
 */
public protocol SQLiteErrorDelegate: AnyObject {

    /**
     Called by the storage implementation in case of an error
     */
    func storage(didFail operation: SQLiteOperation, for path: Path?, with error: Error)
}
