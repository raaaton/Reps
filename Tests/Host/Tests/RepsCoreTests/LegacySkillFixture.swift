import Foundation

// Make historical fixtures represent real pre-Skills archives rather than a current body with an old label.
func removingNewTrainingFields(_ raw: [String: Any]) -> [String: Any] {
  func stripQuantities(_ value: Any) -> Any {
    if let array = value as? [Any] { return array.map(stripQuantities) }
    guard var object = value as? [String: Any] else { return value }
    if object["grams"] != nil { object.removeValue(forKey: "quantity") }
    return object.mapValues(stripQuantities)
  }
  var root = (raw["version"] as? Int ?? 7) < 7 ? stripQuantities(raw) as! [String: Any] : raw
  guard (root["version"] as? Int ?? 6) < 6, var contents = root["contents"] as? [String: Any] else {
    return root
  }
  contents.removeValue(forKey: "skillSessions")
  if var configuration = contents["configuration"] as? [String: Any] {
    configuration.removeValue(forKey: "skills")
    configuration.removeValue(forKey: "skillProgress")
    if var schedules = configuration["schedules"] as? [[String: Any]] {
      for i in schedules.indices {
        schedules[i].removeValue(forKey: "skills")
        schedules[i].removeValue(forKey: "skillPlacement")
      }
      configuration["schedules"] = schedules
    }
    contents["configuration"] = configuration
  }
  if var workouts = contents["workouts"] as? [[String: Any]] {
    for i in workouts.indices { workouts[i].removeValue(forKey: "skills") }
    contents["workouts"] = workouts
  }
  root["contents"] = contents
  return root
}
