import Foundation

extension SkillDefinition {
  /// App-owned preset wording can evolve without rewriting saved practice snapshots or custom text.
  public var americanEnglish: Self {
    guard isPreset else { return self }
    var copy = self
    copy.summary = Self.usSpelling(summary)
    copy.preparation = Self.usSpelling(preparation)
    copy.steps = steps.map { original in
      var step = original
      step.instructions = Self.usSpelling(step.instructions)
      step.cues = Self.usSpelling(step.cues)
      step.suggestedPractice = Self.usSpelling(step.suggestedPractice)
      step.equipment = Self.usSpelling(step.equipment)
      let host = original.sourceURL.flatMap { URLComponents(string: $0)?.host }
      if let source = SkillDemonstrations.url(for: step.id),
        original.sourceURL == nil
          || ["gmb.io", "www.gmb.io", "youtube.com", "www.youtube.com", "youtu.be"].contains(
            host ?? "")
      {
        step.sourceURL = source
      }
      return step
    }
    return copy
  }

  private static func usSpelling(_ value: String) -> String {
    var result = value
    for (uk, us) in [
      ("practise", "practice"), ("practises", "practices"),
      ("practised", "practiced"), ("practising", "practicing"),
    ] {
      result = result.replacingOccurrences(of: "\\b\(uk)\\b", with: us, options: .regularExpression)
      result = result.replacingOccurrences(
        of: "\\b\(uk.capitalized)\\b", with: us.capitalized, options: .regularExpression)
    }
    return result
  }
}
