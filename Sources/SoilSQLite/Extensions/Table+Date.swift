import Foundation
import SQLite

extension Date {

    /// The date expressed as milliseconds since 1970
    var millisecondsSince1970: Int {
        Int((timeIntervalSince1970 * 1000).rounded())
    }

    /**
     Create a date from a millisecond timestamp.
     - Parameter millisecondsSince1970: The number of milliseconds since 1.1.1970.
     */
    init(millisecondsSince1970: Int) {
        self.init(timeIntervalSince1970: Double(millisecondsSince1970) / 1000)
    }
}

extension Table {

    /**
     Filter a query with a date range on a column.

     The sort order of the result is:
     - ascending, if `end = nil`
     - descending, if `end != nil` and `start = nil`
     - ascending, if `start < end`
     - descending, if `start > end`

     - Parameter timestamp: The timestamp column
     - Parameter start: The start of the requested interval (exclusive, `nil` indicates beginning of time)
     - Parameter end: The end of the requested interval (inclusive, `nil` indicates end of time)
     - Returns: The modified table to use for queries
     */
    func filter(_ timestamp: SQLite.Expression<Int>, from start: Date?, to end: Date?) -> Table {
        guard let end = end?.millisecondsSince1970 else {
            guard let start = start?.millisecondsSince1970 else {
                // No interval given, sort ascending
                return order(timestamp.asc)
            }
            // Only start given, sort ascending
            return filter(timestamp > start).order(timestamp.asc)
        }

        guard let start = start?.millisecondsSince1970 else {
            // Only end given, sort descending
            return filter(timestamp <= end).order(timestamp.desc)
        }

        if start < end {
            // Return ascending
            return filter(timestamp > start && timestamp <= end).order(timestamp.asc)
        }
        // Return descending, switch range
        return filter(timestamp >= end && timestamp < start).order(timestamp.desc)
    }
}
