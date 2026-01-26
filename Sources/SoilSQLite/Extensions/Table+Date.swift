import Foundation
import SQLite

extension Table {

    /**
     Filter a query with a date range on a column.

     If `start < end`, then the values will be switched automatically
     - Parameter timestamp: The timestamp column
     - Parameter start: The upper limit (exclusive)
     - Parameter end: The lower limit (inclusive)
     - Returns: The modified table to use for queries
     */
    func filter(_ timestamp: SQLite.Expression<Int>, from start: Date?, to end: Date?) -> Table {
        // TODO: Select correct order
        guard let start = start?.sqliteTimestamp else {
            guard let end else {
                return self
            }
            return filter(timestamp >= end.sqliteTimestamp)
        }
        guard let end = end?.sqliteTimestamp else {
            return filter(timestamp < start)
        }
        if start < end {
            // Correct invalid range by switching start and end
            return filter(timestamp >= start && timestamp < end)
        }
        return filter(timestamp >= end && timestamp < start)
    }
}
