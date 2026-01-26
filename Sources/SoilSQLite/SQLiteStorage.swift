import Foundation
import SQLite
import Soil

/**
 A SQLite database to store values.

 The database uses three tables to store all data:
  - A `paths` table to map paths to integer ids
  - A `values` table to store all values based on their integer ids
 */
public final class SQLiteStorage: Storage {

    /// The database connection to retrieve and insert values
    private let database: Connection

    private let resolver: PathResolver

    private let values: ValueTable

    public weak var errorDelegate: SQLiteErrorDelegate?

    public convenience init(fileName: String) throws {
        let database = try Connection(fileName)
        try self.init(database: database)
    }

    public init(database: Connection) throws {
        self.database = database
        let resolver = try PathResolver(database: database)
        self.resolver = resolver
        self.values = try .init(database: database, paths: resolver.table)
    }

    // MARK: Storage

    public func receive(_ tree: Tree, for path: Path) {
        do {
            try database.transaction {
                try save(tree, for: path)
            }
        } catch {
            errorDelegate?.storage(didFail: .writeValues, for: path, with: error)
        }
    }

    public func tree(for path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?, limitPerNode: Int?) -> Tree {
        do {
            return try getTree(for: path, from: start, to: end, depth: depth, limitPerNode: limitPerNode)
        } catch {
            errorDelegate?.storage(didFail: .readValues, for: path, with: error)
        }
        return .init()
    }

    public func delete(path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?) {
        do {
            try database.transaction {
                try deleteSamples(at: path, from: start, to: end, depth: depth)
            }
        } catch {
            errorDelegate?.storage(didFail: .deleteValues, for: path, with: error)
        }
    }

    // MARK: Save value

    private func save(_ tree: Tree, for path: Path) throws {
        let node = try resolver.node(for: path) // Note: Uses a transaction
        try save(tree, for: node)
    }

    private func save(_ tree: Tree, for node: Node) throws {
        // First insert the samples at this node
        try values.upsert(samples: tree.samples, for: node.id)

        // Then traverse to the child nodes
        for (component, subTree) in tree.children {
            let childNode = try resolver.select(component, of: node)
            // Recurse into each child, until the tree is saved
            try save(subTree, for: childNode)
        }
    }

    // MARK: Get value

    private func getTree(for path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?, limitPerNode: Int?) throws -> Tree {
        guard let node = try resolver.existingNode(for: path) else { // Note: Uses a transaction
            return .init()
        }
        return try tree(for: node, from: start, to: end, depth: depth, limitPerNode: limitPerNode)
    }

    private func tree(for node: Node, from start: Timestamp?, to end: Timestamp?, depth: Int?, limitPerNode: Int?) throws -> Tree {
        let samples = try values.samples(for: node.id, from: start, to: end, limit: limitPerNode)

        if let depth, depth == 0 {
            return .init(samples: samples)
        }
        let newDepth = depth?.subtracting(1)
        let children: [PathComponent : Tree] = try resolver.children(for: node).mapValues { child in
            try tree(for: child, from: start, to: end, depth: newDepth, limitPerNode: limitPerNode)
        }
        return .init(samples: samples, children: children)
    }

    // MARK: Delete

    private func deleteSamples(at path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?) throws {
        guard let node = try resolver.existingNode(for: path) else { // Note: Uses a transaction
            // If the node doesn't exist, then there is no data to delete
            return
        }
        try delete(node: node, from: start, to: end, depth: depth)
    }

    private func delete(node: Node, from start: Timestamp?, to end: Timestamp?, depth: Int?) throws {
        try values.delete(for: node.id, from: start, to: end)

        let newDepth = depth?.subtracting(1)
        for child in try resolver.children(for: node).values {
            try delete(node: child, from: start, to: end, depth: newDepth)
        }
    }
}
