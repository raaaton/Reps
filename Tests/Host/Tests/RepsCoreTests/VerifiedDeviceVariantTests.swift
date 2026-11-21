import Foundation
import XCTest

@testable import RepsCore

final class VerifiedDeviceVariantTests: XCTestCase, @unchecked Sendable {
  func testVerifiedPersonalCopyPreservesEverySessionSetRestAndDecision() async throws {
    guard let original = ProcessInfo.processInfo.environment["REPS_VARIANT_COPY_TEST"] else {
      throw XCTSkip("Requires an explicitly supplied coherent training-only device copy")
    }
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("training.sqlite").path
    try FileManager.default.copyItem(atPath: original, toPath: path)
    let database = try SQLiteDatabase(path: path)
    let preserved = ["workouts", "workout_sets", "workout_rests", "workout_goal_decisions"]
    func rows(_ table: String) throws -> String {
      try database.query("SELECT * FROM \(table) ORDER BY rowid").map { row in
        row.values.keys.sorted().map { key in "\(key)=\(String(describing: row.values[key]!))" }
          .joined(separator: "|")
      }.joined(separator: "\n")
    }
    let before = try preserved.map(rows)
    let repository = try RepsRepository(path: path)
    let snapshot = try await repository.snapshot()
    XCTAssertEqual(try preserved.map(rows), before)
    let l = try await repository.exerciseHistory(exerciseID: "l-sit", variantID: "l-sit:base")
    let v = try await repository.exerciseHistory(
      exerciseID: "l-sit", variantID: "45152DC5-7A8E-4E29-AB6D-BD2AD7011AC6:base")
    XCTAssertEqual(l.count, 6)
    XCTAssertEqual(v.count, 1)
    XCTAssertEqual(snapshot.exercises.filter { $0.name == "L-sit" }.count, 1)
    XCTAssertFalse(snapshot.exercises.contains { $0.name == "V-sit" })
    let parent = try XCTUnwrap(snapshot.exercises.first { $0.id == "l-sit" })
    XCTAssertFalse(snapshot.needsGoalReview(for: parent, availableLoads: [.bodyweight]))
    XCTAssertNotNil(snapshot.primaryGoal(for: parent))
    let targets = snapshot.workoutTargets(for: parent)
    XCTAssertEqual(targets.count, 1)
    XCTAssertEqual(targets.first?.exercise.variantDisplayName, "V-sit")
    let archive = try await repository.exportTraining(now: WorkoutClock.now)
    _ = try TrainingArchive.decode(archive.encoded())
    let reopened = try RepsRepository(path: path)
    let again = try await reopened.snapshot()
    XCTAssertEqual(again, snapshot)
    let recovery = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter {
      $0.contains("before-lsit")
    }
    XCTAssertEqual(recovery.count, 1)
  }
}
