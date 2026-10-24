import Foundation

extension RepsRepository {
  public func bodyWeightMeasurements() throws -> [BodyWeightMeasurement] {
    try database.query("SELECT * FROM body_weight_measurements ORDER BY day_key,id").map(
      readBodyWeight)
  }

  func readBodyWeight(_ row: SQLRow) throws -> BodyWeightMeasurement {
    BodyWeightMeasurement(
      id: try row.text("id"), dayKey: try row.text("day_key"), grams: try row.integer("grams"))
  }

  public func saveBodyWeight(
    _ proposed: BodyWeightMeasurement, original: BodyWeightMeasurement?, now: Int,
    calendar: Calendar = .current
  ) throws {
    _ = try proposed.validated(now: now, calendar: calendar)
    try database.transaction {
      let current = try database.query(
        "SELECT * FROM body_weight_measurements WHERE id=?", [.text(proposed.id)]
      ).first.map(readBodyWeight)
      guard original.map({ $0.id == proposed.id }) ?? true, current == original else {
        throw TrainingError.invalid("This measurement has changed. Open it again before saving.")
      }
      let occupied = try database.query(
        "SELECT id FROM body_weight_measurements WHERE day_key=? AND id!=?",
        [.text(proposed.dayKey), .text(proposed.id)])
      guard occupied.isEmpty else {
        throw TrainingError.invalid("A weight is already recorded for this date. Open it to edit.")
      }
      try database.execute(
        original == nil
          ? "INSERT INTO body_weight_measurements(day_key,grams,id) VALUES(?,?,?)"
          : "UPDATE body_weight_measurements SET day_key=?,grams=? WHERE id=?",
        [.text(proposed.dayKey), .integer(proposed.grams), .text(proposed.id)])
    }
  }

  public func deleteBodyWeight(_ original: BodyWeightMeasurement) throws {
    try database.transaction {
      let current = try database.query(
        "SELECT * FROM body_weight_measurements WHERE id=?", [.text(original.id)]
      ).first.map(readBodyWeight)
      guard current == original else {
        throw TrainingError.invalid("This measurement has changed. Open it again before deleting.")
      }
      try database.execute("DELETE FROM body_weight_measurements WHERE id=?", [.text(original.id)])
    }
  }
}
