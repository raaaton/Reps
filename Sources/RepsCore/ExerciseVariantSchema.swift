import Foundation

enum ExerciseVariantSchema {
  static func migrate(_ database: SQLiteDatabase) throws {
    try database.execute(
      "CREATE TABLE IF NOT EXISTS exercise_variants(id TEXT PRIMARY KEY,exercise_id TEXT NOT NULL,payload TEXT NOT NULL)"
    )
    try database.execute(
      "CREATE TABLE IF NOT EXISTS schedule_variants(schedule_id TEXT NOT NULL,exercise_id TEXT NOT NULL,variant_id TEXT NOT NULL,PRIMARY KEY(schedule_id,exercise_id),FOREIGN KEY(schedule_id,exercise_id) REFERENCES schedule_exercises(schedule_id,exercise_id) ON DELETE CASCADE)"
    )
    try database.execute(
      "CREATE TABLE IF NOT EXISTS variant_goals(variant_id TEXT NOT NULL,schedule_id TEXT NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(variant_id,schedule_id))"
    )
    try database.execute(
      "CREATE TABLE IF NOT EXISTS workout_variants(exercise_id TEXT PRIMARY KEY REFERENCES workout_exercises(id) ON DELETE CASCADE,variant_id TEXT NOT NULL,payload TEXT,locked INTEGER NOT NULL DEFAULT 0 CHECK(locked IN (0,1)))"
    )
    try database.execute(
      "CREATE TABLE IF NOT EXISTS exercise_identity_aliases(source_id TEXT PRIMARY KEY,exercise_id TEXT NOT NULL,variant_id TEXT NOT NULL)"
    )
    try database.execute(
      "CREATE TABLE IF NOT EXISTS targeted_exercise_merges(id TEXT PRIMARY KEY,payload TEXT NOT NULL)"
    )
    var definitions = try database.query("SELECT * FROM exercises").map(
      TrainingExercise.read)
    definitions += try database.query("SELECT payload FROM archived_exercises").map {
      try JSONDecoder().decode(TrainingExercise.self, from: Data($0.text("payload").utf8))
    }
    let hasWorkouts =
      !(try database.query(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='workout_exercises'")).isEmpty
    let historical =
      hasWorkouts ? try database.query("SELECT * FROM workout_exercises ORDER BY rowid DESC") : []
    for row in historical {
      let id = try row.text("catalogue_id")
      if !definitions.contains(where: { $0.id == id }) {
        definitions.append(try WorkoutExercise.read(row, database: database).definition)
      }
    }
    for exercise in definitions {
      let variant = ExerciseVariant.base(for: exercise)
      try database.execute(
        "INSERT INTO exercise_variants VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload",
        [.text(variant.id), .text(exercise.id), try encode(variant)])
    }
    if hasWorkouts {
      try database.execute(
        "INSERT OR IGNORE INTO workout_variants SELECT e.id,e.catalogue_id||':base',NULL,CASE WHEN e.set_started_at IS NOT NULL OR EXISTS(SELECT 1 FROM workout_sets s WHERE s.exercise_id=e.id) THEN 1 ELSE 0 END FROM workout_exercises e"
      )
      try database.execute(
        "CREATE TRIGGER IF NOT EXISTS lock_workout_variant AFTER UPDATE OF set_started_at ON workout_exercises WHEN NEW.set_started_at IS NOT NULL BEGIN INSERT INTO workout_variants(exercise_id,variant_id,locked) VALUES(NEW.id,NEW.catalogue_id||':base',1) ON CONFLICT(exercise_id) DO UPDATE SET locked=1; END"
      )
    }
    try database.execute("PRAGMA user_version=22")
  }
  static func encode<T: Encodable>(_ value: T) throws -> SQLValue {
    .text(String(decoding: try JSONEncoder().encode(value), as: UTF8.self))
  }
}
