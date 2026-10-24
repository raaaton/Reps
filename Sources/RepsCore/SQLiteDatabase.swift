import CSQLite
import Foundation

enum SQLValue {
  case integer(Int)
  case text(String)
  case blob(Data)
  case null
}

struct SQLRow {
  var values: [String: SQLValue]

  func blob(_ key: String) throws -> Data {
    guard case .blob(let value) = values[key] else { throw TrainingError.storage }
    return value
  }

  func text(_ key: String) throws -> String {
    guard case .text(let value) = values[key] else { throw TrainingError.storage }
    return value
  }

  func optionalText(_ key: String) throws -> String? {
    guard let value = values[key] else { throw TrainingError.storage }
    if case .null = value { return nil }
    return try text(key)
  }

  func integer(_ key: String) throws -> Int {
    guard case .integer(let value) = values[key] else { throw TrainingError.storage }
    return value
  }

  func optionalInteger(_ key: String) throws -> Int? {
    guard let value = values[key] else { throw TrainingError.storage }
    if case .null = value { return nil }
    return try integer(key)
  }
}

/// Accessed exclusively by RepsRepository's actor, including each transaction.
final class SQLiteDatabase {
  private let handle: OpaquePointer

  init(path: String) throws {
    var opened: OpaquePointer?
    guard
      sqlite3_open_v2(
        path, &opened, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
        == SQLITE_OK,
      let opened
    else {
      if let opened { sqlite3_close(opened) }
      throw TrainingError.storage
    }
    handle = opened
    sqlite3_busy_timeout(handle, 5000)
    try execute("PRAGMA foreign_keys=ON")
  }

  deinit { sqlite3_close(handle) }

  func execute(_ sql: String, _ arguments: [SQLValue] = []) throws {
    let statement = try prepare(sql, arguments)
    defer { sqlite3_finalize(statement) }
    guard sqlite3_step(statement) == SQLITE_DONE else { throw TrainingError.storage }
  }

  func query(_ sql: String, _ arguments: [SQLValue] = []) throws -> [SQLRow] {
    let statement = try prepare(sql, arguments)
    defer { sqlite3_finalize(statement) }
    var rows: [SQLRow] = []
    while true {
      let status = sqlite3_step(statement)
      if status == SQLITE_DONE { return rows }
      guard status == SQLITE_ROW else { throw TrainingError.storage }
      var values: [String: SQLValue] = [:]
      for column in 0..<sqlite3_column_count(statement) {
        let key = String(cString: sqlite3_column_name(statement, column))
        switch sqlite3_column_type(statement, column) {
        case SQLITE_INTEGER: values[key] = .integer(Int(sqlite3_column_int64(statement, column)))
        case SQLITE_NULL: values[key] = .null
        case SQLITE_TEXT:
          guard let text = sqlite3_column_text(statement, column) else {
            throw TrainingError.storage
          }
          values[key] = .text(String(cString: text))
        case SQLITE_BLOB:
          let count = Int(sqlite3_column_bytes(statement, column))
          if count == 0 {
            values[key] = .blob(Data())
          } else if let bytes = sqlite3_column_blob(statement, column) {
            values[key] = .blob(Data(bytes: bytes, count: count))
          } else {
            throw TrainingError.storage
          }
        default: throw TrainingError.storage
        }
      }
      rows.append(SQLRow(values: values))
    }
  }

  func transaction<T>(_ action: () throws -> T) throws -> T {
    try execute("BEGIN IMMEDIATE")
    do {
      let result = try action()
      try execute("COMMIT")
      return result
    } catch {
      try? execute("ROLLBACK")
      throw error
    }
  }

  private func prepare(_ sql: String, _ arguments: [SQLValue]) throws -> OpaquePointer {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
      if let statement { sqlite3_finalize(statement) }
      throw TrainingError.storage
    }
    do {
      let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
      for (offset, argument) in arguments.enumerated() {
        let index = Int32(offset + 1)
        let status: Int32
        switch argument {
        case .integer(let value): status = sqlite3_bind_int64(statement, index, Int64(value))
        case .text(let value): status = sqlite3_bind_text(statement, index, value, -1, transient)
        case .blob(let value):
          status =
            value.isEmpty
            ? sqlite3_bind_zeroblob(statement, index, 0)
            : value.withUnsafeBytes {
              sqlite3_bind_blob64(statement, index, $0.baseAddress, UInt64($0.count), transient)
            }
        case .null: status = sqlite3_bind_null(statement, index)
        }
        guard status == SQLITE_OK else { throw TrainingError.storage }
      }
      return statement
    } catch {
      sqlite3_finalize(statement)
      throw error
    }
  }
}
