import Soil
@testable import SoilSQLite

extension PathResolver {

    /**
     - Note: This function is only used for testing.
     */
    func fullTree(for path: Path) throws -> Node {
        let node = try node(for: path)
        try loadTree(at: node)
        return node
    }

    /**
     Load the full tree of a node into the cache
     */
    private func loadTree(at node: Node) throws {
        for (_, child) in try children(for: node) {
            try loadTree(at: child)
        }
    }

    /**
     Return the id of a path from the cache, without updating the database.
     */
    func cachedPathId(for path: Path) -> Int? {
        var node = try! self.node(for: []) // Returns the root node
        for component in path {
            guard let child = node.children[component] else {
                // Sub-path not cached yet
                return nil
            }
            node = child
        }
        return node.id
    }

    /**
     Delete all values from the path cache.
     */
    func clearCache() {
        let root = try! self.node(for: []) // Returns the root node
        root.children.removeAll()
    }
}