# SQLite storage for SOIL

This repository contains a SQLite database that implements data storage for [SOIL](https://gitlab.gsoc.dlr.de/gitlab/rb/mit/mcs/luna/soil/soil-documentation).

The main class `SQLiteStorage` implements the `Soil.Storage` protocol and can be used to store and retrieve arbitrary information.

## Notes

- The database supports all currently available `Value`s
- Timestamps are stored with millisecond precision
- The storage is fully thread-safe due to implementation as a Swift `actor`
- Values with the same timestamp for the same path will be overwritten via an `upsert` query.
- All operations (`receive`, `tree`, and `delete`) are implemented in a "best-effort" manner, meaning they will try to perform the requests partially, if database errors occur.
Samples may therefore be only partially saved or returned, and delete operations may not delete all data.
- Operations can be savely repeated in case of an error.
- `SQLiteStorage` can have an optional `SQLiteErrorDelegate` set (via `setDelegate()`), which will be called with all errors that occur during operation.

## Usage

To create a database, either open a SQLite connection yourself, or specify a file path:

```swift
let storage = SQLiteStorage(filePath: "/path/to/db.sqlite")
```

Set the error delegate, if needed:

```swift
let myDelegate: SQLiteErrorDelegate = ...
await storage.setDelegate(myDelegate)
```

## Internals

The database consists of two tables.

The `path` tables contains the currently existing tree as a list of parent-child relations,
which maps each node in the tree to a unique integer.
This mapping is dynamically created with new nodes,
and allows the samples stored in the `values` table to be associated with a single id (the integer of the path).
The `values` table then contains a sample for each row, consisting of the value and a timestamp,
as well as the id of the path to which it is associated.

### Path table

The `path` table stores integer keys for all paths, so that values can be efficiently stored in the `values` tables.

The table contains three columns:
- The `id` (`INTEGER`) assigns an integer to the path
- The `component` (`TEXT`) indicates the name of the current node
- The `parent` (`INTEGER`) id points to the row of the parent node

 The root node is not stored in the table, and has an `id` of `0`.
 Each top-level node will therefore have `parent = 0`,
 allowing the `parent` column to be declared `NOT NULL` (saves a bit of storage).
 SQLite does not allow the `id` column to be set to `0` since it's a `PRIMARY KEY`.
 SQLite will automatically assign `id`s starting from `1`.

This structure has multiple benefits:
- Paths of arbitrary length can be stored
- No need to introduce path component delimiters like `.` or `/`, which could potentially appear in path components and lead to errors
- Children of nodes can be efficiently queried (by searching for all entries with the same `parent`)

### Value table

The `values` tables contains the individual samples for all paths, stored one sample per row.
The row references the integer ids of the `path` table via

The table contains a separate column for each data type:
- `integer_value` (`INTEGER`)
- `double_value` (`DOUBLE`)
- `string_value` (`TEXT`)
- `data_value` (`BLOB`)

Notes:
- The SQLite interface used ([`SQLite.swift`](https://github.com/stephencelis/SQLite.swift)) works better with strongly typed queries (instead of `Any`).
- A `type` column specifies which value column to get, and identifies custom types that are stored as a blob in `data`.
The raw values are defined in `ValueType+Column.swift` and match the raw values of `Soil.ValueType`.
- The `timestamp` is stored as an `INTEGER`, containing the milliseconds since 1970.
This is more efficient than storing a date string, and the integer format allows more robust upsert queries.
- A separate `id` column is used as the primary key, to improve indexing efficiency.
- The stored entries are identified by the `path` (the id from the `paths` table) and the timestamp.
- The table is created without a `ROW ID`, since samples are indexed using `path` and `timestamp`.
- The primary key is a composite of `path` and `timestamp`, to ensure uniqueness of samples, and to speed up queries by path.
