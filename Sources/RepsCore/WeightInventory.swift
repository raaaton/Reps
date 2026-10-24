import Foundation

public struct WeightItem: Codable, Identifiable, Equatable, Sendable {
  public var id: String
  public var name: String
  /// Weight of one copy, in grams.
  public var grams: Int
  public var isEnabled: Bool
  public var quantity: Int
  public init(id: String, name: String, grams: Int, isEnabled: Bool, quantity: Int = 1) {
    self.id = id
    self.name = name
    self.grams = grams
    self.isEnabled = isEnabled
    self.quantity = quantity
  }
  enum CodingKeys: String, CodingKey { case id, name, grams, isEnabled, quantity }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    name = try c.decode(String.self, forKey: .name)
    grams = try c.decode(Int.self, forKey: .grams)
    isEnabled = try c.decode(Bool.self, forKey: .isEnabled)
    quantity = c.contains(.quantity) ? try c.decode(Int.self, forKey: .quantity) : 1
  }
}

public struct LoadComponent: Identifiable, Codable, Equatable, Sendable {
  public let id: String
  public let name: String
  /// Total grams of all copies, preserving the existing snapshot sum contract.
  public let grams: Int
  public let quantity: Int
  public var unitGrams: Int { quantity > 0 ? grams / quantity : 0 }
  public var displayName: String { quantity == 1 ? name : "\(name) × \(quantity)" }
  public init(id: String, name: String, grams: Int, quantity: Int = 1) {
    self.id = id
    self.name = name
    self.grams = grams
    self.quantity = quantity
  }
  enum CodingKeys: String, CodingKey { case id, name, grams, quantity }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    name = try c.decode(String.self, forKey: .name)
    grams = try c.decode(Int.self, forKey: .grams)
    quantity = c.contains(.quantity) ? try c.decode(Int.self, forKey: .quantity) : 1
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
    // Iterate counts, never permutations of individual identical copies.
    var remainingWork = 200_000
    for item in items.sorted(by: { $0.id < $1.id }) {
      guard item.grams > 0, (1...1000).contains(item.quantity) else {
        throw TrainingError.invalid("Enter a positive unit weight and a quantity from 1 to 1,000.")
      }
      guard item.isEnabled else { continue }
      let prior = totals.sorted { $0.key < $1.key }
      for count in 1...item.quantity {
        let (itemGrams, multipliedOverflow) = item.grams.multipliedReportingOverflow(by: count)
        guard !multipliedOverflow else {
          throw TrainingError.invalid("The total load is too high.")
        }
        for (grams, components) in prior {
          let cost = components.count + 1
          guard cost <= remainingWork else {
            throw TrainingError.invalid(
              "Too many combinations. Reduce quantities or disable some items."
            )
          }
          remainingWork -= cost
          let (total, overflow) = grams.addingReportingOverflow(itemGrams)
          guard !overflow else { throw TrainingError.invalid("The total load is too high.") }
          if totals[total] == nil {
            totals[total] =
              components + [
                LoadComponent(id: item.id, name: item.name, grams: itemGrams, quantity: count)
              ]
            guard totals.count <= 4095 else {
              throw TrainingError.invalid(
                "Too many available loads. Reduce quantities or disable some items."
              )
            }
          }
        }
      }
    }
    return [.bodyweight]
      + totals.sorted { $0.key < $1.key }.map { AvailableLoad(grams: $0.key, components: $0.value) }
  }
  // Project exact totals only after subset generation: pruning intermediate sums
  // would lose loads made from several small items. Validation keeps using loads().
  public static func spacedLoads(_ loads: [AvailableLoad], retaining selected: AvailableLoad? = nil)
    -> [AvailableLoad]
  {
    var result: [AvailableLoad] = []
    for load in loads.sorted(by: { $0.grams < $1.grams }) {
      guard load.grams >= 0 else { continue }
      if let last = result.last, load.grams - last.grams < 500 { continue }
      result.append(load)
    }
    // Preserve an exact existing selection without making filtered-out loads new defaults.
    if let selected, loads.contains(selected), !result.contains(selected) {
      result.append(selected)
      result.sort { $0.grams < $1.grams }
    }
    return result
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
