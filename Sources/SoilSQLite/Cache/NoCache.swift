import Foundation
import Soil

/**
 A cache implementation that does not cache any values.
 */
public final class NoCache: CurrentValueCache {

    public init() {

    }

    public func update(value: Sample?, for pathId: Int) {

    }

    public func value(for pathId: Int) -> Sample?? {
        nil
    }
}
