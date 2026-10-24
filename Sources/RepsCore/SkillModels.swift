import Foundation

public enum SkillFormat: String, Codable, CaseIterable, Sendable {
  case freePractice, timedHolds, repetitions
  public var name: String {
    switch self {
    case .freePractice: "Free Practice"
    case .timedHolds: "Timed Holds"
    case .repetitions: "Repetitions"
    }
  }
}
public enum SkillPlacement: String, Codable, CaseIterable, Sendable {
  case beforeForce, afterForce
  public var name: String { self == .beforeForce ? "Before Strength" : "After Strength" }
}
public enum SkillAchievement: String, Codable, CaseIterable, Sendable {
  case unrecorded, firstSuccess, consistent
  public var name: String {
    switch self {
    case .unrecorded: "Not Recorded"
    case .firstSuccess: "First Success"
    case .consistent: "Consistent"
    }
  }
}
public struct SkillStep: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var name: String
  public var instructions: String
  public var cues: String
  public var suggestedPractice: String
  public var equipment: String
  public var sourceURL: String?
  public var isExtension: Bool
  public var suggestedFormat: SkillFormat
  public init(
    id: String = UUID().uuidString, name: String, instructions: String = "", cues: String = "",
    suggestedPractice: String = "", equipment: String = "", sourceURL: String? = nil,
    isExtension: Bool = false, suggestedFormat: SkillFormat = .freePractice
  ) {
    self.id = id
    self.name = name
    self.instructions = instructions
    self.cues = cues
    self.suggestedPractice = suggestedPractice
    self.equipment = equipment
    self.sourceURL = sourceURL
    self.isExtension = isExtension
    self.suggestedFormat = suggestedFormat
  }
}
public struct SkillDefinition: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var name: String
  public var summary: String
  public var preparation: String
  public var steps: [SkillStep]
  public var isPreset: Bool
  public var isArchived: Bool
  public init(
    id: String = UUID().uuidString, name: String, summary: String = "", preparation: String = "",
    steps: [SkillStep], isPreset: Bool = false, isArchived: Bool = false
  ) {
    self.id = id
    self.name = name
    self.summary = summary
    self.preparation = preparation
    self.steps = steps
    self.isPreset = isPreset
    self.isArchived = isArchived
  }
  public func duplicated() -> Self {
    var copy = self
    copy.id = UUID().uuidString
    copy.name += " Copy"
    copy.isPreset = false
    copy.isArchived = false
    copy.steps = steps.map {
      var step = $0
      step.id = UUID().uuidString
      return step
    }
    return copy
  }
  public func validated() throws -> Self {
    var value = self
    value.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    try TrainingText.validate(name: value.name, id: id)
    guard (1...100).contains(steps.count), Set(steps.map(\.id)).count == steps.count else {
      throw TrainingError.invalid(
        "Add at least one step, with a different identifier for each step.")
    }
    for text in [summary, preparation] { try SkillValidation.optionalText(text) }
    for index in value.steps.indices {
      value.steps[index].name = steps[index].name.trimmingCharacters(in: .whitespacesAndNewlines)
      let step = value.steps[index]
      try TrainingText.validate(name: step.name, id: step.id)
      for text in [step.instructions, step.cues, step.suggestedPractice, step.equipment] {
        try SkillValidation.optionalText(text)
      }
      if let link = step.sourceURL {
        guard link.utf8.count <= 4096, let url = URLComponents(string: link),
          url.scheme?.lowercased() == "https", !(url.host ?? "").isEmpty,
          url.user == nil, url.password == nil
        else { throw TrainingError.invalid("Use a complete HTTPS link for the demonstration.") }
      }
    }
    return value
  }
}
public struct SkillConfiguration: Codable, Equatable, Sendable {
  public var format: SkillFormat = .freePractice
  public var referenceSeconds: Int? = 300
  public var attemptCount: Int = 3
  public var restSeconds: Int = 60
  public var targetSeconds: Int?
  public var targetRepetitions: Int?
  public var assistance: String = ""
  public init(format: SkillFormat = .freePractice) { self.format = format }
  public func validated() throws -> Self {
    guard (1...1000).contains(attemptCount), (0...86400).contains(restSeconds),
      referenceSeconds.map({ (1...86400).contains($0) }) ?? true,
      targetSeconds.map({ (1...86400).contains($0) }) ?? true,
      targetRepetitions.map({ (1...10000).contains($0) }) ?? true
    else {
      throw TrainingError.invalid("Choose valid durations, repetitions and number of attempts.")
    }
    try SkillValidation.optionalText(assistance)
    return self
  }
}
public struct SkillAssignment: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var skillID: String
  public var stepID: String
  public var configuration: SkillConfiguration
  public init(
    id: String = UUID().uuidString, skillID: String, stepID: String,
    configuration: SkillConfiguration = SkillConfiguration()
  ) {
    self.id = id
    self.skillID = skillID
    self.stepID = stepID
    self.configuration = configuration
  }
}
public struct SkillProgress: Codable, Equatable, Identifiable, Sendable {
  public var id: String { skillID }
  public var skillID: String
  public var currentStepID: String
  public var achievements: [String: SkillAchievement] = [:]
  public init(skillID: String, currentStepID: String) {
    self.skillID = skillID
    self.currentStepID = currentStepID
  }
}
struct ScheduleSkills: Codable {
  var placement: SkillPlacement
  var blocks: [SkillAssignment]
}
enum SkillValidation {
  static func optionalText(_ value: String) throws {
    guard value.utf8.count <= 4096, !value.contains("\0") else {
      throw TrainingError.invalid("Use shorter text without unsupported characters.")
    }
  }
}
