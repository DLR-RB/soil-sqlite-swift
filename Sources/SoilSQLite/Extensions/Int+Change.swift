
extension Optional where Wrapped == Int {

    /**
     Returns the result of subtracting an `Int` from an optional `Int`.
     - Parameter lhs: The optional integer on the left-hand side.
     - Parameter rhs: The integer to subtract from `lhs`.
     - Returns: The result of `lhs - rhs` if `lhs` is non-nil, otherwise `nil`.
     */
    static func - (lhs: Int?, rhs: Int) -> Int? {
        guard let lhs else { return nil }
        return lhs - rhs
    }
}