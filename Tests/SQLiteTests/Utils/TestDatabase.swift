import SQLite
import SoilSQLite

func makeStorageAndDelegate() async throws -> (storage: SQLiteStorage, delegate: TestErrorDelegate) {
    let db = try Connection(.inMemory)
    let storage = try SQLiteStorage(database: db)
    let delegate = TestErrorDelegate()
    await storage.setDelegate(delegate)
    return (storage, delegate)
}