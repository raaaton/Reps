import Foundation
import XCTest

@testable import SportCore

final class VaultRepositoryTests: XCTestCase, @unchecked Sendable {
  func testBatchDeleteKeepsOtherPhotosAndKeyMarker() async throws {
    let (repo, lease) = try await fixture()
    let one = photo()
    let two = photo()
    let other = photo()
    for value in [one, two, other] { try await repo.insert(value, lease: lease) }
    try await repo.delete(ids: [one.id, two.id], lease: lease)
    let remaining = try await repo.metadata(lease: lease)
    XCTAssertEqual(remaining.map(\.id), [other.id])
    let retained = try await repo.content(id: other.id, thumbnail: false, lease: lease)
    XCTAssertEqual(retained, other.original)
    let state = try await repo.state()
    XCTAssertEqual(state?.keyID, lease.keyID)
  }
  func testBatchDeleteFailureRollsBackEveryPhoto() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repo = try VaultRepository(path: path)
    let lease = VaultLease(keyID: UUID().uuidString)
    try await repo.initialize(keyID: lease.keyID, verification: Data(repeating: 1, count: 64))
    let one = photo()
    let two = photo()
    for value in [one, two] { try await repo.insert(value, lease: lease) }
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "CREATE TRIGGER refuse_photo_delete BEFORE DELETE ON vault_photos WHEN OLD.id='\(two.id)' BEGIN SELECT RAISE(ABORT,'refused'); END"
    )
    do {
      try await repo.delete(ids: [one.id, two.id], lease: lease)
      XCTFail("A failed batch must throw")
    } catch {}
    let retained = try await repo.metadata(lease: lease)
    XCTAssertEqual(Set(retained.map(\.id)), Set([one.id, two.id]))
  }
  func testOversizedStoredCiphertextIsRefusedAndReopenPreservesState() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repo = try VaultRepository(path: path)
    let lease = VaultLease(keyID: UUID().uuidString)
    try await repo.initialize(keyID: lease.keyID, verification: Data(repeating: 1, count: 64))
    let value = photo()
    try await repo.insert(value, lease: lease)
    let reopened = try VaultRepository(path: path)
    let loaded = try await reopened.content(id: value.id, thumbnail: false, lease: lease)
    XCTAssertEqual(loaded, value.original)
    let db = try SQLiteDatabase(path: path)
    try db.execute("UPDATE vault_photos SET metadata=zeroblob(16385),thumbnail=zeroblob(1048577)")
    do {
      _ = try await repo.metadata(lease: lease)
      XCTFail("Oversized metadata was read")
    } catch {}
    do {
      _ = try await repo.content(id: value.id, thumbnail: true, lease: lease)
      XCTFail("Oversized thumbnail was read")
    } catch {}
  }
  func fixture() async throws -> (VaultRepository, VaultLease) {
    let repo = try VaultRepository(path: ":memory:")
    let id = UUID().uuidString
    try await repo.initialize(keyID: id, verification: Data(repeating: 1, count: 64))
    return (repo, VaultLease(keyID: id))
  }
  func photo(_ id: String = UUID().uuidString) -> VaultEncryptedPhoto {
    VaultEncryptedPhoto(
      id: id, metadata: Data(repeating: 0, count: 64),
      original: Data([0, 1, 0, 255]) + Data(repeating: 2, count: 64),
      thumbnail: Data(repeating: 3, count: 64))
  }
  func testBinaryRoundTripAndIndependentDeletion() async throws {
    let (repo, lease) = try await fixture()
    let one = photo()
    let two = photo()
    try await repo.insert(one, lease: lease)
    try await repo.insert(two, lease: lease)
    let original = try await repo.content(id: one.id, thumbnail: false, lease: lease)
    XCTAssertEqual(original, one.original)
    try await repo.delete(id: two.id, lease: lease)
    let records = try await repo.metadata(lease: lease)
    XCTAssertEqual(records.map(\.id), [one.id])
    try await repo.delete(id: nil, lease: lease)
    let state = try await repo.state()
    XCTAssertEqual(state?.keyID, lease.keyID)
  }
  func testRevokedAndForeignLeasesCannotReadOrWrite() async throws {
    let (repo, lease) = try await fixture()
    let value = photo()
    try await repo.insert(value, lease: lease)
    lease.invalidate()
    do {
      _ = try await repo.metadata(lease: lease)
      XCTFail()
    } catch {}
    do {
      try await repo.insert(photo(), lease: lease)
      XCTFail()
    } catch {}
    let foreign = VaultLease(keyID: UUID().uuidString)
    for refused in [lease, foreign] {
      do {
        try await repo.delete(ids: [value.id], lease: refused)
        XCTFail("Expired or foreign batch deletion must be refused")
      } catch {}
    }
    let retained = try await repo.metadata(lease: VaultLease(keyID: lease.keyID))
    XCTAssertEqual(retained.map(\.id), [value.id])
    do {
      try await repo.delete(id: nil, lease: foreign)
      XCTFail()
    } catch {}
  }
  func testDuplicatesRollbackAndResetMakesOldLeaseInvalid() async throws {
    let (repo, lease) = try await fixture()
    let one = photo()
    try await repo.insert(one, lease: lease)
    do {
      try await repo.insert(photo(one.id), lease: lease)
      XCTFail()
    } catch {}
    let saved = try await repo.content(id: one.id, thumbnail: false, lease: lease)
    XCTAssertEqual(saved, one.original)
    try await repo.reset()
    do {
      _ = try await repo.metadata(lease: lease)
      XCTFail()
    } catch {}
    let state = try await repo.state()
    XCTAssertNil(state)
  }
}
