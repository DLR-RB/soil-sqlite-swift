import Soil

/**
 A node in the cache, representing a node in the stored tree
 */
class Node {

    /// The unique path id (from the `path` table)
    let id: Int

    /// The cached child nodes of this path
    var children: [PathComponent : Node] = [:]

    /// Indicate if `nodes` contains all stored children
    var hasAllChildrenCached: Bool

    /**
     Create a new node, indicating if it is fully fetched.
     - Parameter id: The unique id of the path for the node
     - Parameter isComplete: Indicate if the node has all children fetched.
     */
    init(id: Int, isComplete: Bool) {
        self.id = id
        self.hasAllChildrenCached = isComplete
    }
}