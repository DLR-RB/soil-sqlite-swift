import Foundation


extension Date {

    func isVeryClose(to other: Date) -> Bool {
        distance(to: other) < 0.001
    }
}
