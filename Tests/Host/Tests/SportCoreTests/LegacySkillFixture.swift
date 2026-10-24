import Foundation

// Make historical fixtures represent real pre-Skills archives rather than a v6 body with an old label.
func removingNewSkillFields(_ raw: [String: Any]) -> [String: Any] {
  var root = raw
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
