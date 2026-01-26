import Foundation
import SQLite
import Soil

/**
 A table containing timestamped values, index by their path id.

 - The table contains a separate column for each data type (`INTEGER`, `DOUBLE`, `TEXT`, `BLOB`),
 because `SQLite.swift` works better with strongly typed queries (instead of `Any`).
 - A `type` column specifies which value column to get, and identifies custom types that are stored as a blob in `data`.
 - The timestamp is stored as a `DOUBLE`, containing the milliseconds since 1970 (more efficient than storing a date string)
 - A separate `id` column is used as the primary key, to improve indexing efficiency.
 - The stored entries are identified by the `path id` (from the `paths` table) and the timestamp.
 - An index is created to efficiently fetch the latest value of each path (based on `path` and `timestamp.DESC`).
 */
final class ValueTable {

    /// The database connection to retrieve and insert values
    private let database: Connection

    /// The definition of the table
    private let table = Table("values")

    /// The unique id of each entry
    private let id = Expression<Int>("id")

    /// The unique id of the path, from the path table
    private let path = Expression<Int>("path")

    /// The column storing the timestamps as milliseconds since 1970.
    private let timestamp = Expression<Int>("timestamp")

    /// The column containing the type identifier to select the correct value column
    private let type = Expression<Int>("type")

    /// The column storing integer values
    private let integer = Expression<Int?>("integer")

    /// The column storing double values
    private let double = Expression<Double?>("double")

    /// The column storing TEXT values
    private let string = Expression<String?>("string")

    /// The column storing BLOB values
    private let data = Expression<Data?>("data")

    /**
     Create an object to interact with the history table.
     - Parameter paths: The table storing the path to id mappings.
     */
    init(database: Connection, paths: PathTable) throws {
        self.database = database

        /*
        CREATE TABLE history (
            id INTEGER PRIMARY KEY,
            path INTEGER NOT NULL REFERENCES paths(id),
            timestamp INTEGER NOT NULL,
            type INTEGER NOT NULL,
            integer INTEGER,
            double DOUBLE,
            string TEXT,
            data BLOB
        );
        */
        let createQuery = table.create(ifNotExists: true) {
            $0.column(id, primaryKey: true)
            $0.column(path, references: paths.table, paths.id)
            $0.column(timestamp)
            $0.column(type)
            $0.column(integer)
            $0.column(double)
            $0.column(string)
            $0.column(data)
        }

        try database.run(createQuery)

        // Create an index to sort the entries by their timestamp (newest first),
        // so that current values queries and range queries are faster.
        // Note: The index is created with newest timestamps first, since
        // there is almost no performance difference for range queries,
        // but it's expected that most queries will be done in reverse timestamp order.
        let indexQuery = table.createIndex(path, timestamp.desc, ifNotExists: true)
        try database.run(indexQuery)
    }

    // MARK: Write

    func upsert(samples: [Sample], for pathId: Int) throws {
        guard !samples.isEmpty else {
            return
        }
        let upsert = """
            INSERT INTO history(path, timestamp, type, integer, double, string, data)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(path) DO UPDATE SET
                type = excluded.type,
                integer = excluded.integer,
                double = excluded.double,
                string = excluded.string,
                data = excluded.data
            WHERE excluded.timestamp == history.timestamp;
            """
        // Save all samples at the current node
        for sample in samples {
            try database.run(upsert,
                pathId,
                sample.timestamp.sqliteTimestamp,
                sample.value.type.rawValue,
                sample.value.integerValue,
                sample.value.doubleValue,
                sample.value.stringValue,
                sample.value.dataValue?.blob)
        }
    }

    /**
     Insert a new value for a path.
     - Parameter value: The value to insert.
     - Parameter pathId: The unique id of the path (from the `paths` table)
     - Parameter timestamp: The timestamp associated with the value..
     - Throws: The SQLite error of the failed insert.
     */
    func insert(value: Soil.Value, for pathId: Int, timestamp: Date) throws {
        let insertQuery = table.insert(
            path <- pathId,
            self.timestamp <- timestamp.sqliteTimestamp,
            setter(for: value)
        )

        try database.run(insertQuery)
    }

    /**
     Create a setter for the correct column based on the type of the value.
     */
    private func setter(for value: Soil.Value) -> Setter {
        switch value {
        case .integer(let value): integer <- value
        case .double(let value): double <- value
        case .string(let value): string <- value
        case .data(let value): data <- value
        case .path(let value): data <- value.toData()
        }
    }

    // MARK: Read

    /**
     Get the most value of a path at a point in time.

     This function will return the value before or at the provided date, regardless of the type.
     - Parameter pathId: The unique id of the path (from the `paths` table).
     - Parameter date: The point in time of interest (`nil` indicates the most recent timestamp)
     - Returns: The timestamped value at the given path, if present
     - Throws: A SQLite error, if the query fails.
     */
    func sample(for pathId: Int, beforeOrAt date: Date?) throws -> Sample? {
        guard let date else {
            return try latestSample(for: pathId)
        }
        let query = table
            .filter(path == pathId && timestamp <= date.sqliteTimestamp)
            .order(timestamp.desc)

        guard let row = try database.pluck(query) else {
            return nil
        }
        return sample(in: row)
    }

    /**
     Get the most recent value of a path.

     This function will return the latest value, regardless of the type.
     - Parameter pathId: The unique id of the path (from the `paths` table).
     - Returns: The most recent timestamped value at the given path, if present
     - Throws: A SQLite error, if the query fails.
     */
    private func latestSample(for pathId: Int) throws -> Sample? {
        let query = table
            .filter(path == pathId)
            .order(timestamp.desc)

        guard let row = try database.pluck(query) else {
            return nil
        }
        return sample(in: row)
    }

    private func column(for type: ValueType) -> Expressible {
        switch type {
        case .integer: integer
        case .double: double
        case .string: string
        case .data, .path: data
        }
    }

    private func sample(in row: Row) -> Sample? {
        guard let value = value(in: row) else {
            return nil
        }
        let timestamp = Date(sqliteTimestamp: row[self.timestamp])
        return .init(value: value, timestamp: timestamp)
    }

    /**
     Get the timestamped value in a row.

     If (by accident) multiple values are stored in the row then the first of (`integer`, `double`, `string`, `data`) is returned.
     */
    private func value(in row: Row) -> Soil.Value? {
        guard let type = ValueType(rawValue: row[type]) else {
            return nil
        }
        return value(in: row, of: type)
    }

    private func value(in row: Row, of type: ValueType) -> Soil.Value? {
        switch type {
        case .integer:
            return row[integer].map { .integer($0) }
        case .double:
            return row[double].map { .double($0) }
        case .string:
            return row[string].map { .string($0) }
        case .data:
            return row[data].map { .data($0) }
        case .path:
            guard let raw = row[data] else { return nil }
            guard let path = Path(data: raw) else { return nil }
            return .path(path)
        }
    }

    // MARK: History

    /**
     Provides the values in a given date range for a path, regardless of the value type.

     The start value is assumed to be later than the end value (backwards search).
     - Parameter pathId: The unique id of the path (from the `paths` table).
     - Parameter start: The start of the requested interval (exclusive, defaults to `nil`, meaning from end of time)
     - Parameter end: The end of the requested interval (inclusive, defaults to `nil`, meaning to beginning of time)
     - Parameter limit: The maximum number of values to return (defaults to `nil`, e.g. no limit)
     - Returns: The values in the range, sorted by most recent first. If a limit is set, then the `limit` newest values in the interval are returned.
     */
    func samples(for pathId: Int, from start: Date? = nil, to end: Date? = nil, limit: Int? = nil) throws -> [Sample] {
        let query = table
            .filter(path == pathId)
            .filter(timestamp, from: start, to: end)
            .limit(limit)
        return try database.prepare(query).compactMap(sample(in:))
    }

    func delete(for pathId: Int, from start: Date? = nil, to end: Date? = nil) throws {
        let query = table
            .filter(path == pathId)
            .filter(timestamp, from: start, to: end)
            .delete()
        try database.run(query)
    }
}

extension Date {

    var sqliteTimestamp: Int {
        Int((timeIntervalSince1970 * 1000).rounded())
    }

    init(sqliteTimestamp: Int) {
        self.init(timeIntervalSince1970: Double(sqliteTimestamp) / 1000)
    }
}