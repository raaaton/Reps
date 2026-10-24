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
  public static let defaultMaximumObjects = 10

  public static func loads(items: [WeightItem], maximumObjects: Int = 10, backpackGrams: Int = 3000)
    throws -> [AvailableLoad]
  {
    guard (1...1000).contains(maximumObjects) else {
      throw TrainingError.invalid("Choose a maximum from 1 to 1,000 objects.")
    }
    guard backpackGrams > 0 else {
      throw TrainingError.invalid("Enter a positive backpack weight.")
    }
    let bag = LoadComponent(id: Self.bag.id, name: Self.bag.name, grams: backpackGrams)
    var totals: [Int: (components: [LoadComponent], objects: Int)] = [bag.grams: ([bag], 0)]
    var remainingWork = 200_000
    for item in items.sorted(by: { $0.id < $1.id }) {
      guard item.grams > 0, (1...1000).contains(item.quantity) else {
        throw TrainingError.invalid("Enter a positive unit weight and a quantity from 1 to 1,000.")
      }
      guard item.isEnabled else { continue }
      // Freeze prior states so this item type cannot be reused beyond its available count.
      let prior = totals.sorted { $0.key < $1.key }
      for count in 1...min(item.quantity, maximumObjects) {
        let (itemGrams, multipliedOverflow) = item.grams.multipliedReportingOverflow(by: count)
        guard !multipliedOverflow else {
          throw TrainingError.invalid("The total load is too high.")
        }
        for (grams, previous) in prior {
          let cost = previous.components.count + 1
          guard cost <= remainingWork else {
            throw TrainingError.invalid(
              "Too many combinations. Reduce quantities or disable some items.")
          }
          remainingWork -= cost
          let objects = previous.objects + count
          guard objects <= maximumObjects else { continue }
          let (total, overflow) = grams.addingReportingOverflow(itemGrams)
          guard !overflow else { throw TrainingError.invalid("The total load is too high.") }
          // At the same subtotal fewer objects always leaves at least as much capacity
          // for later independent item types. Keep the first composition on exact ties.
          if let existing = totals[total], existing.objects <= objects { continue }
          totals[total] = (
            previous.components + [
              LoadComponent(id: item.id, name: item.name, grams: itemGrams, quantity: count)
            ], objects
          )
          guard totals.count <= 4095 else {
            throw TrainingError.invalid(
              "Too many available loads. Reduce quantities or disable some items.")
          }
        }
      }
    }
    return [.bodyweight]
      + totals.sorted { $0.key < $1.key }.map {
        AvailableLoad(grams: $0.key, components: $0.value.components)
      }
  }

  // Feasibility is independent of the preferred composition for the same total.
  // This preserves exact saved choices while applying the cap to future selections.
  public static func isAvailable(
    _ load: AvailableLoad, items: [WeightItem], maximumObjects: Int = 10, backpackGrams: Int = 3000
  ) -> Bool {
    guard (1...1000).contains(maximumObjects), backpackGrams > 0 else { return false }
    let bag = LoadComponent(id: Self.bag.id, name: Self.bag.name, grams: backpackGrams)
    if load.grams == 0 { return load.components.isEmpty }
    guard load.grams >= bag.grams else { return false }
    var seen = Set<String>()
    var total = 0
    var objects = 0
    for component in load.components {
      guard seen.insert(component.id).inserted, component.grams > 0 else { return false }
      if component.id == bag.id {
        guard component == bag else { return false }
      } else {
        guard (1...maximumObjects).contains(component.quantity),
          let item = items.first(where: { $0.id == component.id }), item.isEnabled,
          item.name == component.name, item.grams > 0, (1...1000).contains(item.quantity),
          component.quantity <= item.quantity
        else { return false }
        let (grams, overflow) = item.grams.multipliedReportingOverflow(by: component.quantity)
        guard !overflow, grams == component.grams else { return false }
        objects += component.quantity
        guard objects <= maximumObjects else { return false }
      }
      let (grams, overflow) = total.addingReportingOverflow(component.grams)
      guard !overflow else { return false }
      total = grams
    }
    return seen.contains(bag.id) && total == load.grams
  }

  // Project exact totals only after subset generation: pruning intermediate sums
  // would lose loads made from several small items. Validation keeps using loads().
  public static func spacedLoads(
    _ loads: [AvailableLoad], retaining selected: AvailableLoad? = nil, items: [WeightItem]? = nil,
    maximumObjects: Int = 10, backpackGrams: Int = 3000
  ) -> [AvailableLoad] {
    // Give fewer physical copies priority BEFORE resolving nearby total weights.
    var candidates: [(load: AvailableLoad, objects: Int)] = []
    for load in loads where load.grams >= 0 {
      let count = load.components.filter { $0.id != bag.id }.reduce(0) { $0 + $1.quantity }
      candidates.append((load, count))
    }
    candidates.sort { lhs, rhs in
      if lhs.objects != rhs.objects { return lhs.objects < rhs.objects }
      return lhs.load.grams < rhs.load.grams
    }
    var result: [AvailableLoad] = []
    // At most one accepted total fits in each 500g bucket. Only adjacent buckets
    // can conflict, so priority filtering does not require a quadratic scan.
    var chosenByBucket: [Int: Int] = [:]
    for candidate in candidates {
      let load = candidate.load
      let bucket = load.grams / 500
      let conflicts = (-1...1).contains { offset in
        guard let grams = chosenByBucket[bucket + offset] else { return false }
        return abs(grams - load.grams) < 500
      }
      guard !conflicts else { continue }
      chosenByBucket[bucket] = load.grams
      result.append(load)
    }
    // Preserve a feasible filtered-out selection, without duplicating a total that
    // already offers its preferred composition. No inventory means exact membership.
    if let selected,
      items.map({
        isAvailable(
          selected, items: $0, maximumObjects: maximumObjects, backpackGrams: backpackGrams)
      })
        ?? loads.contains(selected),
      !result.contains(where: { $0.grams == selected.grams })
    {
      result.append(selected)
    }
    return result.sorted { $0.grams < $1.grams }
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
