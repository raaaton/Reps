import Foundation

extension SportRepository {
  func readWeightItems() throws -> [WeightItem] {
    try database.query("SELECT * FROM weight_items ORDER BY name COLLATE NOCASE,id").map { row in
      WeightItem(
        id: try row.text("id"), name: try row.text("name"), grams: try row.integer("grams"),
        isEnabled: try row.integer("enabled") == 1)
    }
  }
  public func saveWeightItem(_ proposed: WeightItem) throws {
    var item = proposed
    item.name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !item.id.isEmpty, item.id != WeightInventory.bag.id, !item.name.isEmpty, item.grams > 0
    else {
      throw TrainingError.invalid(
        "Enter an item name and a positive weight.")
    }
    try TrainingText.validate(name: item.name, id: item.id)
    try database.transaction {
      var items = try readWeightItems().filter { $0.id != item.id }
      items.append(item)
      _ = try WeightInventory.loads(items: items)
      try database.execute(
        "INSERT INTO weight_items VALUES(?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,grams=excluded.grams,enabled=excluded.enabled",
        [.text(item.id), .text(item.name), .integer(item.grams), .integer(item.isEnabled ? 1 : 0)])
    }
  }
  public func deleteWeightItem(id: String) throws {
    try database.transaction {
      try database.execute("DELETE FROM weight_items WHERE id=?", [.text(id)])
    }
  }
  func validateLoad(_ load: AvailableLoad, grams: Int) throws {
    guard load.grams == grams, try WeightInventory.loads(items: readWeightItems()).contains(load)
    else {
      throw TrainingError.invalid(
        "This load combination has changed. Choose the load again.")
    }
  }
}
