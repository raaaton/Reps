import Foundation

enum VaultVideoSchema {
  static func migrate(_ db: SQLiteDatabase) throws {
    try db.transaction {
      try db.execute(
        "CREATE TABLE vault_movements(id TEXT PRIMARY KEY NOT NULL,metadata BLOB NOT NULL)")
      try db.execute(
        "CREATE TABLE vault_videos(id TEXT PRIMARY KEY NOT NULL,movement_id TEXT NOT NULL REFERENCES vault_movements(id) ON DELETE CASCADE,metadata BLOB NOT NULL,thumbnail BLOB NOT NULL,byte_count INTEGER NOT NULL,import_session TEXT NOT NULL,complete INTEGER NOT NULL DEFAULT 0 CHECK(complete IN (0,1)))"
      )
      try db.execute(
        "CREATE TABLE vault_video_chunks(video_id TEXT NOT NULL REFERENCES vault_videos(id) ON DELETE CASCADE,position INTEGER NOT NULL,ciphertext BLOB NOT NULL,PRIMARY KEY(video_id,position))"
      )
      try db.execute("PRAGMA user_version=3")
    }
  }
}
