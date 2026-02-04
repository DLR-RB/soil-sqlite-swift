import Soil
import SoilSQLite

actor TestErrorDelegate: SQLiteErrorDelegate {

    var error: (operation: SQLiteOperation, path: Path?, id: Int?, error: any Error)?

    private func record(operation: SQLiteOperation, path: Path?, id: Int?, error: any Error) {
        self.error = (operation, path, id, error)
    }

    nonisolated func storage(didFail operation: SQLiteOperation, for path: Path?, id: Int?, with error: any Error) {
        Task {
            await self.record(operation: operation, path: path, id: id, error: error)
        }
    }
}
