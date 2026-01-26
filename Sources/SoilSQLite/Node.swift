import Soil

/**
 A node in the cache, representing a node in the stored tree
 */
class Node {

    /// The unique path id (from the `path` table)
    let id: Int

    /// The cached child nodes of this path
    var nodes: [PathComponent : Node] = [:]

    /// Indicate if `nodes` contains all stored children
    var hasAllChildrenCached: Bool

    init(id: Int, isComplete: Bool) {
        self.id = id
        self.hasAllChildrenCached = isComplete
    }
}