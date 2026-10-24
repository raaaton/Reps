import Foundation
import XCTest

@testable import RepsCore

final class VaultVideoTests: XCTestCase, @unchecked Sendable {
  func testUpgradeAddsVideoStorageWithoutChangingPhotosOrKey() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "CREATE TABLE vault_state(singleton INTEGER PRIMARY KEY,key_id TEXT,verification BLOB)")
    try db.execute(
      "CREATE TABLE vault_photos(id TEXT PRIMARY KEY,metadata BLOB,original BLOB,thumbnail BLOB,day_key TEXT)"
    )
    try db.execute("PRAGMA user_version=2")
    let keyID = UUID().uuidString
    let id = UUID().uuidString
    let bytes = Data(repeating: 7, count: 64)
    try db.execute("INSERT INTO vault_state VALUES(1,?,?)", [.text(keyID), .blob(bytes)])
    try db.execute(
      "INSERT INTO vault_photos VALUES(?,?,?,?,?)",
      [.text(id), .blob(bytes), .blob(bytes), .blob(bytes), .text("2026-10-24")])
    let repo = try VaultRepository(path: path)
    XCTAssertEqual(try db.query("PRAGMA user_version").first?.integer("user_version"), 3)
    let state = try await repo.state()
    XCTAssertEqual(state?.keyID, keyID)
    let actual = try await repo.content(id: id, thumbnail: false, lease: VaultLease(keyID: keyID))
    XCTAssertEqual(actual, bytes)
    XCTAssertEqual(
      try db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='vault_videos'")
        .count, 1)
  }
}

extension VaultVideoTests {
  func setupVideo(path: String = ":memory:") async throws -> (
    VaultRepository, VaultLease, VaultEncryptedVideo
  ) {
    let repo = try VaultRepository(path: path)
    let lease = VaultLease(keyID: UUID().uuidString)
    try await repo.initialize(keyID: lease.keyID, verification: Data(repeating: 1, count: 64))
    let movement = UUID().uuidString
    try await repo.saveMovement(
      id: movement, encrypted: Data(repeating: 2, count: 64), lease: lease)
    return (
      repo, lease,
      VaultEncryptedVideo(
        id: UUID().uuidString, movementID: movement,
        metadata: Data(repeating: 3, count: 64), thumbnail: Data(repeating: 4, count: 64),
        byteCount: VaultVideoLimits.chunkBytes + 7)
    )
  }
  func testVideoIsPublishedOnlyAfterAllChunksAndPhotoDeletionKeepsIt() async throws {
    let (repo, lease, video) = try await setupVideo()
    try await repo.beginVideo(video, lease: lease)
    let hidden = try await repo.videoMetadata(lease: lease)
    XCTAssertTrue(hidden.isEmpty)
    try await repo.appendVideoChunk(
      id: video.id, index: 0,
      encrypted: Data(repeating: 5, count: VaultVideoLimits.chunkBytes + 28), lease: lease)
    do {
      try await repo.finishVideo(id: video.id, lease: lease)
      XCTFail("Incomplete video published")
    } catch {}
    try await repo.appendVideoChunk(
      id: video.id, index: 1, encrypted: Data(repeating: 6, count: 35), lease: lease)
    try await repo.finishVideo(id: video.id, lease: lease)
    try await repo.delete(id: nil, lease: lease)
    let saved = try await repo.videoMetadata(lease: lease)
    XCTAssertEqual(saved.map(\.id), [video.id])
    let last = try await repo.videoChunk(id: video.id, index: 1, lease: lease)
    XCTAssertEqual(last, Data(repeating: 6, count: 35))
    try await repo.deleteMovement(id: video.movementID, lease: lease)
    let removed = try await repo.videoMetadata(lease: lease)
    XCTAssertTrue(removed.isEmpty)
  }
  func testRevokedLeaseCannotWriteOrReadVideos() async throws {
    let (repo, lease, video) = try await setupVideo()
    try await repo.beginVideo(video, lease: lease)
    lease.invalidate()
    do {
      _ = try await repo.videoMetadata(lease: lease)
      XCTFail("Private metadata leaked")
    } catch {}
    do {
      try await repo.appendVideoChunk(
        id: video.id, index: 0,
        encrypted: Data(repeating: 5, count: VaultVideoLimits.chunkBytes + 28), lease: lease)
      XCTFail("Stale write accepted")
    } catch {}
  }
  func testByteRangesClampAtEndWithoutOverflow() throws {
    XCTAssertEqual(
      try VaultVideoRange.requested(offset: 1_048_574, length: 10, total: 1_048_580),
      VaultVideoRange(lower: 1_048_574, upper: 1_048_580))
    XCTAssertEqual(
      try VaultVideoRange.requested(offset: 3, length: Int.max, total: 7),
      VaultVideoRange(lower: 3, upper: 7))
    XCTAssertThrowsError(try VaultVideoRange.requested(offset: -1, length: 2, total: 5))
    XCTAssertThrowsError(try VaultVideoRange.requested(offset: Int64.max, length: 2, total: 5))
    XCTAssertEqual(
      VaultVideoAlignment(first: 2, second: 4).remaining(firstDuration: 8, secondDuration: 6), 2)
  }
  func testFollowingAndSavedKeepVideoHistoryWithoutCreatingSkills() throws {
    let skill = SkillCatalogue.definitions[0]
    let progress = SkillProgress(skillID: skill.id, currentStepID: skill.steps[0].id)
    let following = VaultMovementCollection.following([skill], progress: [progress])
    XCTAssertEqual(following.compactMap(\.metadata.skillID), [skill.id])
    let custom = VaultMovementEntry(id: UUID().uuidString, metadata: .init(name: "Squat"))
    let linked = VaultMovementEntry(
      id: following.first?.id ?? UUID().uuidString,
      metadata: .init(name: skill.name, skillID: skill.id))
    let video = VaultVideoEntry(
      id: UUID().uuidString,
      metadata: .init(
        dayKey: "2026-10-24", movementID: linked.id, type: "public.mpeg-4", duration: 12,
        byteCount: 8, importedAt: 1))
    XCTAssertEqual(
      VaultMovementCollection.saved([linked, custom], following: [], videos: [video]).map(\.id),
      [linked.id, custom.id].sorted { a, b in
        let names = [linked.id: linked.metadata.name, custom.id: custom.metadata.name]
        return names[a]! < names[b]!
      })
    XCTAssertEqual(VaultMovementCollection.videos([video], movementID: linked.id), [video])
    XCTAssertTrue(
      VaultMovementCollection.saved([linked], following: following, videos: [video]).isEmpty)
  }
}

extension VaultVideoTests {
  func testCancelledSessionCanRemoveOnlyItsOwnUnpublishedImport() async throws {
    let (repo, lease, video) = try await setupVideo()
    try await repo.beginVideo(video, lease: lease)
    let other = VaultLease(keyID: lease.keyID)
    try await repo.cancelVideo(id: video.id, lease: other)
    try await repo.appendVideoChunk(
      id: video.id, index: 0,
      encrypted: Data(repeating: 5, count: VaultVideoLimits.chunkBytes + 28), lease: lease)
    lease.invalidate()
    try await repo.cancelVideo(id: video.id, lease: lease)
    // Reusing the same id succeeds only if the incomplete row and its chunks were removed.
    try await repo.beginVideo(video, lease: other)
  }
}

extension VaultVideoTests {
  private func publish(_ video: VaultEncryptedVideo, repo: VaultRepository, lease: VaultLease)
    async throws
  {
    try await repo.beginVideo(video, lease: lease)
    try await repo.appendVideoChunk(
      id: video.id, index: 0,
      encrypted: Data(repeating: 5, count: VaultVideoLimits.chunkBytes + 28), lease: lease)
    try await repo.appendVideoChunk(
      id: video.id, index: 1, encrypted: Data(repeating: 6, count: 35), lease: lease)
    try await repo.finishVideo(id: video.id, lease: lease)
  }
  func testReopenRemovesInterruptedImportAndKeepsPublishedVideo() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let (repo, lease, video) = try await setupVideo(path: path)
    try await publish(video, repo: repo, lease: lease)
    let orphan = VaultEncryptedVideo(
      id: UUID().uuidString, movementID: video.movementID, metadata: video.metadata,
      thumbnail: video.thumbnail, byteCount: video.byteCount)
    try await repo.beginVideo(orphan, lease: lease)
    try await repo.appendVideoChunk(
      id: orphan.id, index: 0,
      encrypted: Data(repeating: 7, count: VaultVideoLimits.chunkBytes + 28), lease: lease)
    let reopened = try VaultRepository(path: path)
    let saved = try await reopened.videoMetadata(lease: lease)
    XCTAssertEqual(saved.map(\.id), [video.id])
    try await reopened.beginVideo(orphan, lease: lease)
    let db = try SQLiteDatabase(path: path)
    XCTAssertEqual(
      try db.query(
        "SELECT COUNT(*) AS n FROM vault_video_chunks WHERE video_id=?", [.text(orphan.id)]
      ).first?.integer("n"), 0)
  }
  func testChunkSizeDuplicateAndForeignImportWritesAreRejected() async throws {
    let (repo, lease, video) = try await setupVideo()
    try await repo.beginVideo(video, lease: lease)
    for (index, count) in [(0, 64), (2, 35), (-1, 35)] {
      do {
        try await repo.appendVideoChunk(
          id: video.id, index: index, encrypted: Data(repeating: 1, count: count), lease: lease)
        XCTFail("Invalid chunk accepted")
      } catch {}
    }
    let other = VaultLease(keyID: lease.keyID)
    do {
      try await repo.appendVideoChunk(
        id: video.id, index: 0,
        encrypted: Data(repeating: 1, count: VaultVideoLimits.chunkBytes + 28), lease: other)
      XCTFail("Different import owner accepted")
    } catch {}
    try await repo.appendVideoChunk(
      id: video.id, index: 0,
      encrypted: Data(repeating: 1, count: VaultVideoLimits.chunkBytes + 28), lease: lease)
    do {
      try await repo.appendVideoChunk(
        id: video.id, index: 0,
        encrypted: Data(repeating: 1, count: VaultVideoLimits.chunkBytes + 28), lease: lease)
      XCTFail("Duplicate accepted")
    } catch {}
  }
  func testDeletionFailureRollsBackMovementVideoAndAllChunks() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let (repo, lease, video) = try await setupVideo(path: path)
    try await publish(video, repo: repo, lease: lease)
    let db = try SQLiteDatabase(path: path)
    try db.execute(
      "CREATE TRIGGER refuse_chunk_delete BEFORE DELETE ON vault_video_chunks BEGIN SELECT RAISE(ABORT,'refused'); END"
    )
    do {
      try await repo.deleteMovement(id: video.movementID, lease: lease)
      XCTFail("Deletion unexpectedly succeeded")
    } catch {}
    let saved = try await repo.videoMetadata(lease: lease)
    let movements = try await repo.movements(lease: lease)
    let last = try await repo.videoChunk(id: video.id, index: 1, lease: lease)
    XCTAssertEqual(saved.map(\.id), [video.id])
    XCTAssertEqual(movements.map(\.id), [video.movementID])
    XCTAssertEqual(last.count, 35)
  }
  func testResetRemovesAllMediaAndRejectsOldKeyWithoutRegeneration() async throws {
    let (repo, lease, video) = try await setupVideo()
    try await publish(video, repo: repo, lease: lease)
    try await repo.cancelVideo(id: video.id, lease: lease)
    let stillPublished = try await repo.videoMetadata(lease: lease)
    XCTAssertEqual(stillPublished.map(\.id), [video.id])
    try await repo.reset()
    let state = try await repo.state()
    XCTAssertNil(state)
    do {
      _ = try await repo.movements(lease: lease)
      XCTFail("Old session accepted after reset")
    } catch {}
    do {
      _ = try await repo.videoChunk(id: video.id, index: 0, lease: lease)
      XCTFail("Deleted video readable")
    } catch {}
    let replacement = VaultLease(keyID: UUID().uuidString)
    try await repo.initialize(keyID: replacement.keyID, verification: Data(repeating: 8, count: 64))
    let empty = try await repo.videoMetadata(lease: replacement)
    XCTAssertTrue(empty.isEmpty)
  }
  func testMissingKeyMarkerWithMovementDataFailsClosed() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let (repo, _, _) = try await setupVideo(path: path)
    let db = try SQLiteDatabase(path: path)
    try db.execute("DELETE FROM vault_state")
    do {
      _ = try await repo.state()
      XCTFail("Vault with missing key mistaken for new")
    } catch {}
    do {
      try await repo.initialize(
        keyID: UUID().uuidString, verification: Data(repeating: 1, count: 64))
      XCTFail("Key replaced over existing data")
    } catch {}
    XCTAssertEqual(try db.query("SELECT COUNT(*) AS n FROM vault_movements").first?.integer("n"), 1)
  }
  func testVideoMetadataValidationAndChronologicalOrder() throws {
    let movement = UUID().uuidString
    let current = VaultVideoMetadata(
      dayKey: "2026-10-24", movementID: movement, type: "public.mpeg-4", duration: 30,
      byteCount: 100, importedAt: 10)
    try current.validate()
    var malformed = current
    malformed.dayKey = "2026-02-30"
    XCTAssertThrowsError(try malformed.validate())
    let huge = VaultVideoMetadata(
      dayKey: current.dayKey, movementID: movement, type: current.type, duration: 301,
      byteCount: 100, importedAt: 10)
    XCTAssertThrowsError(try huge.validate())
    let first = VaultVideoEntry(id: UUID().uuidString, metadata: current)
    let newer = VaultVideoEntry(
      id: UUID().uuidString,
      metadata: .init(
        dayKey: current.dayKey, movementID: movement, type: current.type, duration: 2,
        byteCount: 10, importedAt: 11))
    XCTAssertEqual(
      VaultMovementCollection.videos([first, newer], movementID: movement).map(\.id),
      [newer.id, first.id])
  }
  func testArchivedSkillHistoryIsSavedAndEmptyOldSkillIsHidden() {
    var skill = SkillCatalogue.definitions[0]
    skill.isArchived = true
    let progress = SkillProgress(skillID: skill.id, currentStepID: skill.steps[0].id)
    XCTAssertTrue(VaultMovementCollection.following([skill], progress: [progress]).isEmpty)
    let movement = VaultMovementEntry(
      id: UUID().uuidString, metadata: .init(name: skill.name, skillID: skill.id))
    XCTAssertTrue(VaultMovementCollection.saved([movement], following: [], videos: []).isEmpty)
    let video = VaultVideoEntry(
      id: UUID().uuidString,
      metadata: .init(
        dayKey: "2026-10-24", movementID: movement.id, type: "public.mpeg-4", duration: 1,
        byteCount: 1, importedAt: 1))
    XCTAssertEqual(
      VaultMovementCollection.saved([movement], following: [], videos: [video]), [movement])
  }
}

extension VaultVideoTests {
  func testNonCanonicalVideoDatesAreRejected() {
    let metadata = VaultVideoMetadata(
      dayKey: "2026-1-1", movementID: UUID().uuidString,
      type: "public.mpeg-4", duration: 3, byteCount: 1, importedAt: 1)
    XCTAssertThrowsError(try metadata.validate())
  }
}

extension VaultVideoTests {
  func testFollowedMetadataAcceptsExistingTrainingNameAndIdentifierLimits() throws {
    var skill = SkillCatalogue.definitions[0]
    skill.id = String(repeating: "s", count: 256)
    skill.name = String(repeating: "a", count: 2000)
    let progress = SkillProgress(skillID: skill.id, currentStepID: skill.steps[0].id)
    let movement = try XCTUnwrap(
      VaultMovementCollection.following([skill], progress: [progress]).first)
    XCTAssertNoThrow(try movement.metadata.validate())
    let extreme = VaultMovementMetadata(
      name: String(repeating: "\u{1}", count: 4096), skillID: skill.id)
    XCTAssertNoThrow(try extreme.validate())
    XCTAssertLessThanOrEqual(try JSONEncoder().encode(extreme).count + 28, 32768)
    XCTAssertThrowsError(
      try VaultMovementMetadata(name: String(repeating: "a", count: 101)).validate())
    XCTAssertThrowsError(try VaultMovementMetadata(name: "bad\0name").validate())
  }
}

extension VaultVideoTests {
  func testReplacementIsAtomicAndRejectsChangedSource() async throws {
    let (repo, lease, original) = try await setupVideo()
    func fill(_ video: VaultEncryptedVideo) async throws {
      try await repo.beginVideo(video, lease: lease)
      try await repo.appendVideoChunk(
        id: video.id, index: 0,
        encrypted: Data(repeating: 5, count: VaultVideoLimits.chunkBytes + 28), lease: lease)
      try await repo.appendVideoChunk(
        id: video.id, index: 1,
        encrypted: Data(repeating: 6, count: 35), lease: lease)
    }
    try await fill(original)
    try await repo.finishVideo(id: original.id, lease: lease)
    let replacement = VaultEncryptedVideo(
      id: UUID().uuidString, movementID: original.movementID,
      metadata: Data(repeating: 8, count: 64), thumbnail: original.thumbnail,
      byteCount: original.byteCount)
    try await fill(replacement)
    try await repo.updateVideo(
      id: original.id, encrypted: Data(repeating: 9, count: 64), lease: lease)
    do {
      try await repo.finishVideo(
        id: replacement.id, replacing: original.id, expectedMetadata: original.metadata,
        lease: lease)
      XCTFail("Stale replacement committed")
    } catch {}
    let unchanged = try await repo.videoMetadata(lease: lease)
    XCTAssertEqual(unchanged.map(\.id), [original.id])
    try await repo.finishVideo(
      id: replacement.id, replacing: original.id,
      expectedMetadata: Data(repeating: 9, count: 64), lease: lease)
    let complete = try await repo.videoMetadata(lease: lease)
    XCTAssertEqual(complete.map(\.id), [replacement.id])
    do {
      _ = try await repo.videoChunk(id: original.id, index: 0, lease: lease)
      XCTFail("Old chunks remain")
    } catch {}
  }
}

extension VaultVideoTests {
  func testDayStacksKeepSameDayClipsAndIsolateMovements() throws {
    let movement = UUID().uuidString
    func video(_ day: String, _ time: Int, _ owner: String) -> VaultVideoEntry {
      VaultVideoEntry(
        id: UUID().uuidString,
        metadata: .init(
          dayKey: day, movementID: owner,
          type: "public.mpeg-4", duration: 4, byteCount: 10, importedAt: time))
    }
    let first = video("2026-10-24", 1, movement)
    let second = video("2026-10-24", 2, movement)
    let older = video("2026-10-23", 3, movement)
    let unrelated = video("2026-10-24", 4, UUID().uuidString)
    let days = VaultVideoDay.grouped([first, unrelated, older, second], movementID: movement)
    XCTAssertEqual(days.map(\.id), ["2026-10-24", "2026-10-23"])
    XCTAssertEqual(days.first?.videos.map(\.id), [second.id, first.id])
    XCTAssertEqual(days.last?.videos.map(\.id), [older.id])
    var legacy =
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(first.metadata)) as! [String: Any]
    legacy.removeValue(forKey: "audioRemoved")
    let restored = try JSONDecoder().decode(
      VaultVideoMetadata.self, from: JSONSerialization.data(withJSONObject: legacy))
    XCTAssertNil(restored.audioRemoved)
  }
}

extension VaultVideoTests {
  func testReplacementAtVideoLimitDoesNotIncreasePublishedLimit() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let (repo, lease, source) = try await setupVideo(path: path)
    let db = try SQLiteDatabase(path: path)
    try db.transaction {
      for index in 0..<5000 {
        try db.execute(
          "INSERT INTO vault_videos VALUES(?,?,?,?,?,?,1)",
          [
            .text(index == 0 ? source.id : UUID().uuidString), .text(source.movementID),
            .blob(source.metadata), .blob(source.thumbnail), .integer(source.byteCount),
            .text(lease.id.uuidString),
          ])
      }
    }
    let candidate = VaultEncryptedVideo(
      id: UUID().uuidString, movementID: source.movementID,
      metadata: source.metadata, thumbnail: source.thumbnail, byteCount: source.byteCount)
    do {
      try await repo.beginVideo(candidate, lease: lease)
      XCTFail("Ordinary import exceeded limit")
    } catch {}
    try await repo.beginVideo(
      candidate, replacing: source.id, expectedMetadata: source.metadata, lease: lease)
    try await repo.appendVideoChunk(
      id: candidate.id, index: 0,
      encrypted: Data(repeating: 5, count: VaultVideoLimits.chunkBytes + 28), lease: lease)
    try await repo.appendVideoChunk(
      id: candidate.id, index: 1,
      encrypted: Data(repeating: 6, count: 35), lease: lease)
    do {
      try await repo.finishVideo(id: candidate.id, lease: lease)
      XCTFail("Replacement bypassed published limit")
    } catch {}
    try await repo.finishVideo(
      id: candidate.id, replacing: source.id, expectedMetadata: source.metadata, lease: lease)
    let result = try await repo.videoMetadata(lease: lease)
    XCTAssertEqual(result.count, 5000)
    XCTAssertFalse(result.contains { $0.id == source.id })
    XCTAssertTrue(result.contains { $0.id == candidate.id })
  }
}
