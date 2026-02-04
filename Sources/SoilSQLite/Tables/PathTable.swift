import Foundation
import SQLite
import Soil

/**
 The SQLite table storing the integer keys for all paths,
 so that values can be efficiently stored in the `values` table.

 The table contains three columns:
 - The `id` (`INTEGER`) assigns an integer to the path
 - The `component` (`TEXT`) indicates the name of the current node
 - The `parent` (`INTEGER`) id points to the row of the parent node

 The root node is not stored in the table, and has an `id` of `0`.
 Each top-level node will therefore have `parent = 0`,
 allowing the `parent` column to be declared `NOT NULL` (saves a bit of storage).
 SQLite does not allow the `id` column to be set to `0` since it's a `PRIMARY KEY`.
 SQLite will automatically assign `id`s starting from `1`.
 */
final class PathTable {

    /// The database connection to retrieve and insert values
    private let database: Connection

    /// The definition of the table
    let table = Table("path")

    /// The unique id of the path
    ///
    /// The id is used to identify values associated with this path
    let id = Expression<Int>("id")

    /**
     The path component added to the parent path.

     If the parent relation is none, then this component represents a top-level path.
     */
    private let component = Expression<String>("component")

    /**
     The unique id of the parent path.

     If the id is `0`, then the component represents a top-level path.
     Otherwise the node is located below the node with the same `id`.
     */
    private let parent = Expression<Int?>("parent")

    /**
     The id of the empty root path, to which all other paths are connected
     */
    let rootId: Int = 0

    /**
     Create a path table interface.

     This function will create the path table in the provided database, if it doesn't exist.
     It will also create the index to speed up searches.
     - Parameter database: The SQLite connection to use
     - Throws: SQLite errors if the table or index creation fails.
     */
    init(database: Connection) throws {
        self.database = database

        /*
        CREATE TABLE path (
            id INTEGER PRIMARY KEY,
            component TEXT NOT NULL,
            parent INTEGER,
            UNIQUE(parent, component)
        );
        */
        let createQuery = table.create(ifNotExists: true) {
            $0.column(id, primaryKey: true)
            $0.column(component)
            $0.column(parent, references: table, id)
            $0.unique(parent, component)
        }
        try database.run(createQuery)

        // Create an index to speed up searches for component ids
        let indexQuery = table.createIndex(parent, component, ifNotExists: true)
        try database.run(indexQuery)
    }

    /**
     Get the integer id of a component beneath a parent node.
     - Parameter component: The node name of the child
     - Parameter parent: The integer id of the parent node
     - Returns: The integer id of the child node, if present in the table.
     - Throws: SQLite errors from the query
     */
    func id(of component: PathComponent, parent: Int) throws -> Int? {
        let select = table
            .filter(self.parent == parent && self.component == component)
            .select(self.id)
        return try database.pluck(select)?[self.id]
    }

    /**
     Insert a child component for a parent path, and return the node id.
     - Parameter component: The node name to insert beneath the parent
     - Parameter parent: The integer id of the parent node
     - Returns: The integer id of the inserted child node
     - Throws: SQLite errors for the insert
     */
    func insert(component: PathComponent, parent: Int) throws -> Int {
        let query = table.insert(
            or: .ignore,
            self.component <- component,
            self.parent <- parent)
        let id = try database.run(query)
        return Int(id)
    }

    /**
     Provide all known children of a path.
     - Parameter pathId: The unique id of the path.
     - Returns: A dictionary containing the components under the path with their path ids.
     */
    func childNodes(of pathId: Int) throws -> [PathComponent : Int] {
        let query = table.filter(self.parent == pathId)
        return try database.prepare(query).reduce(into: [:]) { nodes, row in
            let component = row[component]
            nodes[component] = row[id]
        }
    }
}
