import Foundation
import Testing
import SQLite
import Soil
@testable import SoilSQLite

@Suite("Paths")
struct PathTests {

    private func createResolver() throws -> PathResolver {
        let db = try Connection(.inMemory)
        let table = try PathTable(database: db)
        return PathResolver(table: table)
    }

    /**
     Check that the paths are stored in the cache.
     */
    @Test("Caching")
    func testPathCache() throws {
        let resolver = try createResolver()

        let pathA = ["a", "b", "c"]

        // Getting a path should add the components to the cache
        let id = try resolver.pathId(for: pathA)

        let cachedId = resolver.cachedPathId(for: pathA)
        #expect(cachedId == id)

        // All sub-paths should also be cached
        let first = resolver.cachedPathId(for: ["a"])
        #expect(first != nil)
        let second = resolver.cachedPathId(for: ["a", "b"])
        #expect(second != nil)
    }

    /**
     Check that querying a path also writes it to the database table.
     */
    @Test("Persistence")
    func testDatabaseWrite() throws {
        let resolver = try createResolver()

        let path = ["a", "b", "c"]
        // Getting a path should add the components to the cache
        let id = try resolver.pathId(for: path)

        // All sub-paths should be fetched from the database
        let first = resolver.cachedPathId(for: ["a"])
        #expect(first != nil)
        let second = resolver.cachedPathId(for: ["a", "b"])
        #expect(second != nil)
        let full = resolver.cachedPathId(for: path)
        #expect(full != nil)
        #expect(full == id)

        resolver.clearCache()

        // Check that the cache is empty
        do {
            let firstFromCache = resolver.cachedPathId(for: ["a"])
            #expect(firstFromCache == nil)
            let secondFromCache = resolver.cachedPathId(for: ["a", "b"])
            #expect(secondFromCache == nil)
            let fullFromCache = resolver.cachedPathId(for: path)
            #expect(fullFromCache == nil)
        }

        // All sub-paths should be fetched from the database
        let firstFromDB = try resolver.pathId(for: ["a"])
        #expect(firstFromDB == first)
        let secondFromDB = try resolver.pathId(for: ["a", "b"])
        #expect(secondFromDB == second)
        let fullFromDB = try resolver.pathId(for: path)
        #expect(fullFromDB == full)
    }

    /**
     Check that a sub-tree path is correctly returned
     */
    @Test("Sub-tree")
    func testSubTree() throws {
        let resolver = try createResolver()

        let path = ["a", "b", "c"]
        // Getting a path adds the components to the cache
        let id = try resolver.pathId(for: path)
        #expect(id == 3)

        do {
            let root = try resolver.fullTree(for: [])
            #expect(root.id == 0) // PathTable.rootId
            #expect(root.children.count == 1)
            let a = try #require(root.children["a"])
            #expect(a.id == 1)
            #expect(a.children.count == 1)
            let b = try #require(a.children["b"])
            #expect(b.id == 2)
            #expect(b.children.count == 1)
            let c = try #require(b.children["c"])
            #expect(c.id == 3)
            #expect(c.children.count == 0)
        }

        do {
            let a = try resolver.fullTree(for: ["a"])
            #expect(a.id == 1)
            #expect(a.children.count == 1)
            let b = try #require(a.children["b"])
            #expect(b.id == 2)
            #expect(b.children.count == 1)
            let c = try #require(b.children["c"])
            #expect(c.id == 3)
            #expect(c.children.count == 0)
        }

        do {
            let b = try resolver.fullTree(for: ["a", "b"])
            #expect(b.id == 2)
            #expect(b.children.count == 1)
            let c = try #require(b.children["c"])
            #expect(c.id == 3)
            #expect(c.children.count == 0)
        }

        do {
            let c = try resolver.fullTree(for: ["a", "b", "c"])
            #expect(c.id == 3)
            #expect(c.children.count == 0)
        }
    }
}
