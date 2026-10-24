import XCTest

@testable import RepsCore

final class SkillGenerationTests: XCTestCase {
  private var json: String {
    """
    {"name":"Flag","preparation":"Prepare shoulders","steps":[
    {"name":"Support","instructions":"Push with straight arms","cues":"Stable shoulders","suggestedPractice":"Use controlled attempts","equipment":"Bar","sourceURL":null,"isExtension":false,"suggestedFormat":"timedHolds"},
    {"name":"Flag","instructions":"Hold the side lever","cues":"Keep the body straight","suggestedPractice":"Use assistance","equipment":"Bar","sourceURL":"https://www.youtube.com/watch?v=AGhb8V8M758","isExtension":false,"suggestedFormat":"timedHolds"},
    {"name":"Flag raises","instructions":"Raise with control","cues":"Avoid swinging","suggestedPractice":"Record repetitions","equipment":"Bar","sourceURL":null,"isExtension":true,"suggestedFormat":"repetitions"}]}
    """
  }
  func testGenerationValidatesAndAssignsLocalIDs() throws {
    let p = try SkillGeneration.parse(json)
    XCTAssertEqual(p.name, "Flag")
    XCTAssertEqual(p.steps.count, 3)
    XCTAssertFalse(p.isPreset)
    XCTAssertEqual(Set(p.steps.map(\.id)).count, 3)
    XCTAssertTrue(p.steps.last!.isExtension)
    XCTAssertEqual(
      try SkillGeneration.parse("```json\n" + json + "\n```").steps.map(\.name), p.steps.map(\.name)
    )
  }
  func testPromptRequiresVideoResearchInsteadOfDefaultNull() throws {
    let prompt = try SkillGeneration.prompt(name: "Handstand")
    XCTAssertTrue(prompt.contains("Search the web"))
    XCTAssertTrue(prompt.contains("every step"))
    XCTAssertTrue(prompt.contains("cannot browse"))
    XCTAssertFalse(prompt.contains("\"sourceURL\":null"))
  }
  func testInvalidResponsesNeverReachStorage() throws {
    for text in [
      "not JSON", json.replacingOccurrences(of: "Stable shoulders", with: ""),
      json.replacingOccurrences(
        of: "\"equipment\":\"Bar\"", with: "\"extra\":true,\"equipment\":\"Bar\""),
      json.replacingOccurrences(
        of: "https://www.youtube.com/watch?v=AGhb8V8M758", with: "http://example.com"),
      json.replacingOccurrences(of: "\"isExtension\":false", with: "\"isExtension\":true"),
      String(repeating: "x", count: 200_001),
    ] {
      XCTAssertThrowsError(try SkillGeneration.parse(text))
    }
    XCTAssertThrowsError(try SkillGeneration.prompt(name: "  "))
    XCTAssertTrue(try SkillGeneration.prompt(name: "Human Flag").contains("Human Flag"))
  }
  func testReviewedDraftIsSavedOnceAndSurvivesReopen() async throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let r = try RepsRepository(path: path)
    let draft = try SkillGeneration.parse(json)
    try await r.saveSkill(draft, original: nil)
    do {
      try await r.saveSkill(draft, original: nil)
      XCTFail("Duplicate draft saved twice")
    } catch {}
    let reopened = try RepsRepository(path: path)
    let snapshot = try await reopened.snapshot()
    XCTAssertEqual(snapshot.skills.filter { $0.id == draft.id }, [draft])
  }
}

extension SkillGenerationTests {
  func testAIIntroductionAndFencedResponseCanBeReviewedLikeKavi() throws {
    let response =
      "Your skill is ready. Copy this JSON back into Reps.\n```json\n" + json
      + "\n```\nYou can now review it."
    let parsed = try SkillGeneration.parse(response)
    XCTAssertEqual(parsed.name, "Flag")
    XCTAssertEqual(parsed.steps.count, 3)
  }
  func testSurroundingProseWithoutFenceCanBeReviewed() throws {
    let parsed = try SkillGeneration.parse("Here is the roadmap:\n" + json + "\nReady for Reps.")
    XCTAssertEqual(parsed.name, "Flag")
  }
  func testMultipleRoadmapsAreRejectedInsteadOfPickingOneSilently() {
    XCTAssertThrowsError(
      try SkillGeneration.parse(
        "```json\n" + json + "\n```\n```json\n"
          + json.replacingOccurrences(of: "Flag", with: "Planche") + "\n```"))
  }
}

extension SkillGenerationTests {
  func testChatGPTMarkdownHardBreaksAndEncodedIndentationAreAccepted() throws {
    let response = json.replacingOccurrences(of: "\n", with: "\\\n&#x20; ")
    let parsed = try SkillGeneration.parse(response)
    XCTAssertEqual(parsed.name, "Flag")
    XCTAssertEqual(parsed.steps.count, 3)
    XCTAssertEqual(parsed.steps[1].instructions, "Hold the side lever")
  }
  func testImportNormalizationPreservesJSONEscapesAndLiteralEntitiesInsideText() throws {
    let instruction = #"Keep \"quoted\" cues and a C:\\training path; literal &#x20; remains."#
    let text = json.replacingOccurrences(of: "Push with straight arms", with: instruction)
    let parsed = try SkillGeneration.parse(text)
    XCTAssertEqual(
      parsed.steps[0].instructions,
      #"Keep "quoted" cues and a C:\training path; literal &#x20; remains."#)
    XCTAssertThrowsError(
      try SkillGeneration.parse(text.replacingOccurrences(of: "\\\\training", with: "\\qtraining")))
  }
}
