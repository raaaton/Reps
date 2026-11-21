import Foundation
import XCTest

@testable import RepsCore

final class ExerciseVariantTests: XCTestCase, @unchecked Sendable {
  func testBaseMigrationAndReopeningAreIdempotent() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try RepsRepository(path: path)
    let before = try await repository.snapshot()
    XCTAssertEqual(before.variants.count, before.exercises.count)
    XCTAssertEqual(Set(before.variants.map(\.id)).count, before.variants.count)
    let reopened = try RepsRepository(path: path)
    let after = try await reopened.snapshot()
    XCTAssertEqual(before, after)
    for exercise in before.exercises {
      XCTAssertEqual(before.variants.filter { $0.exerciseID == exercise.id }.count, 1)
    }
  }

  func testMeasuresAcceptBothDecimalSeparatorsWithoutConvertingUnits() throws {
    XCTAssertEqual(try VariantMeasure.parse("15,50"), "15.5")
    XCTAssertEqual(try VariantMeasure.parse("0.125"), "0.125")
    XCTAssertEqual(try VariantMeasure.parse(""), nil)
    for invalid in ["NaN", "1,2.3", "1e3", "-3", "1 000", "inf"] {
      XCTAssertThrowsError(try VariantMeasure.parse(invalid))
    }
    var variant = ExerciseVariant.base(for: exercise())
    variant.id = "hands-15"
    variant.name = "Mains surélevées"
    variant.measure = "15.5"
    variant.unit = "cm libres"
    XCTAssertEqual(try variant.validated().unit, "cm libres")
    variant.unit = " "
    XCTAssertThrowsError(try variant.validated())
    variant.measure = nil
    variant.unit = nil
    XCTAssertNoThrow(try variant.validated())
  }

  func testNamedVariantsKeepIndependentSettingsAndScheduleSetCount() async throws {
    let repository = try RepsRepository(path: ":memory:")
    let initial = try await repository.snapshot()
    let parent = try XCTUnwrap(initial.exercises.first { $0.id == "push-ups" })
    var a = ExerciseVariant.base(for: parent)
    a.id = "hands-15"
    a.name = "Mains surélevées"
    a.measure = "15"
    a.unit = "cm"
    a.minimumReps = 3
    a.maximumReps = 6
    var b = a
    b.id = "hands-20"
    b.measure = "20"
    b.minimumReps = 7
    b.maximumReps = 9
    try await repository.saveVariant(a)
    try await repository.saveVariant(b)
    var schedule = try XCTUnwrap(initial.schedules.first { $0.id == "push" })
    schedule.setCounts[parent.id] = 5
    schedule.variantIDs[parent.id] = a.id
    try await repository.saveSchedule(schedule)
    let saved = try await repository.snapshot()
    let savedSchedule = try XCTUnwrap(saved.schedules.first { $0.id == "push" })
    let target = try XCTUnwrap(saved.exercises(for: savedSchedule).first { $0.id == parent.id })
    XCTAssertEqual(target.variantID, a.id)
    XCTAssertEqual(target.minimumReps, 3)
    XCTAssertEqual(target.setCount, 5)
    XCTAssertEqual(saved.variants.first { $0.id == b.id }?.minimumReps, 7)
    try await repository.archiveVariant(id: a.id)
    let archived = try await repository.snapshot()
    XCTAssertTrue(try XCTUnwrap(archived.variants.first { $0.id == a.id }).isArchived)
    XCTAssertEqual(archived.schedules.first { $0.id == "push" }?.variantIDs[parent.id], a.id)
  }

  private func exercise() -> TrainingExercise {
    TrainingExercise(
      id: "test", name: "Test", tracking: .repetitions, setCount: 4,
      minimumReps: 8, maximumReps: 12, durationSeconds: nil, isEnabled: true)
  }
}

extension ExerciseVariantTests {
  func testParentRenamePreservesCustomBaseMetadata() async throws {
    let repository = try RepsRepository(path: ":memory:")
    let snapshot = try await repository.snapshot()
    var parent = try XCTUnwrap(snapshot.exercises.first { $0.id == "push-ups" })
    var base = ExerciseVariant.base(for: parent)
    base.name = "Custom base"
    base.measure = "15"
    base.unit = "cm"
    try await repository.saveVariant(base)
    parent.name = "Renamed parent"
    try await repository.saveExercise(parent)
    let after = try await repository.snapshot()
    XCTAssertEqual(after.variants.first { $0.id == base.id }?.name, "Custom base")
    XCTAssertEqual(after.variants.first { $0.id == base.id }?.measure, "15")
    XCTAssertEqual(after.variants.first { $0.id == base.id }?.unit, "cm")
  }
}
