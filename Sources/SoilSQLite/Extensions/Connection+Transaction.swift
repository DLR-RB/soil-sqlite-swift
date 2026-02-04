import SQLite

extension Connection {

    /**
     Runs a transaction with the given mode.

     - Note: Transactions cannot be nested. To nest transactions, see
       `savepoint()`, instead.

     - Parameter mode: The mode in which a transaction acquires a lock.

         Default: `.deferred`

     - Parameter block: A closure to run SQL statements within the transaction.
         The transaction will be committed when the block returns. The block
         must throw to roll the transaction back.
     - Returns: The result of the block.
     - Throws: `Result.Error`, and rethrows.
     */
    func transaction<T>(_ mode: TransactionMode = .deferred, block: () throws -> T) throws -> T {
        var t: T!
        try transaction {
            t = try block()
        }
        return t
    }
}