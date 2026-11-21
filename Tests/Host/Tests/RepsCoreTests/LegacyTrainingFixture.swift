import Foundation

// Tests downgrade current exports to exercise old readers. Remove fields that did
// not exist in those file versions; production continues to reject unknown fields.
enum LegacyTrainingFixture {
  static func data(withJSONObject object: Any, options: JSONSerialization.WritingOptions = [])
    throws -> Data
  {
    guard var root = object as? [String: Any], root["format"] as? String == "sport.training",
      let version = root["version"] as? Int, version < 11,
      var contents = root["contents"] as? [String: Any],
      var config = contents["configuration"] as? [String: Any]
    else {
      return try JSONSerialization.data(withJSONObject: object, options: options)
    }
    for key in ["variants", "variantGoals", "identityAliases", "completedExerciseMerges"] {
      config.removeValue(forKey: key)
    }
    if var schedules = config["schedules"] as? [[String: Any]] {
      for index in schedules.indices {
        schedules[index].removeValue(forKey: "variantIDs")
        schedules[index].removeValue(forKey: "baseGoals")
      }
      config["schedules"] = schedules
    }
    contents["configuration"] = config
    root["contents"] = contents
    return try JSONSerialization.data(withJSONObject: root, options: options)
  }
}
