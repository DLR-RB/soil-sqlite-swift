import Foundation
import Testing
import SQLite
import Soil
import SoilSQLite

@Suite("Deletion")
struct DeletionTests {

    @Test("All samples")
    func deleteAllSamples() async throws {
        let (storage, delegate) = try await makeStorageAndDelegate()

        let path = ["a", "b", "c"]

        do {
            let now = Timestamp.current()

            await storage.receive(.integer(123), for: path, at: now.addingTimeInterval(1)).wait()
            await storage.receive(.integer(124), for: path, at: now.addingTimeInterval(2)).wait()
            await storage.receive(.integer(125), for: path, at: now.addingTimeInterval(3)).wait()
            await storage.receive(.integer(126), for: path, at: now.addingTimeInterval(4)).wait()
            await storage.receive(.integer(127), for: path, at: now.addingTimeInterval(5)).wait()
        }

        // Delete all data
        await storage.delete(path: path, from: nil, to: nil, depth: nil).wait()

        do {
            let all = await storage.tree(for: path, from: nil, to: nil, depth: nil, limitPerNode: nil)
            #expect(all.samples.isEmpty)
            #expect(all.isEmpty)
            #expect(all.children.isEmpty)
        }
        let error = await delegate.error
        #expect(error == nil)
    }

    @Test("Limited depth")
    func deleteWithLimitedDepth() async throws {
        let (storage, delegate) = try await makeStorageAndDelegate()

        let parentPath = ["a", "b"]
        let path = parentPath + ["c"]

        let now = Timestamp.current()
        do {
            await storage.receive(.integer(123), for: parentPath, at: now).wait()
            await storage.receive(.integer(124), for: path, at: now).wait()
        }

        // Check that samples are present
        do {
            let all = await storage.tree(for: parentPath, from: nil, to: nil, depth: nil, limitPerNode: nil)
            #expect(all.samples.count == 1)
            let sample = try #require(all.samples.first)
            #expect(sample.value == .integer(123))
            #expect(sample.timestamp.isVeryClose(to: now))

            let child = try #require(all.children["c"])
            #expect(child.samples.count == 1)
            let childSample = try #require(child.samples.first)
            #expect(childSample.value == .integer(124))
            #expect(childSample.timestamp.isVeryClose(to: now))
        }

        // Delete all data at the parent
        await storage.delete(path: parentPath, from: nil, to: nil, depth: 0).wait()

        do {
            let error = await delegate.error
            #expect(error == nil)
        }

        do {
            let child = await storage.tree(for: path, from: nil, to: nil, depth: 0, limitPerNode: nil)
            #expect(child.samples.count == 1)
            let sample = try #require(child.samples.first)
            #expect(sample.value == .integer(124))
            #expect(sample.timestamp.isVeryClose(to: now))
        }

        do {
            let all = await storage.tree(for: parentPath, from: nil, to: nil, depth: nil, limitPerNode: nil)
            #expect(all.samples.isEmpty)
            let child = try #require(all.children["c"])
            #expect(child.samples.count == 1)
            let sample = try #require(child.samples.first)
            #expect(sample.value == .integer(124))
            #expect(sample.timestamp.isVeryClose(to: now))
        }
        do {
            let error = await delegate.error
            #expect(error == nil)
        }
    }

    @Test("Interval")
    func deleteInterval() async throws {
        let (storage, delegate) = try await makeStorageAndDelegate()

        let path = ["a", "b", "c"]
        let now = Timestamp.current()

        do {
            for i in 0..<10 {
                await storage.receive(.integer(i), for: path, at: now.addingTimeInterval(TimeInterval(i))).wait()
            }
        }

        // Check that samples are present
        do {
            let all = await storage.tree(for: path, from: nil, to: nil, depth: 0, limitPerNode: nil)
            #expect(all.samples.count == 10)
        }

        // Delete all data at the parent
        await storage.delete(path: path, from: now.addingTimeInterval(4.5), to: now.addingTimeInterval(7.5), depth: 0).wait()

        do {
            let error = await delegate.error
            #expect(error == nil)
        }

        do {
            let all = await storage.tree(for: path, from: nil, to: nil, depth: nil, limitPerNode: nil)
            #expect(all.samples.count == 7)
            #expect(all.samples[4].value == .integer(4))
            #expect(all.samples[5].value == .integer(8))
        }
        do {
            let error = await delegate.error
            #expect(error == nil)
        }
    }
}