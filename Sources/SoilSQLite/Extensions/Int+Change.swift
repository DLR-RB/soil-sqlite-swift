
extension Int {

    /**
     Subtract the value and return the result.

     This function is available to simplify optional chaining:

     ```
     let some: Int? = other?.subtracting(1)
     ```

     This would otherwise be difficult to write.
     - Parameter value: The value to subtract.
     - Returns: The original integer value reduced by `value`.
     */
    func subtracting(_ value: Int) -> Int {
        self - value
    }

    /**
     Add the value and return the result.

     This function is available to simplify optional chaining:

     ```
     let some: Int? = other?.adding(1)
     ```

     This would otherwise be difficult to write.
     - Parameter value: The value to add.
     - Returns: The original integer value incremented by `value`.
     */
    func adding(_ value: Int) -> Int {
        self + value
    }
}
