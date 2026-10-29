import XCTest
@testable import Fahrtkosten

final class MergeSyncedEntriesTests: XCTestCase {

    private struct Item: Identifiable, Equatable {
        let id: UUID
        let value: Int
    }

    func testKeepsLocalOnlyItems() {
        let local = [Item(id: UUID(), value: 1)]
        let result = mergeSyncedEntries(local: local, remote: [], deleted: [])
        XCTAssertEqual(result, local)
    }

    func testAddsRemoteOnlyItems() {
        let remote = [Item(id: UUID(), value: 1)]
        let result = mergeSyncedEntries(local: [], remote: remote, deleted: [])
        XCTAssertEqual(result, remote)
    }

    func testRemoteWinsOnConflict() {
        let id = UUID()
        let local = [Item(id: id, value: 1)]
        let remote = [Item(id: id, value: 2)]
        let result = mergeSyncedEntries(local: local, remote: remote, deleted: [])
        XCTAssertEqual(result, [Item(id: id, value: 2)])
    }

    func testExcludesDeletedIDsFromBothSides() {
        let id = UUID()
        let local = [Item(id: id, value: 1)]
        let remote = [Item(id: id, value: 2)]
        let result = mergeSyncedEntries(local: local, remote: remote, deleted: [id])
        XCTAssertTrue(result.isEmpty)
    }

    func testPreservesLocalOrderThenAppendsNewRemoteItems() {
        let idA = UUID()
        let idB = UUID()
        let idC = UUID()
        let local = [Item(id: idA, value: 1), Item(id: idB, value: 2)]
        let remote = [Item(id: idB, value: 20), Item(id: idC, value: 3)]
        let result = mergeSyncedEntries(local: local, remote: remote, deleted: [])
        XCTAssertEqual(result, [Item(id: idA, value: 1), Item(id: idB, value: 20), Item(id: idC, value: 3)])
    }
}
