import Foundation

/// Only the two explicit identities verified in a recovery copy are accepted.
/// This is an internal delivery operation, with no general-purpose merge UI.
public struct LSitMergeManifest: Codable, Equatable, Sendable {
  public let lSitID: String
  public let vSitID: String
  public init(lSitID: String, vSitID: String) {
    self.lSitID = lSitID
    self.vSitID = vSitID
  }
  var operationID: String { "lsit-vsit:" + lSitID + ":" + vSitID }
}

extension RepsRepository {
  @discardableResult
  public func mergeLSitAndVSit(_ manifest: LSitMergeManifest, recoveryPath: String) throws -> Bool {
    try TrainingText.validate(name: "L-sit", id: manifest.lSitID)
    try TrainingText.validate(name: "V-sit", id: manifest.vSitID)
    guard manifest.lSitID != manifest.vSitID else {
      throw TrainingError.invalid("The source identities must be different.")
    }
    if try mergeAlreadyApplied(manifest) { return false }
    let before = try readSnapshot()
    guard
      let lSit = (before.exercises + before.archivedExercises).first(where: {
        $0.id == manifest.lSitID
      }),
      let vSit = (before.exercises + before.archivedExercises).first(where: {
        $0.id == manifest.vSitID
      }),
      lSit.tracking == .duration, vSit.tracking == .duration
    else { throw TrainingError.invalid("The verified L-sit and V-sit identities are unavailable.") }
    if try mergeHasActiveWorkout(manifest) { return false }
    // sqlite3_backup copies the complete database consistently, including rest and
    // decision rows not represented by the user-facing training export.
    try database.recoveryCopy(to: recoveryPath)
    return try database.transaction {
      if try mergeAlreadyApplied(manifest) { return false }
      if try mergeHasActiveWorkout(manifest) { return false }
      guard try readSnapshot() == before else {
        throw TrainingError.invalid(
          "Training data changed before the merge. Retry with a new recovery copy.")
      }
      var parent = lSit
      parent.name = "L-sit"
      parent.isEnabled = true
      try database.execute("DELETE FROM archived_exercises WHERE id=?", [.text(parent.id)])
      if !before.exercises.contains(where: { $0.id == parent.id }) {
        try database.execute(
          "INSERT INTO exercises VALUES(?,?,?,?,?,?,?,?,(SELECT COALESCE(MAX(position),-1)+1 FROM exercises))",
          [
            .text(parent.id), .text(parent.name), .text(parent.tracking.rawValue),
            .integer(parent.setCount), parent.minimumReps.map(SQLValue.integer) ?? .null,
            parent.maximumReps.map(SQLValue.integer) ?? .null,
            parent.durationSeconds.map(SQLValue.integer) ?? .null, .integer(1),
          ])
      } else {
        try database.execute(
          "UPDATE exercises SET name='L-sit',enabled=1 WHERE id=?", [.text(parent.id)])
      }
      var lVariant = ExerciseVariant.base(for: parent)
      lVariant.name = "L-sit"
      var vVariant = ExerciseVariant.base(for: vSit)
      vVariant.exerciseID = parent.id
      vVariant.name = "V-sit"
      vVariant.isArchived = false
      try writeVariant(lVariant)
      try writeVariant(vVariant)
      for (source, variant) in [(lSit, lVariant), (vSit, vVariant)] {
        try database.execute(
          "INSERT INTO exercise_identity_aliases VALUES(?,?,?) ON CONFLICT(source_id) DO UPDATE SET exercise_id=excluded.exercise_id,variant_id=excluded.variant_id",
          [.text(source.id), .text(parent.id), .text(variant.id)])
        for row in try database.query(
          "SELECT * FROM workout_exercises WHERE catalogue_id=?", [.text(source.id)])
        {
          let occurrence = try readExercise(row)
          var frozen = occurrence.definition
          var metadata = variant
          metadata.tracking = frozen.tracking
          metadata.minimumReps = frozen.minimumReps
          metadata.maximumReps = frozen.maximumReps
          metadata.durationSeconds = frozen.durationSeconds
          frozen.variant = metadata
          try writeWorkoutVariant(frozen, occurrenceID: occurrence.id, locked: true)
        }
        for row in try database.query(
          "SELECT schedule_id,goal_payload FROM schedule_exercises WHERE exercise_id=?",
          [.text(source.id)])
        {
          if let payload = try row.optionalText("goal_payload") {
            let old = try ExerciseGoal.decode(payload)
            var definition = variant.applying(to: parent)
            definition.setCount = old.definition.setCount
            let goal = ExerciseGoal(
              definition: definition, load: old.load, repetitions: old.repetitions,
              durationsMS: old.durationsMS)
            try database.execute(
              "INSERT INTO variant_goals VALUES(?,?,?) ON CONFLICT(variant_id,schedule_id) DO UPDATE SET payload=excluded.payload",
              [
                .text(variant.id), .text(try row.text("schedule_id")),
                try ExerciseGoal.encode(goal),
              ])
          }
        }
        if let old = try database.query(
          "SELECT payload FROM exercise_goals WHERE catalogue_id=?", [.text(source.id)]
        ).first.map({ try ExerciseGoal.decode($0.text("payload")) }) {
          var definition = variant.applying(to: parent)
          definition.setCount = old.definition.setCount
          let goal = ExerciseGoal(
            definition: definition, load: old.load, repetitions: old.repetitions,
            durationsMS: old.durationsMS)
          try database.execute(
            "INSERT INTO variant_goals VALUES(?,?,?) ON CONFLICT(variant_id,schedule_id) DO UPDATE SET payload=excluded.payload",
            [.text(variant.id), .text(""), try ExerciseGoal.encode(goal)])
        }
      }
      let assignments = try database.query(
        "SELECT * FROM schedule_exercises WHERE exercise_id=?", [.text(vSit.id)])
      for assignment in assignments {
        let scheduleID = try assignment.text("schedule_id")
        let hasParent =
          !(try database.query(
            "SELECT 1 FROM schedule_exercises WHERE schedule_id=? AND exercise_id=?",
            [.text(scheduleID), .text(parent.id)])).isEmpty
        let slotID = hasParent ? vSit.id : parent.id
        if !hasParent {
          try database.execute(
            "DELETE FROM schedule_variants WHERE schedule_id=? AND exercise_id=?",
            [.text(scheduleID), .text(vSit.id)])
          try database.execute(
            "UPDATE schedule_exercises SET exercise_id=?,goal_payload=NULL WHERE schedule_id=? AND exercise_id=?",
            [.text(parent.id), .text(scheduleID), .text(vSit.id)])
        }
        try database.execute(
          "INSERT INTO schedule_variants VALUES(?,?,?) ON CONFLICT(schedule_id,exercise_id) DO UPDATE SET variant_id=excluded.variant_id",
          [.text(scheduleID), .text(slotID), .text(vVariant.id)])
      }
      // A remaining source row is only an assignment slot when a program contains
      // both variants. It is hidden from the exercise catalogue through the alias.
      if try database.query(
        "SELECT 1 FROM schedule_exercises WHERE exercise_id=?", [.text(vSit.id)]
      ).isEmpty {
        try database.execute("DELETE FROM exercises WHERE id=?", [.text(vSit.id)])
      }
      try database.execute("DELETE FROM archived_exercises WHERE id=?", [.text(vSit.id)])
      try database.execute(
        "INSERT INTO targeted_exercise_merges VALUES(?,?)",
        [.text(manifest.operationID), try ExerciseVariantSchema.encode(manifest)])
      return true
    }
  }
  private func mergeAlreadyApplied(_ manifest: LSitMergeManifest) throws -> Bool {
    !(try database.query(
      "SELECT 1 FROM targeted_exercise_merges WHERE id=?", [.text(manifest.operationID)])).isEmpty
  }
  private func mergeHasActiveWorkout(_ manifest: LSitMergeManifest) throws -> Bool {
    !(try database.query(
      "SELECT 1 FROM workout_exercises e JOIN workouts w ON w.id=e.workout_id WHERE w.status='active' AND e.catalogue_id IN (?,?)",
      [.text(manifest.lSitID), .text(manifest.vSitID)])).isEmpty
  }
}

extension RepsRepository {
  // Exact identities read from a coherent schema-21 USB copy on 21 November 2026.
  // Other installations and newly-created exercises never match this manifest.
  func applyVerifiedLSitMergeIfNeeded() throws {
    let manifest = LSitMergeManifest(
      lSitID: "l-sit", vSitID: "45152DC5-7A8E-4E29-AB6D-BD2AD7011AC6")
    guard databasePath != ":memory:", !(try mergeAlreadyApplied(manifest)) else { return }
    let snapshot = try readSnapshot()
    let identities = Set((snapshot.exercises + snapshot.archivedExercises).map(\.id))
    guard identities.contains(manifest.lSitID), identities.contains(manifest.vSitID) else { return }
    _ = try mergeLSitAndVSit(
      manifest, recoveryPath: databasePath + ".before-lsit-" + UUID().uuidString + ".sqlite")
  }
}
