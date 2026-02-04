import Foundation
import SQLite
import Soil

/**
 A SQLite database to store values.

 The database uses three tables to store all data:
  - A `paths` table to map paths to integer ids
  - A `values` table to store all values based on their integer ids
 */
public actor SQLiteStorage {

    /// The database connection to retrieve and insert values
    private let database: Connection

    /// The interface to the path table to get integer ids for paths
    private let paths: PathResolver

    /// The interface to the values table
    private let values: ValueTable

    /// The delegate to receive SQLite errors
    private weak var delegate: SQLiteErrorDelegate?

    /**
     Create or open a SQLite database using a file name.
     - Parameter filePath: The path to the SQLite database file
     - Throws: Errors, if the database could not be connected or if the tables could not be created
     */
    public init(filePath: String) throws {
        let database = try Connection(filePath)
        try self.init(database: database)
    }

    /**
     Create a storage with an existing database connection.
     - Parameter database: The database handle
     - Throws: SQLite errors, if the tables could not be created
     */
    public init(database: Connection) throws {
        self.database = database
        let pathTable = try PathTable(database: database)
        self.paths = PathResolver(table: pathTable)
        self.values = try ValueTable(database: database, paths: pathTable)
    }

    /**
     Set the delegate to receive SQLite errors.
     - Parameter delegate: The delegate that should be informed about errors.
     */
    public func setDelegate(_ delegate: SQLiteErrorDelegate) {
        self.delegate = delegate
    }

    // MARK: Save value

    /**
     Actor-isolated function to store a tree.

     - Note: If some samples fail to insert, then the other samples will still be inserted
       in a "best-effort" manner. The error delegate will be called with information about failed operations.
     - Parameter tree: The tree to store
     - Parameter path: The path associated with the samples
     */
    private func store(_ tree: SampleTree, for path: Path) {
        // Run all operations of the request in a deferred transaction to increase speed
        // The transaction will only be started when an actual read/write occurs
        transaction(path: path) {
            guard let node = node(for: path) else {
                return
            }
            save(tree, for: node)
        }
    }

    /**
     Save a tree within a node.
     - Parameter tree: The tree to save
     - Parameter node: The node where the tree should be inserted.
     - Note: The samples are inserted in a "best-effort" manner, and the error delegate is called with all errors.
     */
    private func save(_ tree: SampleTree, for node: Node) {
        // First insert the samples at this node
        values.upsert(samples: tree.samples, for: node.id, delegate: delegate)

        // Then traverse to the child nodes
        for (component, subTree) in tree.children {
            do {
                let childNode = try paths.select(component, of: node)
                // Recurse into each child, until the tree is saved
                save(subTree, for: childNode)
            } catch {
                // We notify the delegate about the error, but we continue to save as much data as possible.
                // It can always be completed by saving the same data again due to the upsert logic.
                delegate?.storage(didFail: .readOrWritePathInformation, for: nil, id: node.id, with: error)
            }
        }
    }

    // MARK: Get value

    /**
     Get a tree in an interval for a node.
     - Parameter node: The node for which to get the tree.
     - Parameter start: The start of the requested interval (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the requested interval (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter depth: The number of levels below the path to include in the result
     - Parameter limitPerNode: The maximum number of values to return for each node of the tree (defaults to `nil`, e.g. no limit)
     - Returns: The tree with the given depth, limited to the maximum count per node, for the requested interval.
     - Note: The function may return an incomplete tree if the database has errors while fetching some samples.
       The error delegate will be called with all errors that occured, and all accessible samples and paths will be returned (best-effort).
     */
    private func tree(for node: Node, from start: Timestamp?, to end: Timestamp?, depth: Int?, limitPerNode: Int?) -> SampleTree {
        let samples = values.samples(for: node.id, from: start, to: end, limit: limitPerNode, delegate: delegate)

        // End the recursion if the depth is reached
        if depth == 0 {
            return .init(samples: samples)
        }

        // Ensure that all children are available to continue the recursion
        // We continue in a best-effort manner if the fetch failed
        fetchChildrenIfNeeded(for: node)

        let childDepth = depth - 1
        let children: [PathComponent : SampleTree] = node.children.mapValues { child in
            tree(for: child, from: start, to: end, depth: childDepth, limitPerNode: limitPerNode)
        }
        return .init(samples: samples, children: children)
    }

    // MARK: Delete

    /**
     Actor-isolated function to delete samples in an interval.
     - Parameter path: The path of the node targeted for the delete.
     - Parameter start: The start of the interval to delete (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the interval to delete (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter depth: The number of levels to include for deletion below the given path
     - Note: The deletion request may only be partially completed, if the deletion of samples produces errors.
       In this case the error delegate is informed about the errors, and the accessible data is deleted (best-effort).
       It is always possible to run the same request again to finish deletion of the remaining samples.
     */
    private func delete(path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?) {
        transaction(path: path) {
            guard let node = existingNode(for: path) else {
                // If the node doesn't exist, then there is no data to delete
                return
            }
            delete(node: node, from: start, to: end, depth: depth)
        }
    }

    /**
     Delete a tree based on a node.
     - Parameter node: The node targeted for the delete.
     - Parameter start: The start of the interval to delete (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the interval to delete (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter depth: The number of levels to include for deletion below the given path
     - Note: The deletion request may only be partially completed, if the deletion of samples produces errors.
       In this case the error delegate is informed about the errors, and the accessible data is deleted (best-effort).
       It is always possible to run the same request again to finish deletion of the remaining samples.
     */
    private func delete(node: Node, from start: Timestamp?, to end: Timestamp?, depth: Int?) {
        deleteSamples(at: node.id, from: start, to: end)

        // End the recursion if the depth is reached
        if depth == 0 {
            return
        }

        // Ensure that all children are available to continue the recursion
        // We continue in a best-effort manner if the fetch failed
        fetchChildrenIfNeeded(for: node)

        let childDepth = depth - 1
        for child in node.children.values {
            delete(node: child, from: start, to: end, depth: childDepth)
        }
    }

    /**
     Attempt to delete samples for a node in an interval
     - Parameter pathId: The integer id of the path
     - Parameter start: The start of the interval to delete (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the interval to delete (inclusive, defaults to `nil`, meaning to end of time)
     - Note: If the deletion fails, then the error delegate will be called.
     */
    private func deleteSamples(at pathId: Int, from start: Timestamp?, to end: Timestamp?) {
        do {
            try values.delete(for: pathId, from: start, to: end)
        } catch {
            delegate?.storage(didFail: .deleteSamples, for: nil, id: pathId, with: error)
        }
    }

    // MARK: Transaction

    /**
     Run a deferred transaction that produces some value.
     - Parameter path: The path associated with this transaction, to use when errors occur
     - Parameter block: A closure to run SQL statements within the transaction.
         The transaction will be committed when the block returns. The block
         must throw to roll the transaction back.
     - Returns: The result of the block, or `nil` if the transaction fails.
     - Note: If an error occurs within the transaction, then the error delegate is called, and `nil` is returned.
     */
    private func transaction<T>(path: Path? = nil, block: () -> T?) -> T? {
        do {
            return try database.transaction(block: block)
        } catch {
            delegate?.storage(didFail: .transaction, for: path, id: nil, with: error)
            return nil
        }
    }

    // MARK: Node operations

    /**
     Attempt to get the tree node for a path.
     - Parameter path: The path of the node to get.
     - Returns: The node, if it could be found or created, or `nil`, if an error occured
     - Note: The error delegate will be called if the node could not be fetched or created
     */
    private func node(for path: Path) -> Node? {
        do {
            return try paths.node(for: path)
        } catch {
            delegate?.storage(didFail: .readOrWritePathInformation, for: path, id: nil, with: error)
            return nil
        }
    }

    /**
     Get a node for a path, if it already exists.
     - Parameter path: The path of the node
     - Returns: The node, if it already exists, or `nil`.
     - Note: The error delegate is called if the fetch fails, and `nil` is returned.
     */
    private func existingNode(for path: Path) -> Node? {
        do {
            return try paths.existingNode(for: path)
        } catch {
            delegate?.storage(didFail: .readOrWritePathInformation, for: path, id: nil, with: error)
            return nil
        }
    }

    /**
     Fetch all children of a node for traversal.
     - Parameter node: The node to populate
     - Note: If the fetch fails, then the error delegate will be called
     */
    private func fetchChildrenIfNeeded(for node: Node) {
        // Populate the node if needed
        if node.hasAllChildrenCached {
            return
        }
        do {
            try paths.fetchAllChildren(for: node)
        } catch {
            // If we can't fetch the children, then we inform the delegate
            // We still continue the request, to at least return all possible data
            delegate?.storage(didFail: .readOrWritePathInformation, for: nil, id: node.id, with: error)
        }
    }
}

// MARK: Storage

extension SQLiteStorage: Storage {

    /**
     Receive a request to store a tree for a path.

     The provided tree can contain multiple samples for each node, and be of arbitrary depth.

     Existing samples (same path and timestamp) will be overwritten with the new value (upsert).
     - Parameter tree: The tree to store.
     - Parameter path: The path of the root node of the provided tree
     - Returns: A request handle, to optionally wait until the data is stored.
     - Note: The data may be only partially saved, if errors occur during insert.
       In this case the error delegate will be called with the errors, and all accessible samples will be saved (best-effort).
       It is always possible to store the same data again to complete the save.
     */
    @discardableResult
    public nonisolated func receive(_ tree: SampleTree, for path: Path) -> any Request {
        // Call the actor-isolated function in an async task to prevent data races
        AsyncRequest {
            await self.store(tree, for: path)
        }
    }

    /**
     Read a data tree for a given path within a given interval.

     This is the singular function to serve all data retrieval needs.

     The sort order of the result is:
     - ascending, if `end = nil`
     - descending, if `end != nil` and `start = nil`
     - ascending, if `start < end`
     - descending, if `start > end`

     The `limitPerNode` is applied in sort order.

     - Parameter path: The requested path.
     - Parameter start: The start of the requested interval (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the requested interval (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter depth: The number of levels below the path to include in the result
     - Parameter limitPerNode: The maximum number of values to return for each node of the tree (defaults to `nil`, e.g. no limit)
     - Returns: The tree with the given depth, limited to the maximum count per node, for the requested interval.
       The tree will be empty, if the database transaction fails, or if the node lookup for the path fails
     - Note: The function may return an incomplete tree if the database has errors while fetching some samples.
       The error delegate will be called with all errors that occured, and all accessible samples and paths will be returned (best-effort).
     */
    public func tree(for path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?, limitPerNode: Int?) async -> SampleTree {
        transaction(path: path) {
            guard let node = existingNode(for: path) else {
                // Return an empty tree if the node lookup fails
                return nil
            }
            return tree(for: node, from: start, to: end, depth: depth, limitPerNode: limitPerNode)
        } ?? SampleTree() // Return an empty tree if the transaction fails
    }

    /**
     Delete data from the storage.
     - Parameter path: The path of the node targeted for the delete.
     - Parameter start: The start of the interval to delete (exclusive, defaults to `nil`, meaning from beginning of time)
     - Parameter end: The end of the interval to delete (inclusive, defaults to `nil`, meaning to end of time)
     - Parameter depth: The number of levels to include for deletion below the given path
     - Returns: A request that can be used to wait until completion
     - Note: The deletion request may only be partially completed, if the deletion of samples produces errors.
       In this case the error delegate is informed about the errors, and the accessible data is deleted (best-effort).
       It is always possible to run the same request again to finish deletion of the remaining samples.
     */
    @discardableResult
    public nonisolated func delete(path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?) -> any Request {
        // Call the actor-isolated function in an async task to prevent data races
        AsyncRequest {
            await self.delete(path: path, from: start, to: end, depth: depth)
        }
    }
}
