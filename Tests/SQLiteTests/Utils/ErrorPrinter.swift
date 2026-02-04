import Soil
import SoilSQLite

final class ErrorPrinter: SQLiteErrorDelegate {

    func storage(didFail operation: SQLiteOperation, for path: Path?, id: Int?, with error: any Error) {
        let path = path?.map { "'\($0)'" }.joined(separator: ", ") ?? "?"
        let id = id.map { "\($0)" } ?? "?"
        switch operation {
        case .readOrWritePathInformation:
            print("Failed to get info for [\(path)] (\(id)): \(error)")
        case .writeSamples:
            print("Failed to save values for [\(path)] (\(id)): \(error)")
        case .readSamples:
            print("Failed to read values for [\(path)] (\(id)): \(error)")
        case .deleteSamples:
            print("Failed to delete values for [\(path)] (\(id)): \(error)")
        case .transaction:
            print("Failed to run transaction for  [\(path)] (\(id)): \(error)")
        }
    }
}
