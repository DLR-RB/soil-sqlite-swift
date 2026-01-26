import Foundation
import Soil

public final class BasicCache {

    private var values: [Int: Sample?] = [:]

    public init() {

    }

    public var count: Int {
        values.count
    }

    public func updateIfNewer(value: Value, for pathId: Int, timestamp: Date) -> Bool {
        if let old = values[pathId], let old, timestamp > old.timestamp {
            return false
        }
        values[pathId] = .init(value: value, timestamp: timestamp)
        return true
    }
}

extension BasicCache: CurrentValueCache {

    public func update(value: Sample?, for pathId: Int) {
        values[pathId] = value
    }

    public func value(for pathId: Int) -> Sample?? {
        values[pathId]
    }
}
