import Soil

/**
 A type that can be notified about errors occuring in a SQLite database
 */
public protocol SQLiteErrorDelegate: AnyObject, Sendable {

    /**
     Called by the storage implementation in case of an error
     - Parameter operation: The type of operation that failed
     - Parameter path: The path for which the operation failed
     - Parameter id: The integer path id for which the operation failed
     - Parameter error: The error that occured
     */
    func storage(didFail operation: SQLiteOperation, for path: Path?, id: Int?, with error: Error)
}
