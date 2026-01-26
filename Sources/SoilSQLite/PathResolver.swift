import SQLite
import Soil

final class PathResolver {

    private let database: Connection

    let table: PathTable

    private let root: Node

    init(database: Connection) throws {
        self.database = database
        self.table = try .init(database: database)
        self.root = .init(id: table.rootId, isComplete: false)
    }

    /**
     Provide the id for a path to look up in the value and history tables.
     - Note: Uses a database transaction if inserting path components
     - Warning: Each queried path is created in the database and in the cache.
     Requesting many paths that might not have values in the database can potentially cause the cache and paths table to grow more than intended.
     This behaviour may be a denial-of-service attack vector.
     - Note: This function is only needed for testing
     */
    func pathId(for path: Path) throws -> Int {
        try node(for: path).id
    }

    /**
     Get a tree node, if it exists in the database.
     - Parameter path: The path of the node
     - Returns: The node, if it exists in the database.
     - Throws: SQLite errors, if path traversals could not be read from the path table
     - Note: This function uses a transaction to fetch path information if the path is not fully cached
     */
    func existingNode(for path: Path) throws -> Node? {
        // Traverse the cached paths as far to the leaf as possible.
        var (node, index) = cachedNode(for: path)

        guard index < path.count else {
            // The path was fully cached so return the id
            // The extra condition is needed to not start a database transaction unnecessarily.
            return node
        }

        // Further traverse the path, fetching new ids as needed
        var nodeDoesNotExist = false
        try database.transaction {
            while index < path.count {
                let component = path[index]
                guard let childId = try table.id(of: component, parent: node.id) else {
                    // We can't directly exit from the transaction,
                    // and it doesn't permit a return value
                    nodeDoesNotExist = true
                    break
                }
                // Create a new cache node, and advance
                let childNode = Node(id: childId, isComplete: false)
                node.nodes[component] = childNode
                node = childNode
                index += 1
            }
        }
        if nodeDoesNotExist {
            return nil
        }

        // Now the full path is traversed, and the leaf can be returned
        return node
    }

    /**
     Get the cached node for a path, or create it.
     - Parameter path: The path of the node
     - Returns: The node at the path
     - Throws: SQLite errors, if path traversals can't be written or read
     - Note: This function uses a transaction to fetch path information and to insert new paths if the path is not fully cached
     */
    func node(for path: Path) throws -> Node {
        // Traverse the cached paths as far to the leaf as possible.
        var (node, index) = cachedNode(for: path)

        guard index < path.count else {
            // The path was fully cached so return the id
            // The extra condition is needed to not start a database transaction unnecessarily.
            return node
        }

        // Further traverse the path, fetching or inserting new ids as needed
        try database.transaction {
            while index < path.count {
                let component = path[index]
                let (childId, created) = try getOrCreateId(for: component, parent: node.id)
                // Create a new cache node, and advance
                let childNode = Node(id: childId, isComplete: created)
                node.nodes[component] = childNode
                node = childNode
                index += 1
            }
        }
        // Now the full path is traversed, and the leaf id can be returned
        return node
    }

    private func getOrCreateId(for component: PathComponent, parent: Int) throws -> (id: Int, created: Bool) {
        if let id = try table.id(of: component, parent: parent) {
            return (id, false)
        }
        // Sub-path not saved yet, so insert it
        let id = try table.insert(component: component, parent: parent)
        return (id, true)
    }

    /**
     Traverse a node to a child via a path component, fetching data as needed.
     - Parameter component: The name of the child node
     - Parameter node: The parent node from which to select the child
     - Returns: The child node, created if it didn't exist
     */
    func select(_ component: PathComponent, of node: Node) throws -> Node {
        if let cached = node.nodes[component] {
            return cached
        }
        // We fetch all children, because we assume that we will need many of them
        // for this request.
        // This should be fast, since we only need to perform one query.
        if !node.hasAllChildrenCached {
            try fetchAllChildren(for: node)
            if let cached = node.nodes[component] {
                return cached
            }
        }
        // Child doesn't exist yet
        // We create it, and add it to the cache
        let childId = try table.insert(component: component, parent: node.id)
        let childNode = Node(id: childId, isComplete: true)
        node.nodes[component] = childNode
        // The node will remain completely cached, since we added the new child
        return childNode
    }

    /**
     Get a cached node for a path.
     - Parameter path: The path of the node to select
     - Returns: A tuple of the deepest node in the path, and the index within the path.
       If `index == path.count`, then the node at the full path is found
     */
    private func cachedNode(for path: Path) -> (node: Node, index: Int) {
        // The node represents the last cached path component
        var node = self.root
        // The index represents the first component of the path that is not cached
        var index = 0
        while index < path.count {
            let component = path[index]
            guard let child = node.nodes[component] else {
                // Sub-path not cached yet
                break
            }
            node = child
            index += 1
        }
        return (node, index)
    }

    // MARK: Tree traversal

    func children(for node: Node) throws -> [PathComponent: Node] {
        if node.hasAllChildrenCached {
            return node.nodes
        }
        try fetchAllChildren(for: node)
        return node.nodes
    }

    private func fetchAllChildren(for node: Node) throws {
        let all = try table.childNodes(of: node.id)
        for (component, id) in all {
            guard node.nodes[component] == nil else {
                continue
            }
            let child = Node(id: id, isComplete: false)
            node.nodes[component] = child
        }
        node.hasAllChildrenCached = true
    }
}