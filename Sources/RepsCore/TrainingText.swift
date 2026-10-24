import Foundation

enum TrainingText {
  static func isValid(_ value: String, limit: Int = 4096) -> Bool {
    !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && value.utf8.count <= limit && !value.contains("\0")
  }

  static func validate(name: String, id: String) throws {
    guard isValid(id, limit: 256) else {
      throw TrainingError.invalid("This identifier is invalid.")
    }
    guard isValid(name) else {
      throw TrainingError.invalid("Enter a shorter name without unsupported characters.")
    }
  }
}
