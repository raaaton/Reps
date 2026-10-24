import Foundation
import XCTest

@testable import SportCore

final class VaultPhotoActivityTests: XCTestCase, @unchecked Sendable {
  func testActivityRemainsAvailableAfterLockAndReopenWithoutMediaAccess() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repo = try VaultRepository(path: path)
    let lease = VaultLease(keyID: UUID().uuidString)
    try await repo.initialize(keyID: lease.keyID, verification: Data(repeating: 1, count: 64))
    for day in ["2026-10-23", "2026-10-24", "2026-10-24"] {
      try await repo.insert(photo(), dayKey: day, lease: lease)
    }
    lease.invalidate()
    let reopened = try VaultRepository(path: path)
    let activity = try await reopened.photoActivity()
    XCTAssertEqual(activity.countsByDay, ["2026-10-23": 1, "2026-10-24": 2])
    XCTAssertFalse(activity.needsUnlock)
    do {
      _ = try await reopened.metadata(lease: lease)
      XCTFail("Public activity must not authorize private metadata")
    } catch {}
    // Destroy synthetic payloads: counting still works without reading them.
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "UPDATE vault_photos SET metadata=zeroblob(20000),original=zeroblob(0),thumbnail=zeroblob(0)")
    let counts = try await reopened.photoActivity()
    XCTAssertEqual(counts, activity)
  }

  func testEditDeletionAndResetUpdateCountsAtomically() async throws {
    let (repo, lease) = try await fixture()
    let one = photo()
    let two = photo()
    try await repo.insert(one, dayKey: "2026-10-23", lease: lease)
    try await repo.insert(two, dayKey: "2026-10-23", lease: lease)
    try await repo.changeMetadata(
      id: one.id, encrypted: Data(repeating: 4, count: 64), dayKey: "2026-10-24", lease: lease)
    var activity = try await repo.photoActivity()
    XCTAssertEqual(activity.countsByDay, ["2026-10-23": 1, "2026-10-24": 1])
    let bytes = try await repo.content(id: one.id, thumbnail: false, lease: lease)
    XCTAssertEqual(bytes, one.original)
    try await repo.delete(ids: [one.id], lease: lease)
    activity = try await repo.photoActivity()
    XCTAssertEqual(activity.countsByDay, ["2026-10-23": 1])
    try await repo.delete(id: nil, lease: lease)
    activity = try await repo.photoActivity()
    XCTAssertEqual(activity.countsByDay, [:])
    try await repo.insert(one, dayKey: "2026-10-24", lease: lease)
    try await repo.reset()
    activity = try await repo.photoActivity()
    XCTAssertEqual(activity, VaultPhotoActivity())
  }

  func testInvalidDatesAndExpiredLeasesCannotPublishActivity() async throws {
    let (repo, lease) = try await fixture()
    let photo = photo()
    for day in ["2026-02-30", "2026-1-01", "0000-01-01", "not-a-date"] {
      do {
        try await repo.insert(photo, dayKey: day, lease: lease)
        XCTFail("Invalid date must fail")
      } catch {}
    }
    try await repo.insert(photo, dayKey: "2026-10-24", lease: lease)
    lease.invalidate()
    do {
      try await repo.changeMetadata(
        id: photo.id, encrypted: Data(repeating: 4, count: 64), dayKey: "2026-10-23", lease: lease)
      XCTFail("Expired lease must not update private metadata or public dates")
    } catch {}
    let activity = try await repo.photoActivity()
    XCTAssertEqual(activity.countsByDay, ["2026-10-24": 1])
  }

  func testLegacyMigrationPreservesEveryEncryptedByteAndKeepsPhotoDateIndexEmpty() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "CREATE TABLE vault_state (singleton INTEGER PRIMARY KEY, key_id TEXT NOT NULL, verification BLOB NOT NULL)"
    )
    try db.execute(
      "CREATE TABLE vault_photos (id TEXT PRIMARY KEY, metadata BLOB NOT NULL, original BLOB NOT NULL, thumbnail BLOB NOT NULL)"
    )
    try db.execute("PRAGMA user_version=1")
    let keyID = UUID().uuidString
    let photo = photo()
    try db.execute(
      "INSERT INTO vault_state VALUES(1,?,?)", [.text(keyID), .blob(Data(repeating: 1, count: 64))])
    try db.execute(
      "INSERT INTO vault_photos VALUES(?,?,?,?)",
      [.text(photo.id), .blob(photo.metadata), .blob(photo.original), .blob(photo.thumbnail)])
    let repo = try VaultRepository(path: path)
    let lease = VaultLease(keyID: keyID)
    let original = try await repo.content(id: photo.id, thumbnail: false, lease: lease)
    let thumbnail = try await repo.content(id: photo.id, thumbnail: true, lease: lease)
    let metadata = try await repo.metadata(lease: lease)
    XCTAssertEqual(original, photo.original)
    XCTAssertEqual(thumbnail, photo.thumbnail)
    XCTAssertEqual(metadata.first?.data, photo.metadata)
    XCTAssertEqual(try db.query("PRAGMA user_version").first?.integer("user_version"), 3)
    var activity = try await repo.photoActivity()
    XCTAssertEqual(activity, VaultPhotoActivity(needsUnlock: true))
    try await repo.indexPhotoDays(
      [VaultPhotoIndexEntry(id: photo.id, dayKey: "2026-10-23", encryptedMetadata: photo.metadata)],
      lease: lease)
    activity = try await repo.photoActivity()
    XCTAssertEqual(activity, VaultPhotoActivity(countsByDay: ["2026-10-23": 1]))
    // The only added plaintext is day_key; all previous ciphertext stays byte-identical.
    let stored = try db.query("SELECT metadata,original,thumbnail,day_key FROM vault_photos").first!
    XCTAssertEqual(try stored.blob("metadata"), photo.metadata)
    XCTAssertEqual(try stored.blob("original"), photo.original)
    XCTAssertEqual(try stored.blob("thumbnail"), photo.thumbnail)
    XCTAssertEqual(try stored.text("day_key"), "2026-10-23")
  }

  func testBackfillRejectsStaleIncompleteDuplicateAndUnauthorizedSnapshots() async throws {
    let (repo, lease) = try await fixture()
    let one = photo()
    let two = photo()
    for value in [one, two] { try await repo.insert(value, dayKey: "2026-10-23", lease: lease) }
    let first = VaultPhotoIndexEntry(
      id: one.id, dayKey: "2026-10-24", encryptedMetadata: one.metadata)
    let second = VaultPhotoIndexEntry(
      id: two.id, dayKey: "2026-10-24", encryptedMetadata: two.metadata)
    for invalid in [[first], [first, first]] {
      do {
        try await repo.indexPhotoDays(invalid, lease: lease)
        XCTFail("Incomplete or duplicate snapshots cannot rewrite the index")
      } catch {}
    }
    try await repo.changeMetadata(
      id: two.id, encrypted: Data(repeating: 5, count: 64), dayKey: "2026-10-23", lease: lease)
    do {
      try await repo.indexPhotoDays([first, second], lease: lease)
      XCTFail("Stale metadata snapshot must be refused atomically")
    } catch {}
    for refused in [VaultLease(keyID: UUID().uuidString), lease] {
      if refused === lease { lease.invalidate() }
      do {
        try await repo.indexPhotoDays([first, second], lease: refused)
        XCTFail("Foreign or expired lease must not backfill")
      } catch {}
    }
    let activity = try await repo.photoActivity()
    XCTAssertEqual(activity.countsByDay, ["2026-10-23": 2])
  }

  func testFailedDateUpdateRollsBackCiphertextAndActivity() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repo = try VaultRepository(path: path)
    let lease = VaultLease(keyID: UUID().uuidString)
    try await repo.initialize(keyID: lease.keyID, verification: Data(repeating: 1, count: 64))
    let value = photo()
    try await repo.insert(value, dayKey: "2026-10-23", lease: lease)
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "CREATE TRIGGER refuse_index BEFORE UPDATE OF day_key ON vault_photos BEGIN SELECT RAISE(ABORT,'refused'); END"
    )
    do {
      try await repo.changeMetadata(
        id: value.id, encrypted: Data(repeating: 5, count: 64), dayKey: "2026-10-24", lease: lease)
      XCTFail("Failed date write must not commit any ciphertext")
    } catch {}
    let metadata = try await repo.metadata(lease: lease)
    let activity = try await repo.photoActivity()
    XCTAssertEqual(metadata.first?.data, value.metadata)
    XCTAssertEqual(activity.countsByDay, ["2026-10-23": 1])
  }

  func testBackfillFailureOnSecondRowRollsBackFirstAndDeletedSnapshotsStayRejected() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repo = try VaultRepository(path: path)
    let lease = VaultLease(keyID: UUID().uuidString)
    try await repo.initialize(keyID: lease.keyID, verification: Data(repeating: 1, count: 64))
    let one = photo()
    let two = photo()
    for value in [one, two] { try await repo.insert(value, dayKey: "2026-10-23", lease: lease) }
    let entries = [one, two].map {
      VaultPhotoIndexEntry(id: $0.id, dayKey: "2026-10-24", encryptedMetadata: $0.metadata)
    }
    let db = try SQLiteDatabase(path: path)
    try db.execute("UPDATE vault_photos SET day_key=NULL")
    try db.execute(
      "CREATE TRIGGER refuse_second_index BEFORE UPDATE OF day_key ON vault_photos WHEN OLD.id='\(two.id)' BEGIN SELECT RAISE(ABORT,'refused'); END"
    )
    do {
      try await repo.indexPhotoDays(entries, lease: lease)
      XCTFail("A failed backfill must roll back its earlier rows")
    } catch {}
    var activity = try await repo.photoActivity()
    XCTAssertEqual(activity, VaultPhotoActivity(needsUnlock: true))
    try db.execute("DROP TRIGGER refuse_second_index")
    try await repo.delete(id: two.id, lease: lease)
    do {
      try await repo.indexPhotoDays(entries, lease: lease)
      XCTFail("A deleted photo must never be restored or indexed by stale backfill")
    } catch {}
    activity = try await repo.photoActivity()
    XCTAssertEqual(activity, VaultPhotoActivity(needsUnlock: true))
    let original = try await repo.content(id: one.id, thumbnail: false, lease: lease)
    XCTAssertEqual(original, one.original)
  }
  private func photo() -> VaultEncryptedPhoto {
    VaultEncryptedPhoto(
      id: UUID().uuidString, metadata: Data(repeating: 0, count: 64),
      original: Data([0, 1, 0, 255]) + Data(repeating: 2, count: 64),
      thumbnail: Data(repeating: 3, count: 64))
  }
  private func fixture() async throws -> (VaultRepository, VaultLease) {
    let repo = try VaultRepository(path: ":memory:")
    let lease = VaultLease(keyID: UUID().uuidString)
    try await repo.initialize(keyID: lease.keyID, verification: Data(repeating: 1, count: 64))
    return (repo, lease)
  }

}
