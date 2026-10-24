import Foundation
import RepsCore

enum BodyWeightPresentation {
  static func value(_ grams: Int) -> String {
    "\(input(grams)) kg"
  }
  static func input(_ grams: Int) -> String {
    let whole = String(grams / 1000)
    let remainder = grams % 1000
    guard remainder != 0 else { return whole }
    var fractional = String(format: "%03d", remainder)
    while fractional.last == "0" { fractional.removeLast() }
    return whole + (Locale.current.decimalSeparator ?? ".") + fractional
  }
  static func change(_ grams: Int) -> String {
    "\(grams > 0 ? "+" : grams < 0 ? "−" : "")\(value(abs(grams)))"
  }
}
