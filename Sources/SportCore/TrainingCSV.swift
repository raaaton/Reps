import Foundation

public enum TrainingCSV {
  public static let columns = [
    "sport_csv_version", "row_type", "workout_id", "workout_name", "date", "status", "schedule_id",
    "started_at_ms", "ended_at_ms", "rest_seconds", "exercise_id", "catalogue_id", "exercise_name",
    "mode", "set_count", "min_reps", "max_reps", "duration_target_seconds", "feeling", "set_id",
    "set_number", "repetitions", "duration_seconds", "weight_kg", "completed_at_ms",
    "components_json", "goal_json", "pending_start_ms", "pending_weight_kg", "pending_end_ms",
    "pending_components_json", "support_json",
  ]
  private static func decimal(_ value: Int) -> String {
    let fraction = value % 1000
    return fraction == 0
      ? String(value / 1000) : String(value / 1000) + "." + String(format: "%03d", fraction)
  }
  private static func json<T: Encodable>(_ value: T?) throws -> String {
    guard let value else { return "" }
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return String(decoding: try encoder.encode(value), as: UTF8.self)
  }
  private static func requiresProtection(_ value: String) -> Bool {
    guard let first = value.first else { return false }
    if "'=+-@\t\r\n".contains(first) { return true }
    return value.trimmingCharacters(in: .whitespacesAndNewlines).first.map { "=+-@".contains($0) }
      ?? false
  }
  private static func protected(_ value: String) -> String {
    requiresProtection(value) ? "'" + value : value
  }
  private static func unprotected(_ value: String) -> String {
    guard value.first == "'", requiresProtection(String(value.dropFirst())) else { return value }
    return String(value.dropFirst())
  }
  public static func encode(_ workouts: [WorkoutSession]) throws -> Data {
    try TrainingTransfer.workouts(workouts)
    var output = "\u{feff}"
    var count = 3
    func append(_ row: [String]) throws {
      let line =
        row.map { "\"" + protected($0).replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(
          separator: ",") + "\r\n"
      guard line.utf8.count <= TrainingTransfer.maximumBytes - count else {
        throw TrainingTransfer.invalid
      }
      count += line.utf8.count
      output.append(line)
    }
    try append(columns)
    for w in workouts {
      let base = [
        "2", "workout", w.id, w.name, w.dayKey, w.status.rawValue, w.scheduleID,
        String(w.startedAt), w.endedAt.map(String.init) ?? "", String(w.restSeconds),
      ]
      if w.exercises.isEmpty {
        try append(base + Array(repeating: "", count: columns.count - base.count))
      }
      for e in w.exercises {
        let d = e.definition
        var row =
          base + [
            e.id, d.id, d.name, d.tracking.rawValue, String(d.setCount),
            d.minimumReps.map(String.init) ?? "", d.maximumReps.map(String.init) ?? "",
            d.durationSeconds.map(String.init) ?? "",
            e.feelingTenths.map { String($0 / 10) + "." + String($0 % 10) } ?? "",
          ] + Array(repeating: "", count: 13)
        row[1] = "exercise"
        row[26] = try json(e.goal)
        row[27] = e.setStartedAt.map(String.init) ?? ""
        row[28] = e.setWeightGrams.map(decimal) ?? ""
        row[29] = e.setEndedAt.map(String.init) ?? ""
        row[30] = try json(e.setComponents)
        row[31] = try json(w.support)
        if e.sets.isEmpty { try append(row) }
        for set in e.sets {
          var line = row
          line[1] = "set"
          line[19] = set.id
          line[20] = String(set.number)
          line[21] = set.repetitions.map(String.init) ?? ""
          line[22] = set.durationMS.map(decimal) ?? ""
          line[23] = decimal(set.weightGrams)
          line[24] = String(set.completedAt)
          line[25] = try json(set.components)
          try append(line)
        }
      }
    }
    let data = Data(output.utf8)
    return data
  }
  public static func decode(_ data: Data) throws -> [WorkoutSession] {
    var rows = try parse(data)
    if rows.first == Array(columns.dropLast()) {
      rows = rows.map { $0 + [""] }
      rows[0] = columns
    }
    guard rows.first == columns else { throw TrainingTransfer.invalid }
    let records = Array(rows.dropFirst()).map { $0.map(unprotected) }
    guard
      records.allSatisfy({
        $0.count == columns.count && ["1", "2"].contains($0[0])
          && ["set", "exercise", "workout"].contains($0[1])
      })
    else { throw TrainingTransfer.invalid }
    var order: [String] = []
    var grouped: [String: [[String]]] = [:]
    for row in records {
      if grouped[row[2]] == nil { order.append(row[2]) }
      grouped[row[2], default: []].append(row)
    }
    var result: [WorkoutSession] = []
    for id in order {
      let group = grouped[id]!
      let first = group[0]
      guard group.allSatisfy({ Array($0[2...9]) == Array(first[2...9]) && $0[31] == first[31] }),
        let status = WorkoutStatus(rawValue: first[5])
      else { throw TrainingTransfer.invalid }
      var exOrder: [String] = []
      var exGroups: [String: [[String]]] = [:]
      for row in group {
        if row[1] == "workout" {
          guard group.count == 1, row[10...].allSatisfy(\.isEmpty) else {
            throw TrainingTransfer.invalid
          }
          continue
        }
        if exGroups[row[10]] == nil { exOrder.append(row[10]) }
        exGroups[row[10], default: []].append(row)
      }
      var exercises: [WorkoutExercise] = []
      for exID in exOrder {
        let lines = exGroups[exID]!
        let ex = lines[0]
        guard
          lines.allSatisfy({
            Array($0[10...18]) == Array(ex[10...18]) && Array($0[26...30]) == Array(ex[26...30])
          }), let mode = TrackingMode(rawValue: ex[13])
        else { throw TrainingTransfer.invalid }
        let definition = TrainingExercise(
          id: ex[11], name: ex[12], tracking: mode, setCount: try integer(ex[14]),
          minimumReps: try optionalInteger(ex[15]), maximumReps: try optionalInteger(ex[16]),
          durationSeconds: try optionalInteger(ex[17]), isEnabled: true)
        var sets: [WorkoutSet] = []
        for row in lines {
          if row[1] == "exercise" {
            guard lines.count == 1, row[19...25].allSatisfy(\.isEmpty) else {
              throw TrainingTransfer.invalid
            }
          } else {
            sets.append(
              WorkoutSet(
                id: row[19], number: try integer(row[20]),
                repetitions: try optionalInteger(row[21]), durationMS: try scaled(row[22]),
                weightGrams: try requiredScaled(row[23]), completedAt: try integer(row[24]),
                components: try decodeJSON(row[25])))
          }
        }
        exercises.append(
          WorkoutExercise(
            id: exID, definition: definition, sets: sets.sorted { $0.number < $1.number },
            feelingTenths: ex[18].isEmpty ? nil : try WorkoutFeeling.tenths(ex[18]),
            setStartedAt: try optionalInteger(ex[27]), setWeightGrams: try scaled(ex[28]),
            setEndedAt: try optionalInteger(ex[29]), setComponents: try decodeJSON(ex[30]),
            goal: try decodeJSON(ex[26])))
      }
      result.append(
        WorkoutSession(
          id: id, scheduleID: first[6], name: first[3], dayKey: first[4],
          startedAt: try integer(first[7]), endedAt: try optionalInteger(first[8]), status: status,
          restSeconds: try integer(first[9]), exercises: exercises, rest: nil,
          support: try decodeJSON(first[31])))
    }
    try TrainingTransfer.workouts(result)
    return result
  }
  private static func integer(_ value: String) throws -> Int {
    guard !value.isEmpty, value.utf8.allSatisfy({ (48...57).contains($0) }), let number = Int(value)
    else { throw TrainingTransfer.invalid }
    return number
  }
  private static func optionalInteger(_ value: String) throws -> Int? {
    value.isEmpty ? nil : try integer(value)
  }
  private static func scaled(_ value: String) throws -> Int? {
    value.isEmpty ? nil : try WorkoutWeight.grams(value)
  }
  private static func requiredScaled(_ value: String) throws -> Int {
    guard let result = try scaled(value) else { throw TrainingTransfer.invalid }
    return result
  }
  private static func decodeJSON<T: Decodable>(_ value: String) throws -> T? {
    if value.isEmpty { return nil }
    do { return try JSONDecoder().decode(T.self, from: Data(value.utf8)) } catch {
      throw TrainingTransfer.invalid
    }
  }
  private static func parse(_ data: Data) throws -> [[String]] {
    guard data.count <= TrainingTransfer.maximumBytes, String(data: data, encoding: .utf8) != nil
    else { throw TrainingTransfer.invalid }
    var bytes = Array(data)
    if bytes.starts(with: [239, 187, 191]) { bytes.removeFirst(3) }
    var rows: [[String]] = []
    var row: [String] = []
    var field: [UInt8] = []
    var quoted = false
    var closed = false
    var index = 0
    func finishField() throws {
      guard row.count < columns.count else { throw TrainingTransfer.invalid }
      row.append(String(decoding: field, as: UTF8.self))
      field.removeAll(keepingCapacity: true)
      closed = false
    }
    func finishRow() throws {
      try finishField()
      if let header = rows.first {
        guard row.count == header.count else { throw TrainingTransfer.invalid }
      } else {
        guard row.count == columns.count || row.count == columns.count - 1 else {
          throw TrainingTransfer.invalid
        }
      }
      rows.append(row)
      row.removeAll(keepingCapacity: true)
      guard rows.count <= 100001 else { throw TrainingTransfer.invalid }
    }
    while index < bytes.count {
      let byte = bytes[index]
      if quoted {
        if byte == 34 {
          if index + 1 < bytes.count && bytes[index + 1] == 34 {
            field.append(34)
            index += 1
          } else {
            quoted = false
            closed = true
          }
        } else {
          field.append(byte)
        }
      } else {
        switch byte {
        case 34:
          guard field.isEmpty, !closed else { throw TrainingTransfer.invalid }
          quoted = true
        case 44: try finishField()
        case 10: try finishRow()
        case 13:
          guard index + 1 < bytes.count, bytes[index + 1] == 10 else {
            throw TrainingTransfer.invalid
          }
          index += 1
          try finishRow()
        default:
          guard !closed else { throw TrainingTransfer.invalid }
          field.append(byte)
        }
      }
      index += 1
    }
    guard !quoted else { throw TrainingTransfer.invalid }
    if !field.isEmpty || !row.isEmpty || closed { try finishRow() }
    return rows
  }
}
