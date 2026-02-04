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
        #expect(sample.timestamp.isVeryClose(to: now))
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
            #expect(tree.current == nil)
            #expect(tree.children.count == 2)
            let b = try #require(tree.children["b"])
            #expect(b.current == nil)
            #expect(b.children.count == 2)
            let c = try #require(b.children["c"])
            #expect(c.samples.count == 1)
            let cSample = try #require(c.current)
            #expect(cSample.value == .integer(123))
            #expect(cSample.timestamp.isVeryClose(to: now))
            #expect(c.children.count == 0)
            let d = try #require(b.children["d"])
            #expect(d.samples.count == 1)
            let dSample = try #require(d.current)
            #expect(dSample.value == .double(3.14))
            #expect(dSample.timestamp.isVeryClose(to: now))
            #expect(d.children.count == 0)
            let e = try #require(tree.children["e"])
            #expect(e.samples.count == 1)
            let eSample = try #require(e.current)
            #expect(eSample.value == .string("some"))
            #expect(eSample.timestamp.isVeryClose(to: now))
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
            #expect(tree.current == nil)
            #expect(tree.children.count == 2)
            let b = try #require(tree.children["b"])
            #expect(b.current == nil)
            #expect(b.children.count == 2)
            let c = try #require(b.children["c"])
            #expect(c.samples.count == 1)
            let cSample = try #require(c.current)
            #expect(cSample.value == .integer(123))
            #expect(cSample.timestamp.isVeryClose(to: now))
            #expect(c.children.count == 0)
            let d = try #require(b.children["d"])
            #expect(d.samples.count == 1)
            let dSample = try #require(d.current)
            #expect(dSample.value == .double(3.14))
            #expect(dSample.timestamp.isVeryClose(to: now))
            #expect(d.children.count == 0)
            let e = try #require(tree.children["e"])
            #expect(e.samples.count == 1)
            let eSample = try #require(e.current)
            #expect(eSample.value == .string("some"))
            #expect(eSample.timestamp.isVeryClose(to: now))
            #expect(e.children.count == 0)
        }

        do {
            let tree = await storage.currentTree(for: ["a"], depth: 1)
            #expect(tree.current == nil)
            #expect(tree.children.count == 2)
            let b = try #require(tree.children["b"])
            #expect(b.current == nil)
            #expect(b.children.count == 0)
            let e = try #require(tree.children["e"])
            #expect(e.samples.count == 1)
            let eSample = try #require(e.current)
            #expect(eSample.value == .string("some"))
            #expect(eSample.timestamp.isVeryClose(to: now))
            #expect(e.children.count == 0)
        }

        do {
            let tree = await storage.currentTree(for: ["a"], depth: 0)
            #expect(tree.current == nil)
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
            #expect(sample.timestamp.isVeryClose(to: now))
        }

        // Overwrite sample
        await storage.receive(.integer(42), for: path, at: now).wait()

        do {
            let samples = await storage.samples(for: path)
            #expect(samples.count == 1)
            let sample = try #require(samples.first)
            #expect(sample.value == .integer(42))
            #expect(sample.timestamp.isVeryClose(to: now))
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
            #expect(sample.timestamp.isVeryClose(to: now))
        }

        #expect(await delegate.error == nil)
    }
}
