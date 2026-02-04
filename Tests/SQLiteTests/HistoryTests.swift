import Foundation
import Testing
import SQLite
import Soil
import SoilSQLite

@Suite("History")
struct HistoryTests {

    @Test("All values")
    func getAllSamples() async throws {
        let (storage, delegate) = try await makeStorageAndDelegate()

        let path = ["a", "b", "c"]
        let date = Date()
        await storage.receive(.integer(123), for: path, at: date).wait()
        await storage.receive(.double(124), for: path, at: date.advanced(by: 1)).wait()
        await storage.receive(.string("125"), for: path, at: date.advanced(by: 2)).wait()
        await storage.receive(.data("126".data(using: .utf8)!), for: path, at: date.advanced(by: 3)).wait()
        await storage.receive(.path(["126"]), for: path, at: date.advanced(by: 4)).wait()
        await storage.receive(.null, for: path, at: date.advanced(by: 5)).wait()

        try await Task.sleep(for: .seconds(0.1))
        #expect(await delegate.error == nil)

        do {
            let all = await storage.samples(for: path)
            try #require(all.count == 6)
            // Samples are sorted in ascending order
            #expect(all[0].value == .integer(123))
            #expect(all[1].value == .double(124))
            #expect(all[2].value == .string("125"))
            #expect(all[3].value == .data("126".data(using: .utf8)!))
            #expect(all[4].value == .path(["126"]))
            #expect(all[5].value == .null)
            #expect(all[0].timestamp.isVeryClose(to: date.advanced(by: 0)))
            #expect(all[1].timestamp.isVeryClose(to: date.advanced(by: 1)))
            #expect(all[2].timestamp.isVeryClose(to: date.advanced(by: 2)))
            #expect(all[3].timestamp.isVeryClose(to: date.advanced(by: 3)))
            #expect(all[4].timestamp.isVeryClose(to: date.advanced(by: 4)))
            #expect(all[5].timestamp.isVeryClose(to: date.advanced(by: 5)))
        }

        #expect(await delegate.error == nil)
    }

    @Test("Samples in range")
    func  samplesInRange() async throws {
        let (storage, delegate) = try await makeStorageAndDelegate()

        let path = ["a", "b", "c"]
        let date = Date()
        await storage.receive(.integer(123), for: path, at: date).wait()
        await storage.receive(.integer(124), for: path, at: date.advanced(by: 1)).wait()
        await storage.receive(.integer(125), for: path, at: date.advanced(by: 2)).wait()
        await storage.receive(.integer(126), for: path, at: date.advanced(by: 3)).wait()

        #expect(await delegate.error == nil)

        do {
            let all = await storage.samples(for: path, from: date.advanced(by: 2.5), to: date.advanced(by: 0.5))
            try #require(all.count == 2)
            #expect(all[0].value == .integer(125))
            #expect(all[1].value == .integer(124))
            #expect(all[0].timestamp.isVeryClose(to: date.advanced(by: 2)))
            #expect(all[1].timestamp.isVeryClose(to: date.advanced(by: 1)))
        }

        #expect(await delegate.error == nil)
    }

    @Test("Samples with limit")
    func  samplesInRangeWithLimit() async throws {
        let (storage, delegate) = try await makeStorageAndDelegate()

        let path = ["a", "b", "c"]
        let date = Date()
        await storage.receive(.integer(123), for: path, at: date).wait()
        await storage.receive(.integer(124), for: path, at: date.advanced(by: 1)).wait()
        await storage.receive(.integer(125), for: path, at: date.advanced(by: 2)).wait()
        await storage.receive(.integer(126), for: path, at: date.advanced(by: 3)).wait()

        #expect(await delegate.error == nil)

        do {
            let all = await storage.samples(
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

        #expect(await delegate.error == nil)
    }
}
