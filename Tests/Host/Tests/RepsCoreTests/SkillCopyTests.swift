import XCTest

@testable import RepsCore

final class SkillCopyTests: XCTestCase {
  func testNewPresetCopyUsesUSSpelling() {
    for skill in SkillCatalogue.definitions {
      XCTAssertEqual(skill.americanEnglish, skill)
    }
  }

  func testPreviouslySavedPresetDisplaysUSCopyWithoutChangingSnapshot() {
    var saved = SkillCatalogue.definitions[0]
    saved.summary = "Practise balance. You practised yesterday. Keep practising."
    saved.steps[0].cues = "Practise a controlled exit."
    let display = saved.americanEnglish
    XCTAssertEqual(display.summary, "Practice balance. You practiced yesterday. Keep practicing.")
    XCTAssertEqual(display.steps[0].cues, "Practice a controlled exit.")
    XCTAssertEqual(display.steps.map(\.id), saved.steps.map(\.id))
    XCTAssertEqual(display.isArchived, saved.isArchived)
    XCTAssertTrue(saved.summary.contains("Practise"))
  }

  func testPersonalCopyAndDemonstrationURLsArePreserved() {
    var custom = SkillCatalogue.definitions[0].duplicated()
    custom.summary = "Practise is my own wording."
    custom.steps[0].sourceURL = "https://example.com/practise"
    XCTAssertEqual(custom.americanEnglish, custom)
    var preset = SkillCatalogue.definitions[0]
    preset.steps[0].sourceURL = "https://example.com/practise"
    XCTAssertEqual(preset.americanEnglish.steps[0].sourceURL, preset.steps[0].sourceURL)
  }
}

extension SkillCopyTests {
  func testEveryPresetDemonstrationIsYouTubeIncludingPersistedOldLinks() {
    for skill in SkillCatalogue.definitions {
      for step in skill.steps {
        XCTAssertEqual(
          URLComponents(string: step.sourceURL ?? "")?.host, "www.youtube.com", step.id)
      }
      var old = skill
      for index in old.steps.indices { old.steps[index].sourceURL = "https://gmb.io/handstand/" }
      XCTAssertEqual(old.americanEnglish.steps.map(\.sourceURL), skill.steps.map(\.sourceURL))
      XCTAssertTrue(old.steps.allSatisfy { $0.sourceURL == "https://gmb.io/handstand/" })
    }
  }
}
