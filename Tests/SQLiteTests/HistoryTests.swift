import Foundation
import Testing
import SQLite
import Soil
@testable import SoilSQLite

@Suite("History")
struct HistoryTests {

    @Test("All values")
    func getAllValues() throws {
        let db = try Connection(.inMemory)
        let storage = try SQLiteStorage(database: db)

        let path = ["a", "b", "c"]
        let date = Date()
        storage.receive(.integer(123), for: path, at: date)
        storage.receive(.integer(124), for: path, at: date.advanced(by: 1))
        storage.receive(.integer(125), for: path, at: date.advanced(by: 2))
        storage.receive(.integer(126), for: path, at: date.advanced(by: 3))

        do {
            let all = storage.samples(for: path)
            try #require(all.count == 4)
            #expect(all[0].value == .integer(126))
            #expect(all[1].value == .integer(125))
            #expect(all[2].value == .integer(124))
            #expect(all[3].value == .integer(123))
            #expect(all[0].timestamp.isVeryClose(to: date.advanced(by: 3)))
            #expect(all[1].timestamp.isVeryClose(to: date.advanced(by: 2)))
            #expect(all[2].timestamp.isVeryClose(to: date.advanced(by: 1)))
            #expect(all[3].timestamp.isVeryClose(to: date))
        }
    }

    @Test("Values in range")
    func  samplesInRange() throws {
        let db = try Connection(.inMemory)
        let storage = try SQLiteStorage(database: db)

        let path = ["a", "b", "c"]
        let date = Date()
        storage.receive(.integer(123), for: path, at: date)
        storage.receive(.integer(124), for: path, at: date.advanced(by: 1))
        storage.receive(.integer(125), for: path, at: date.advanced(by: 2))
        storage.receive(.integer(126), for: path, at: date.advanced(by: 3))

        do {
            let all = storage.samples(for: path, from: date.advanced(by: 2.5), to: date.advanced(by: 0.5))
            try #require(all.count == 2)
            #expect(all[0].value == .integer(125))
            #expect(all[1].value == .integer(124))
            #expect(all[0].timestamp.isVeryClose(to: date.advanced(by: 2)))
            #expect(all[1].timestamp.isVeryClose(to: date.advanced(by: 1)))
        }
    }

    @Test("Values with limit")
    func  samplesInRangeWithLimit() throws {
        let db = try Connection(.inMemory)
        let storage = try SQLiteStorage(database: db)

        let path = ["a", "b", "c"]
        let date = Date()
        storage.receive(.integer(123), for: path, at: date)
        storage.receive(.integer(124), for: path, at: date.advanced(by: 1))
        storage.receive(.integer(125), for: path, at: date.advanced(by: 2))
        storage.receive(.integer(126), for: path, at: date.advanced(by: 3))

        do {
            let all = storage.samples(
                for: path,
                from: date.advanced(by: 2.5),
                to: date.advanced(by: -0.5),
                limit: 2)
            try #require(all.count == 2)
            #expect(all[0].value == .integer(125))
            #expect(all[1].value == .integer(124))
            #expect(all[0].timestamp.isVeryClose(to: date.advanced(by: 2)))
            #expect(all[1].timestamp.isVeryClose(to: date.advanced(by: 1)))
        }
    }
}
