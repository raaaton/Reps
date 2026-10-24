import Foundation

public enum SkillCatalogue {
  public static let definitions: [SkillDefinition] = [
    make(
      "handstand", "Handstand",
      "Build confidence upside down, then practice balance and controlled entries.",
      "Prepare your wrists and shoulders with comfortable unloaded movements, then easy supported work. Read the exit instructions before going upside down.",
      "Wall and clear floor space", "https://gmb.io/handstand/",
      [
        (
          "supported", "Supported Inversion and Exit",
          "Walk your feet up the wall only as far as you can confidently return. Keep the floor around you clear.",
          "Practice returning to the floor under control before going higher."
        ),
        (
          "wall-line", "Wall Alignment",
          "Face the wall in a supported handstand at a distance you can manage. Push tall through your shoulders without forcing the position.",
          "Keep the arms straight and the body controlled; walk down when ready."
        ),
        (
          "wall-balance", "Balance Away from the Wall",
          "From a supported position, briefly reduce contact with the wall and return with control. Use small adjustments through your hands.",
          "Avoid kicking away from the wall; keep a reliable way to return."
        ),
        (
          "free", "Freestanding Handstand",
          "Practice controlled entries in a clear space, using the exit you have already rehearsed. Reset between attempts.",
          "Work on a controlled entry and exit as well as the balance itself."
        ),
      ], extensions: [("push-up", "Handstand Push-up"), ("press", "Press to Handstand")]),
    make(
      "l-sit", "L-sit", "Develop support and compression while gradually extending your legs.",
      "Prepare wrists, shoulders and hips with comfortable movements. Start with easy foot-supported holds before floating your legs.",
      "Floor or stable parallettes", "https://gmb.io/l-sit/",
      [
        (
          "support", "Foot-Supported Hold",
          "Place your hands beside your hips and press down. Keep your feet supported while learning to lift and support your hips.",
          "Push the support away and keep your shoulders away from your ears."
        ),
        (
          "tuck", "Tuck L-sit",
          "From a stable support, bring both knees toward your chest and lift your feet. Return the feet to the floor with control.",
          "Keep pressing down; choose a support height that lets you clear the floor."
        ),
        (
          "partial", "Partial Leg Extension",
          "From a tuck, start opening the knees without losing your support. Return to the tuck between attempts.",
          "Extend only as far as you can keep the hips supported."
        ),
        (
          "one-leg", "Single-Leg L-sit",
          "Extend one leg while keeping the other tucked. Practice both sides and return to the tuck with control.",
          "Compare like-for-like attempts and note which side you practiced."
        ),
        (
          "full", "Full L-sit",
          "Press through your hands and extend both legs in front of you, keeping them off the floor.",
          "Maintain straight arms and a supported position rather than chasing a longer hold."
        ),
      ], extensions: [("v-sit", "V-sit")]),
    make(
      "planche", "Planche",
      "Explore progressively longer levers while preserving a controlled straight-arm support.",
      "Prepare wrists and shoulders with easy movement and supported leans. Use a stable surface and start with a variation you can control.",
      "Floor or stable parallettes; optional assistance", "https://gmb.io/planche/",
      [
        (
          "lean", "Planche Lean",
          "From a straight-arm plank, gradually shift the shoulders ahead of the hands while keeping the feet supported.",
          "Keep actively pushing through the support; adjust the lean rather than forcing it."
        ),
        (
          "assisted-tuck", "Supported Tuck Planche",
          "Bring the knees toward your chest while keeping assistance under your feet or using a suitable support.",
          "Record the assistance so future results remain comparable."
        ),
        (
          "tuck", "Tuck Planche",
          "From a stable lean, draw the knees close and briefly float the feet while maintaining straight arms.",
          "Return to supported work when you cannot keep the position controlled."
        ),
        (
          "advanced-tuck", "Advanced Tuck Planche",
          "Open the tuck gradually so the hips and back extend farther behind the shoulders.",
          "Lengthen the lever without losing straight arms or active support."
        ),
        (
          "straddle", "Straddle Planche",
          "Explore extending the legs out to the sides from a controlled support. Assistance can help you practice the intended position.",
          "Keep the assistance and leg position consistent when comparing holds."
        ),
        (
          "full", "Full Planche",
          "Extend both legs together behind you while maintaining a horizontal straight-arm support.",
          "Use an easier variation whenever the intended shape cannot be maintained."
        ),
      ], extensions: [("push-up", "Full Planche Push-up")]),
    make(
      "front-lever", "Front Lever",
      "Develop straight-arm pulling control through progressively longer body positions.",
      "Prepare your shoulders and grip with easy supported pulling and controlled hangs on secure equipment. Begin with a manageable tuck variation.",
      "Secure pull-up bar or rings", "https://www.youtube.com/watch?v=AGhb8V8M758",
      [
        (
          "tuck", "Tuck Front Lever",
          "From a controlled hang, bring your knees toward your chest and raise the hips into a compact horizontal position.",
          "Keep the elbows straight and return to a controlled hang."
        ),
        (
          "advanced-tuck", "Advanced Tuck Front Lever",
          "Open your tuck gradually, moving the knees farther from the chest while maintaining a controlled body line.",
          "Keep the hips level rather than extending at the expense of position."
        ),
        (
          "straddle", "Straddle Front Lever",
          "Extend your legs apart to lengthen the lever. Use assistance if needed to practice a controlled shape.",
          "Record assistance and leg position; do not compare this directly with a tuck."
        ),
        (
          "full", "Full Front Lever",
          "Extend the legs together while keeping the body horizontal under the bar or rings.",
          "Maintain straight arms and a consistent body line instead of chasing seconds."
        ),
      ], extensions: [("pull-up", "Front Lever Pull-up")]),
  ]
  private static func make(
    _ id: String, _ name: String, _ summary: String, _ preparation: String,
    _ equipment: String, _ source: String, _ stages: [(String, String, String, String)],
    extensions: [(String, String)]
  ) -> SkillDefinition {
    var steps = stages.map { key, title, instructions, cues in
      SkillStep(
        id: "\(id).\(key)", name: title, instructions: instructions, cues: cues,
        suggestedPractice:
          "Practice controlled attempts with time to reset. Keep an easier variation available. The duration is a practice reference, not a mastery test.",
        equipment: equipment, sourceURL: source)
    }
    steps += extensions.map { key, title in
      let detail = extensionDetails(title)
      return SkillStep(
        id: "\(id).extension.\(key)", name: title,
        instructions: detail.instructions, cues: detail.cues,
        suggestedPractice: detail.practice, equipment: equipment,
        sourceURL: detail.source ?? source,
        isExtension: true, suggestedFormat: title == "V-sit" ? .freePractice : .repetitions)
    }
    var definition = SkillDefinition(
      id: id, name: name, summary: summary, preparation: preparation,
      steps: steps, isPreset: true)
    for index in definition.steps.indices {
      if let source = SkillDemonstrations.url(for: definition.steps[index].id) {
        definition.steps[index].sourceURL = source
      }
    }
    return definition
  }
  private static func extensionDetails(_ name: String) -> (
    instructions: String, cues: String, practice: String, source: String?
  ) {
    switch name {
    case "Handstand Push-up":
      (
        "From a supported or freestanding handstand, bend your arms to lower with control, then press back to straight arms. Choose support and a range you can manage before attempting a full unsupported repetition.",
        "Keep pushing through the hands. Control the descent rather than dropping onto your head, and preserve a reliable exit.",
        "Use an elevated pike press or an assisted partial handstand press as a working variation. Record the assistance and range with your actual repetitions.",
        "https://gmb.io/handstand-push-up/"
      )
    case "Press to Handstand":
      (
        "Lift the hips over the hands and bring the feet off the floor into a handstand without relying on a kick-up. Begin with a supported hip lift or wall-assisted transition before a full press.",
        "Drive through straight arms and move the hips above the shoulders. Use a manageable tuck or straddle rather than forcing straight legs.",
        "Practice a controlled hip lift or an assisted press and return. Choose repetitions for the transition, or free practice to explore entries with rests between attempts.",
        "https://gmb.io/press-handstand/"
      )
    case "V-sit":
      (
        "From an L-sit support, draw the legs higher toward the torso while maintaining straight arms and active support. Use a tuck or bent-knee variation to explore compression before raising straight legs.",
        "Keep pressing the support down as the legs rise. Work within the hip and hamstring range you can control.",
        "Alternate a manageable support hold with controlled leg lifts. Note the leg shape and support height when comparing attempts.",
        nil
      )
    case "Full Planche Push-up":
      (
        "From a planche support, bend your arms to lower the body, then press back up while keeping the feet unsupported. Begin with band assistance or a shorter lever rather than treating a full repetition as the starting exercise.",
        "Keep the body position and assistance consistent through the descent and press. Reduce the lever when the intended position cannot be maintained.",
        "Practice an assisted or tuck-planche push-up variation that you can control. Record repetitions with the lever and assistance in the block notes.",
        "https://www.youtube.com/watch?v=TZ63httkob4"
      )
    default:
      (
        "From a front lever variation under a secure bar or rings, bend your arms to pull the torso toward the support, then return with control. Use a tuck or assisted lever before the full horizontal version.",
        "Keep the chosen hip and leg position consistent. Shorten the lever or add assistance rather than swinging to finish a repetition.",
        "Choose a tuck or assisted front-lever row, record actual repetitions and keep the same assistance and range when comparing results.",
        nil
      )
    }
  }

}
