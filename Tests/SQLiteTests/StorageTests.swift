import Foundation
import Testing
import SQLite
import Soil
import SoilSQLite

@Suite("Storage")
struct StorageTests {

    @Test("Current value for path")
    func saveAndGetSamples() async throws {
        let (storage, delegate) = try await makeStorageAndDelegate()

        let pathA = ["a", "b", "c"]
        let now = Date().addingTimeInterval(-0.1)

        await storage.receive(.integer(123), for: pathA, at: now).wait()

        let storedPathA = await storage.currentSample(for: pathA)
        let sample = try #require(storedPathA)
        #expect(sample.value == .integer(123))
        #expect(sample.timestamp?.isVeryClose(to: now) ?? false)
        #expect(await delegate.error == nil)
    }

    /**
     Check if a sub-tree is correctly returned with all content when individual paths have been set
     */
    @Test("Get sub-tree")
    func getSubTree() async throws {
        let (storage, delegate) = try await makeStorageAndDelegate()

        let now = Date()

        await storage.receive(.integer(123), for: ["a", "b", "c"], at: now).wait()
        await storage.receive(.double(3.14), for: ["a", "b", "d"], at: now).wait()
        await storage.receive(.string("some"), for: ["a", "e"], at: now).wait()

        do {
            let tree = await storage.currentTree(for: ["a"], depth: nil)
            #expect(tree.samples.isEmpty)
            #expect(tree.children.count == 2)
            let b = try #require(tree.children["b"])
            #expect(b.samples.isEmpty)
            #expect(b.children.count == 2)
            let c = try #require(b.children["c"])
            #expect(c.samples.count == 1)
            let cSample = try #require(c.currentSample)
            #expect(cSample.value == .integer(123))
            #expect(cSample.timestamp?.isVeryClose(to: now) ?? false)
            #expect(c.children.count == 0)
            let d = try #require(b.children["d"])
            #expect(d.samples.count == 1)
            let dSample = try #require(d.currentSample)
            #expect(dSample.value == .double(3.14))
            #expect(dSample.timestamp?.isVeryClose(to: now) ?? false)
            #expect(d.children.count == 0)
            let e = try #require(tree.children["e"])
            #expect(e.samples.count == 1)
            let eSample = try #require(e.currentSample)
            #expect(eSample.value == .string("some"))
            #expect(eSample.timestamp?.isVeryClose(to: now) ?? false)
            #expect(e.children.count == 0)
        }
        #expect(await delegate.error == nil)
    }

    @Test("Sub-tree with depth")
    func subTreeWithDepth() async throws {
        let (storage, delegate) = try await makeStorageAndDelegate()

        let now = Date()

        await storage.receive(.integer(123), for: ["a", "b", "c"], at: now).wait()
        await storage.receive(.double(3.14), for: ["a", "b", "d"], at: now).wait()
        await storage.receive(.string("some"), for: ["a", "e"], at: now).wait()

        do {
            let tree = await storage.currentTree(for: ["a"], depth: 2)
            #expect(tree.samples.isEmpty)
            #expect(tree.children.count == 2)
            let b = try #require(tree.children["b"])
            #expect(b.samples.isEmpty)
            #expect(b.children.count == 2)
            let c = try #require(b.children["c"])
            #expect(c.samples.count == 1)
            let cSample = try #require(c.currentSample)
            #expect(cSample.value == .integer(123))
            #expect(cSample.timestamp?.isVeryClose(to: now) ?? false)
            #expect(c.children.count == 0)
            let d = try #require(b.children["d"])
            #expect(d.samples.count == 1)
            let dSample = try #require(d.currentSample)
            #expect(dSample.value == .double(3.14))
            #expect(dSample.timestamp?.isVeryClose(to: now) ?? false)
            #expect(d.children.count == 0)
            let e = try #require(tree.children["e"])
            #expect(e.samples.count == 1)
            let eSample = try #require(e.currentSample)
            #expect(eSample.value == .string("some"))
            #expect(eSample.timestamp?.isVeryClose(to: now) ?? false)
            #expect(e.children.count == 0)
        }

        do {
            let tree = await storage.currentTree(for: ["a"], depth: 1)
            #expect(tree.samples.isEmpty)
            #expect(tree.children.count == 2)
            let b = try #require(tree.children["b"])
            #expect(b.samples.isEmpty)
            #expect(b.children.count == 0)
            let e = try #require(tree.children["e"])
            #expect(e.samples.count == 1)
            let eSample = try #require(e.currentSample)
            #expect(eSample.value == .string("some"))
            #expect(eSample.timestamp?.isVeryClose(to: now) ?? false)
            #expect(e.children.count == 0)
        }

        do {
            let tree = await storage.currentTree(for: ["a"], depth: 0)
            #expect(tree.samples.isEmpty)
            #expect(tree.children.count == 0)
        }
        #expect(await delegate.error == nil)
    }

    @Test("Insert duplicate")
    func testInsertDuplicate() async throws {
        let (storage, delegate) = try await makeStorageAndDelegate()

        let now = Date()
        let path = ["a", "b", "c"]

        await storage.receive(.integer(123), for: path, at: now).wait()

        do {
            let samples = await storage.samples(for: path)
            #expect(samples.count == 1)
            let sample = try #require(samples.first)
            #expect(sample.value == .integer(123))
            #expect(sample.timestamp?.isVeryClose(to: now) ?? false)
        }

        // Overwrite sample
        await storage.receive(.integer(42), for: path, at: now).wait()

        do {
            let samples = await storage.samples(for: path)
            #expect(samples.count == 1)
            let sample = try #require(samples.first)
            #expect(sample.value == .integer(42))
            #expect(sample.timestamp?.isVeryClose(to: now) ?? false)
        }
        #expect(await delegate.error == nil)
    }

    @Test("Store path")
    func testStorePath() async throws {
        let (storage, delegate) = try await makeStorageAndDelegate()

        let now = Date()
        let path = ["a", "b", "c"]

        await storage.receive(.path(["zz", "abc", "42"]), for: path, at: now).wait()

        try await Task.sleep(for: .seconds(0.1))

        do {
            let samples = await storage.samples(for: path)
            try await Task.sleep(for: .seconds(0.1))
            #expect(await delegate.error == nil)
            #expect(samples.count == 1)
            let oSample = await storage.currentSample(for: path)
            let sample = try #require(oSample)
            #expect(sample.value == .path(["zz", "abc", "42"]))
            #expect(sample.timestamp?.isVeryClose(to: now) ?? false)
        }

        #expect(await delegate.error == nil)
    }

    @Test("Current sample")
    func testCurrentSample() async throws {
        let (storage, _) = try await makeStorageAndDelegate()

        let now = Date()
        let path = ["a", "b", "c"]

        await storage.receive(.integer(1), for: path, at: now.advanced(by: -5)).wait()
        await storage.receive(.integer(3), for: path, at: now.advanced(by: -3)).wait()
        await storage.receive(.integer(5), for: path, at: now.advanced(by: -1)).wait() // Latest
        await storage.receive(.integer(4), for: path, at: now.advanced(by: -2)).wait()
        await storage.receive(.integer(2), for: path, at: now.advanced(by: -4)).wait()

        let possSample = await storage.currentSample(for: path)
        let sample = try #require(possSample)
        #expect(sample.value == .integer(5))
        #expect(sample.timestamp?.isVeryClose(to: now.advanced(by: -1)) ?? false)
    }

    @Test("Samples in range")
    func testSamplesInRange() async throws {
        let (storage, _) = try await makeStorageAndDelegate()

        let now = Date()
        let lastHour = now.addingTimeInterval(-3600)
        let path = ["a", "b", "c"]

        await storage.receive(.integer(1), for: path, at: now.advanced(by: -5)).wait()
        await storage.receive(.integer(3), for: path, at: now.advanced(by: -3)).wait()
        await storage.receive(.integer(5), for: path, at: now.advanced(by: -1)).wait() // Latest
        await storage.receive(.integer(4), for: path, at: now.advanced(by: -2)).wait()
        await storage.receive(.integer(2), for: path, at: now.advanced(by: -4)).wait()
        await storage.receive(.integer(11), for: path, at: now.advanced(by: -3605)).wait()
        await storage.receive(.integer(13), for: path, at: now.advanced(by: -3603)).wait()
        await storage.receive(.integer(15), for: path, at: now.advanced(by: -3601)).wait()
        await storage.receive(.integer(14), for: path, at: now.advanced(by: -3602)).wait()
        await storage.receive(.integer(12), for: path, at: now.advanced(by: -3604)).wait()

        let samples = await storage.samples(for: path, from: lastHour, to: now, limit: nil)

        #expect(samples.count == 5)
    }
}
