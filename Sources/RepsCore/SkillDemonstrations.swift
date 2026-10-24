import Foundation

// Verified author tutorials; keep shared progression videos where they demonstrate each variant.
// Source selection and playback-validation limits are recorded in docs/TESTING.md.
enum SkillDemonstrations {
  static func url(for stepID: String) -> String? {
    let video: String
    switch stepID {
    case "handstand.supported", "handstand.wall-line", "handstand.wall-balance", "handstand.free":
      video = "d6_lcWtQDxw"
    case "handstand.extension.push-up": video = "nk-bjYYZVaE"
    case "handstand.extension.press": video = "SfLaCKaljU4"
    case "l-sit.support": return "https://www.youtube.com/watch?v=BbAkWxDZKIM&t=135s"
    case "l-sit.tuck": return "https://www.youtube.com/watch?v=BbAkWxDZKIM&t=202s"
    case "l-sit.partial": return "https://www.youtube.com/watch?v=BbAkWxDZKIM&t=235s"
    case "l-sit.one-leg": return "https://www.youtube.com/watch?v=BbAkWxDZKIM&t=268s"
    case "l-sit.full": return "https://www.youtube.com/watch?v=BbAkWxDZKIM&t=306s"
    case "l-sit.extension.v-sit": video = "0pkTDnbRe8Q"
    case "planche.lean", "planche.assisted-tuck", "planche.tuck": video = "8mnNpNZ88Oo"
    case "planche.advanced-tuck", "planche.straddle": video = "6snDOgFBBFA"
    case "planche.full": video = "wYWlie_g_js"
    case "planche.extension.push-up": video = "TZ63httkob4"
    case "front-lever.tuck", "front-lever.advanced-tuck", "front-lever.straddle",
      "front-lever.full":
      video = "AGhb8V8M758"
    case "front-lever.extension.pull-up": video = "dze1Dpi3CKk"
    default: return nil
    }
    return "https://www.youtube.com/watch?v=\(video)"
  }
}
