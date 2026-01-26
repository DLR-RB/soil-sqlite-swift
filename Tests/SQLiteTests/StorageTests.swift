import Foundation
import Testing
import SQLite
import Soil
import SoilSQLite

@Suite("Storage")
struct StorageTests {

    @Test("Current value for path")
    func saveAndGetValues() throws {
        let db = try Connection(.inMemory)
        let storage = try SQLiteStorage(database: db)

        let pathA = ["a", "b", "c"]
        let now = Date().addingTimeInterval(-0.1)

        storage.receive(.integer(123), for: pathA, at: now)

        let storedPathA = storage.currentSample(for: pathA)
        let sample = try #require(storedPathA)
        #expect(sample.value == .integer(123))
        #expect(sample.timestamp.isVeryClose(to: now))
    }

    /**
     Check if a sub-tree is correctly returned with all content when individual paths have been set
     */
    @Test("Get sub-tree")
    func getSubTree() throws {
        let db = try Connection(.inMemory)
        let storage = try SQLiteStorage(database: db)

        let now = Date()

        storage.receive(.integer(123), for: ["a", "b", "c"], at: now)
        storage.receive(.double(3.14), for: ["a", "b", "d"], at: now)
        storage.receive(.string("some"), for: ["a", "e"], at: now)

        do {
            let tree = storage.currentTree(for: ["a"], depth: nil)
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
    }

    @Test("Sub-tree with depth")
    func subTreeWithDepth() throws {
        let db = try Connection(.inMemory)
        let storage = try SQLiteStorage(database: db)

        let now = Date()

        storage.receive(.integer(123), for: ["a", "b", "c"], at: now)
        storage.receive(.double(3.14), for: ["a", "b", "d"], at: now)
        storage.receive(.string("some"), for: ["a", "e"], at: now)

        do {
            let tree = storage.currentTree(for: ["a"], depth: 2)
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
            let tree = storage.currentTree(for: ["a"], depth: 1)
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
            let tree = storage.currentTree(for: ["a"], depth: 0)
            #expect(tree.current == nil)
            #expect(tree.children.count == 0)
        }
    }
}
