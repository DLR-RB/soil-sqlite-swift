import Soil

extension ValueType {

    /**
     The indicator to use for the type column to select the correct data column.

     This value matches ``ValueType.rawValue``, but was made explicit to not break databases when the library is updated.
     */
    var columnId: Int {
        switch self {
        case .null: 0
        case .data: 1
        case .integer: 2
        case .double: 3
        case .string: 4
        case .path: 5
        case .list: 6
        case .map: 7
        }
    }

    /**
     Create a type from the value present in the "type" column of a samples table
     */
    init?(columnId: Int) {
        switch columnId {
        case 0: self = .null
        case 1: self = .data
        case 2: self = .integer
        case 3: self = .double
        case 4: self = .string
        case 5: self = .path
        case 6: self = .list
        case 7: self = .map
        default: return nil
        }
    }
}
