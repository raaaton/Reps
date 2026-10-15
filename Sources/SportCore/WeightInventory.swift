import Foundation

public struct WeightItem: Codable, Identifiable, Equatable, Sendable {
  public var id: String
  public var name: String
  public var grams: Int
  public var isEnabled: Bool
  public init(id: String, name: String, grams: Int, isEnabled: Bool) {
    self.id = id
    self.name = name
    self.grams = grams
    self.isEnabled = isEnabled
  }
}

public struct LoadComponent: Identifiable, Codable, Equatable, Sendable {
  public let id: String
  public let name: String
  public let grams: Int
  public init(id: String, name: String, grams: Int) {
    self.id = id
    self.name = name
    self.grams = grams
  }
}

public struct AvailableLoad: Identifiable, Codable, Equatable, Sendable {
  public let grams: Int
  public let components: [LoadComponent]
  public var id: Int { grams }
  public init(grams: Int, components: [LoadComponent]) {
    self.grams = grams
    self.components = components
  }
  public static let bodyweight = AvailableLoad(grams: 0, components: [])
}

public enum WeightInventory {
  public static let bag = LoadComponent(id: "base-bag", name: "Sac", grams: 3000)
  public static func loads(items: [WeightItem]) throws -> [AvailableLoad] {
    var totals: [Int: [LoadComponent]] = [bag.grams: [bag]]
    // Bound component work as well as unique totals: equal weights also grow compositions.
    var remainingWork = 200_000
    for item in items.filter(\.isEnabled).sorted(by: { $0.id < $1.id }) {
      guard item.grams > 0 else {
        throw TrainingError.invalid("An item must have a positive weight.")
      }
      let prior = totals.sorted { $0.key < $1.key }
      for (grams, components) in prior {
        let cost = components.count + 1
        guard cost <= remainingWork else {
          throw TrainingError.invalid(
            "Too many combinations. Disable some items to simplify available loads."
          )
        }
        remainingWork -= cost
        let (total, overflow) = grams.addingReportingOverflow(item.grams)
        guard !overflow else { throw TrainingError.invalid("The total load is too high.") }
        if totals[total] == nil {
          totals[total] =
            components + [LoadComponent(id: item.id, name: item.name, grams: item.grams)]
          guard totals.count <= 4095 else {
            throw TrainingError.invalid(
              "Too many available loads. Disable some items to simplify combinations."
            )
          }
        }
      }
    }
    return [.bodyweight]
      + totals.sorted { $0.key < $1.key }.map { AvailableLoad(grams: $0.key, components: $0.value) }
  }
  static func encode(_ components: [LoadComponent]?) throws -> SQLValue {
    guard let components else { return .null }
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return .text(String(decoding: try encoder.encode(components), as: UTF8.self))
  }
  static func decode(_ text: String?) throws -> [LoadComponent]? {
    guard let text else { return nil }
    do { return try JSONDecoder().decode([LoadComponent].self, from: Data(text.utf8)) } catch {
      throw TrainingError.storage
    }
  }
}
