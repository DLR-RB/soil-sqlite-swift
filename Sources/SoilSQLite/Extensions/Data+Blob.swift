import Foundation
import SQLite


extension Data {

    /// A SQLite BLOB created from the data.
    var blob: Blob {
        .init(bytes: Array(self))
    }
}
