import Foundation
import SQLite
import Soil

/**
 A table containing timestamped values, index by their path id.

 - The table contains a separate column for each data type (`INTEGER`, `DOUBLE`, `TEXT`, `BLOB`),
 because `SQLite.swift` works better with strongly typed queries (instead of `Any`).
 - A `type` column specifies which value column to get, and identifies custom types that are stored as a blob in `data`.
 - The timestamp is stored as an `INTEGER`, containing the milliseconds since 1970 (more efficient than storing a date string)
 - The stored entries are identified by the `path id` (from the `paths` table) and the timestamp.
 - There is no separate ROW ID, since samples are indexed using `path` and `timestamp`
 - The primary key is a composite of `path` and `timestamp`, to ensure uniqueness of samples, and to speed up queries by path.
 - Complex values (Lists, Maps, Paths) are encoded as JSON and stored in the `data` column.
   The encoding consists of a list storing first the value type as an integer, followed by the encoding of the value.
   See the file `Value+Codable.swift` for more information.
 */
final class ValueTable {

    /// The database connection to retrieve and insert values
    private let database: SQLite.Connection

    /// The definition of the table
    private let table = Table("samples")

    /// The unique id of the path, from the path table
    private let path = Expression<Int>("path")

    /// The column storing the timestamps as milliseconds since 1970.
    private let timestamp = Expression<Int>("timestamp")

    /// The column containing the type identifier to select the correct value column
    private let type = Expression<Int>("type")

    /// The column storing BLOB values
    private let data = Expression<Data?>("data_value")

    /// The column storing integer values
    private let integer = Expression<Int?>("integer_value")

    /// The column storing double values
    private let double = Expression<Double?>("double_value")

    /// The column storing TEXT values
    private let string = Expression<String?>("string_value")

    /// The encoding for complex values
    private let encoding: BlobEncoding

    /**
     Create an object to interact with the values table.
     - Parameter database: The database connection
     - Parameter paths: The table storing the path to id mappings.
     - Parameter encoding: The encoding to use for complex values, defaults to JSON
     */
    init(database: SQLite.Connection, paths: PathTable, encoding: any BlobEncoding) throws {
        self.database = database
        self.encoding = encoding

        /*
        CREATE TABLE samples WITHOUT ROW ID (
            path INTEGER NOT NULL REFERENCES paths(id),
            timestamp INTEGER NOT NULL,
            type INTEGER NOT NULL,
            data_value BLOB,
            integer_value INTEGER,
            double_value DOUBLE,
            string_value TEXT,
            PRIMARY KEY(path, timestamp)
        );
        */
        let createQuery = table.create(ifNotExists: true, withoutRowid: true) {
            $0.column(path, references: paths.table, paths.id)
            $0.column(timestamp)
            $0.column(type)
            $0.column(data)
            $0.column(integer)
            $0.column(double)
            $0.column(string)
            $0.primaryKey(path, timestamp)
        }

        try database.run(createQuery)
    }

    // MARK: Write

    /**
     Insert the samples and replace existing values with the same timestamp.

     The samples are inserted individually, and failed inserts are reported to the delegate,
     without preventing other samples from being inserted.
     - Parameter samples: The samples to insert
     - Parameter pathId: The integer id of the path (from the paths table)
     - Parameter delegate: The delegate to inform about insert errors
     */
    func upsert(samples: [Sample], for pathId: Int, delegate: SQLiteErrorDelegate?) {
        guard !samples.isEmpty else {
            return
        }
        let upsert = """
            INSERT INTO samples (path, timestamp, type, data_value, integer_value, double_value, string_value)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(path, timestamp) DO UPDATE SET
                type = excluded.type,
                data_value = excluded.data_value,
                integer_value = excluded.integer_value,
                double_value = excluded.double_value,
                string_value = excluded.string_value
            WHERE excluded.timestamp = samples.timestamp;
            """
        // Save all samples at the current node
        for sample in samples {
            do {
                let values = try columns(for: sample.value)
                try database.run(upsert,
                    pathId,
                    sample.time.millisecondsSince1970,
                    values.type.columnId,
                    values.data,
                    values.integer,
                    values.double,
                    values.string)
            } catch {
                delegate?.storage(didFail: .writeSamples, for: nil, id: pathId, with: error)
            }
        }
    }

    // MARK: Read

    /**
     Provides the values in a given date range for a path, regardless of the value type.

     The start value is assumed to be later than the end value (backwards search).
     Corrupted samples are ignored, and the error delegate is informed.

     This function is called with a delegate to get individual errors for sample extraction without failing the whole request.
     - Parameter pathId: The unique id of the path (from the `paths` table).
     - Parameter start: The start of the requested interval (exclusive, defaults to `nil`, meaning from end of time)
     - Parameter end: The end of the requested interval (inclusive, defaults to `nil`, meaning to beginning of time)
     - Parameter limit: The maximum number of values to return (defaults to `nil`, e.g. no limit)
     - Parameter delegate: The delegate to inform about read errors
     - Returns: The values in the range, sorted by most recent first. If a limit is set, then the `limit` newest values in the interval are returned.
     */
    func samples(for pathId: Int, from start: Date? = nil, to end: Date? = nil, limit: Int? = nil, delegate: SQLiteErrorDelegate?) -> [Sample] {
        let query = table
            .filter(path == pathId)
            .filterAndOrder(timestamp, from: start, to: end)
            .limit(limit)
        let rows: AnySequence<Row>
        do {
            rows = try database.prepare(query)
        } catch {
            delegate?.storage(didFail: .readSamples, for: nil, id: pathId, with: error)
            return []
        }
        return rows.compactMap { row in
            do {
                return try sample(in: row)
            } catch {
                delegate?.storage(didFail: .readSamples, for: nil, id: pathId, with: error)
                return nil
            }
        }
    }

    /**
     Convert a row to a sample.
     - Parameter row: The row read from the table.
     - Returns: The extracted sample, if the data was valid.
     */
    private func sample(in row: Row) throws -> Sample {
        .init(value: try value(in: row),
              timestamp: Date(millisecondsSince1970: row[timestamp]))
    }

    /**
     Get the timestamped value in a row.

     Checks the type column to choose the correct value column.
     Only the column indicated by the type is selected.
     */
    private func value(in row: Row) throws -> Soil.Value {
        guard let type = ValueType(columnId: row[type]) else {
            throw RowError.unknownType(row[type])
        }
        return try value(in: row, of: type)
    }

    /**
     Extract a value from a row, by checking the type and selecting the correct column.

     If data is corrupted, then `nil` is returned (distinct from a `null` value)
     */
    private func value(in row: Row, of type: ValueType) throws(RowError) -> Soil.Value {
        switch type {
        case .null: return .null
        case .integer:
            guard let value = row[integer] else { throw RowError.missingValue(.integer) }
            return .integer(value)
        case .double:
            guard let value = row[double] else { throw RowError.missingValue(.double) }
            return .double(value)
        case .string:
            guard let value = row[string] else { throw RowError.missingValue(.string) }
            return .string(value)
        case .data:
            guard let value = row[data] else { throw RowError.missingValue(.data) }
            return .data(value)
        default:
            guard let raw = row[data] else { throw RowError.missingValue(type) }
            do {
                return try encoding.decode(Value.self, from: raw)
            } catch {
                throw RowError.invalidData(error.localizedDescription)
            }
        }
    }

    /**
     Convert a value to the column entries of the values table.
     Integers, Doubles and Strings, Data are put into their respective columns,
     while other types are encoded into data and also stored in the data column.
     - Parameter value: The value to convert
     - Returns: The column entries for the value
     */
    private func columns(for value: Soil.Value) throws -> (type: ValueType, integer: Int?, double: Double?, string: String?, data: Blob?) {
        switch value {
            case .null: return (.null, nil, nil, nil, nil)
            case .integer(let value): return (ValueType.integer, value, nil, nil, nil)
            case .double(let value): return (.double, nil, value, nil, nil)
            case .string(let value): return (.string, nil, nil, value, nil)
            case .data(let value): return (.data, nil, nil, nil, value.blob)
            default:
                do {
                    let data = try encoding.encode(value)
                    return (value.type, nil, nil, nil, data.blob)
                } catch {
                    throw RowError.invalidData(error.localizedDescription)
                }
        }
    }

    // MARK: Delete

    /**
     Delete the samples for a path in a given interval.
     - Parameter pathId: The interger id of the path (from the paths table).
     - Parameter start: The start of the interval to delete (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the interval to delete (inclusive, defaults to `nil`, meaning to end of time)
     */
    func delete(for pathId: Int, from start: Date? = nil, to end: Date? = nil) throws {
        let query = table
            .filter(path == pathId)
            .filter(timestamp, from: start, to: end)
            .delete()
        try database.run(query)
    }
}
