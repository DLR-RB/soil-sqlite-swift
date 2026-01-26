import Soil
import SoilSQLite

final class ErrorPrinter: SQLiteErrorDelegate {

    func storage(didFail operation: SQLiteOperation, for path: Path?, with error: any Error) {
        let path = path?.map { "'\($0)'" }.joined(separator: ", ") ?? "?"
        switch operation {
        case .readOrWritePathInformation:
            print("Failed to get info for (\(path)): \(error)")
        case .writeValues:
            print("Failed to save values for (\(path)): \(error)")
        case .readValues:
            print("Failed to read values for (\(path)): \(error)")
        case .deleteValues:
            print("Failed to delete values for (\(path)): \(error)")
        }
    }
}
