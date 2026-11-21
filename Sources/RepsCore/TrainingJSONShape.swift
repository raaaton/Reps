import Foundation

extension TrainingTransfer {
  // Closed format: unknown fields are rejected, rather than silently discarding future/private data.
  static func checkJSONShape(_ data: Data) throws {
    let root = try JSONSerialization.jsonObject(with: data)
    let archiveVersion = (root as? [String: Any])?["version"] as? Int
    let hasVariants = archiveVersion == 11
    let hasArchives = archiveVersion == 10 || hasVariants
    let hasBackpack = archiveVersion == 9 || hasArchives
    let hasMaximum = archiveVersion == 8 || hasBackpack
    let hasQuantities = archiveVersion == 7 || hasMaximum
    let hasSkills = archiveVersion == 6 || hasQuantities
    func object(_ raw: Any, _ allowed: [String]) throws -> [String: Any] {
      guard let value = raw as? [String: Any], Set(value.keys).isSubset(of: Set(allowed)) else {
        throw invalid
      }
      return value
    }
    func array(_ raw: Any?) throws -> [Any] {
      guard let values = raw as? [Any] else { throw invalid }
      return values
    }
    func variant(_ raw: Any) throws {
      _ = try object(
        raw,
        [
          "id", "exerciseID", "name", "measure", "unit", "tracking", "minimumReps", "maximumReps",
          "durationSeconds", "isArchived",
        ])
    }
    func definition(_ raw: Any) throws {
      let value = try object(
        raw,
        [
          "id", "name", "tracking", "setCount", "minimumReps", "maximumReps", "durationSeconds",
          "isEnabled",
        ] + (hasVariants ? ["variant"] : []))
      if let raw = value["variant"], !(raw is NSNull) { try variant(raw) }
    }
    func components(_ raw: Any?) throws {
      guard let raw, !(raw is NSNull) else { return }
      for component in try array(raw) {
        _ = try object(
          component, ["id", "name", "grams"] + (hasQuantities ? ["quantity"] : []))
      }
    }
    func goal(_ raw: Any?) throws {
      guard let raw, !(raw is NSNull) else { return }
      let value = try object(
        raw,
        ["definition", "load", "repetitions"]
          + (archiveVersion == 4 || archiveVersion == 5 || hasSkills
            ? ["durationsMS"] : []))
      try definition(value["definition"] ?? NSNull())
      let load = try object(value["load"] ?? NSNull(), ["grams", "components"])
      try components(load["components"])
    }
    let envelope = try object(
      root, ["format", "version", "includesPrivatePhotos", "createdAt", "contents"])
    let contents = try object(
      envelope["contents"] ?? NSNull(),
      ["configuration", "notifications", "workouts", "bodyWeights"]
        + (hasSkills ? ["skillSessions"] : []))
    let c = try object(
      contents["configuration"] ?? NSNull(),
      ["exercises", "schedules", "restSeconds", "weightItems", "goals", "stretchingEnabled"]
        + (hasSkills ? ["skills", "skillProgress"] : [])
        + (hasMaximum ? ["maximumWeightObjects"] : [])
        + (hasBackpack ? ["backpackWeightGrams"] : [])
        + (hasArchives ? ["archivedExercises"] : [])
        + (hasVariants
          ? ["variants", "variantGoals", "identityAliases", "completedExerciseMerges"] : []))
    if hasVariants {
      for raw in try array(c["variants"]) { try variant(raw) }
      for raw in try array(c["variantGoals"]) {
        let item = try object(raw, ["variantID", "scheduleID", "goal"])
        try goal(item["goal"])
      }
      for raw in try array(c["identityAliases"]) {
        _ = try object(raw, ["sourceID", "exerciseID", "variantID"])
      }
      guard c["completedExerciseMerges"] is [String] else { throw invalid }
    }
    if hasMaximum, c["maximumWeightObjects"] == nil { throw invalid }
    if hasBackpack, c["backpackWeightGrams"] == nil { throw invalid }
    if archiveVersion == 5 || hasSkills, !(c["stretchingEnabled"] is Bool) {
      throw invalid
    }
    if hasSkills {
      for raw in try array(c["skills"]) { try SkillTransfer.checkShape(definition: raw) }
      for raw in try array(c["skillProgress"]) { try SkillTransfer.checkShape(progress: raw) }
      for raw in try array(contents["skillSessions"]) {
        try SkillTransfer.checkShape(practice: raw)
      }
    }
    for ex in try array(c["exercises"]) { try definition(ex) }
    if hasArchives {
      for ex in try array(c["archivedExercises"]) { try definition(ex) }
    }
    for schedule in try array(c["schedules"]) {
      let value = try object(
        schedule,
        [
          "id", "name", "weekday", "isEnabled", "reminderMinutes", "exerciseIDs", "setCounts",
          "goals",
        ] + (hasSkills ? ["skills", "skillPlacement"] : [])
          + (hasVariants ? ["variantIDs", "baseGoals"] : []))
      if hasSkills {
        for block in try array(value["skills"]) { try SkillTransfer.checkShape(assignment: block) }
      }
      if let baseGoals = value["baseGoals"] as? [String: Any] {
        for item in baseGoals.values { try goal(item) }
      }
      if let goals = value["goals"] as? [String: Any] {
        for item in goals.values { try goal(item) }
      }
    }
    for item in try array(c["weightItems"]) {
      _ = try object(
        item, ["id", "name", "grams", "isEnabled"] + (hasQuantities ? ["quantity"] : []))
    }
    for item in try array(c["goals"]) { try goal(item) }
    let notifications = try object(
      contents["notifications"] ?? NSNull(),
      [
        "workoutsEnabled", "photosEnabled", "photoMinutes", "weightEnabled", "weightWeekday",
        "weightMinutes",
      ])
    if archiveVersion == 3 || archiveVersion == 4 || archiveVersion == 5 || hasSkills {
      guard contents["bodyWeights"] is [Any], notifications["weightEnabled"] is Bool else {
        throw invalid
      }
    }
    if let weights = contents["bodyWeights"] {
      for weight in try array(weights) { _ = try object(weight, ["id", "dayKey", "grams"]) }
    }
    for raw in try array(contents["workouts"]) {
      let w = try object(
        raw,
        [
          "id", "scheduleID", "name", "dayKey", "startedAt", "endedAt", "status", "restSeconds",
          "exercises", "rest", "support",
        ] + (hasSkills ? ["skills"] : []))
      if let raw = w["skills"], !(raw is NSNull) { try SkillTransfer.checkShape(workout: raw) }
      if let raw = w["rest"], !(raw is NSNull) {
        _ = try object(raw, ["id", "exerciseID", "afterSet", "status", "deadline", "remainingMS"])
      }
      if let raw = w["support"], !(raw is NSNull) {
        let support = try object(raw, ["steps", "restID", "restAnchorID"])
        let steps = try array(support["steps"])
        guard steps.count <= 4 else { throw invalid }
        for step in steps {
          _ = try object(
            step,
            [
              "id", "kind", "name", "instructions", "number", "count", "tracking",
              "targetRepetitions", "targetDurationMS", "restAfterMS", "startedAt", "completedAt",
              "repetitions", "durationMS",
            ])
        }
      }
      for raw in try array(w["exercises"]) {
        let e = try object(
          raw,
          [
            "id", "definition", "sets", "feelingTenths", "setStartedAt", "setWeightGrams",
            "setEndedAt", "setComponents", "goal", "variantSelectionLocked",
          ])
        try definition(e["definition"] ?? NSNull())
        try components(e["setComponents"])
        try goal(e["goal"])
        for raw in try array(e["sets"]) {
          let set = try object(
            raw,
            [
              "id", "number", "repetitions", "durationMS", "weightGrams", "completedAt",
              "components",
            ])
          try components(set["components"])
        }
      }
    }
  }
}
