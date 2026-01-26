import Foundation
import Soil

/**
 A type providing temporary storage for current values
 */
public protocol CurrentValueCache {

    /**
     Store the value for a path.
     - Parameter value: The timestamped value for the path. `nil`, if the database contains no value for the path.
     - Parameter pathId: The unique id of the path.
     */
    func update(value: Sample?, for pathId: Int)

    /**
     Return the value for a path id.

     If the cache has no information about the path, then it should return `.none`.
     If the no value is available for the path, then return `.some(.none)`.
     */
    func value(for pathId: Int) -> Sample??
}

extension CurrentValueCache {

    /**
     Store the value for a path.
     - Parameter value: The value for the path.
     - Parameter pathId: The unique id of the path.
     - Parameter timestamp: The timestamp of the value
     */
    public func update(value: Value, for pathId: Int, at timestamp: Date) {
        update(value: .init(value: value, timestamp: timestamp), for: pathId)
    }
}
