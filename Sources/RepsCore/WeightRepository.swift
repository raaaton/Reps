import Foundation

extension RepsRepository {
  func readWeightItems() throws -> [WeightItem] {
    try database.query("SELECT * FROM weight_items ORDER BY name COLLATE NOCASE,id").map { row in
      WeightItem(
        id: try row.text("id"), name: try row.text("name"), grams: try row.integer("grams"),
        isEnabled: try row.integer("enabled") == 1, quantity: try row.integer("quantity"))
    }
  }
  public func saveWeightItem(_ proposed: WeightItem) throws {
    var item = proposed
    item.name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !item.id.isEmpty, item.id != WeightInventory.bag.id, !item.name.isEmpty, item.grams > 0,
      (1...1000).contains(item.quantity)
    else {
      throw TrainingError.invalid(
        "Enter an item name, a positive unit weight and a quantity from 1 to 1,000.")
    }
    try TrainingText.validate(name: item.name, id: item.id)
    try database.transaction {
      var items = try readWeightItems().filter { $0.id != item.id }
      items.append(item)
      _ = try WeightInventory.loads(items: items)
      try database.execute(
        "INSERT INTO weight_items(id,name,grams,enabled,quantity) VALUES(?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,grams=excluded.grams,enabled=excluded.enabled,quantity=excluded.quantity",
        [
          .text(item.id), .text(item.name), .integer(item.grams), .integer(item.isEnabled ? 1 : 0),
          .integer(item.quantity),
        ])
    }
  }
  public func deleteWeightItem(id: String) throws {
    try database.transaction {
      try database.execute("DELETE FROM weight_items WHERE id=?", [.text(id)])
    }
  }
  func validateLoad(_ load: AvailableLoad, grams: Int) throws {
    guard load.grams == grams, WeightInventory.isAvailable(load, items: try readWeightItems())
    else {
      throw TrainingError.invalid(
        "This load combination has changed. Choose the load again.")
    }
  }
}
