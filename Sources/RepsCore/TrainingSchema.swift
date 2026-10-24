import Foundation

enum TrainingSchema {
  static func migrate(_ database: SQLiteDatabase) throws {
    try database.transaction {
      let version = try database.query("PRAGMA user_version").first?.integer("user_version") ?? 0
      guard version <= 18 else { throw TrainingError.newerSchema }
      if version == 0 {
        for statement in statements { try database.execute(statement) }
        try seed(database)
      }
      if version < 2 {
        for statement in WorkoutSchema.statements { try database.execute(statement) }
        try database.execute("PRAGMA user_version=2")
      }
      if version < 3 {
        try database.execute(
          "ALTER TABLE workout_exercises ADD COLUMN set_weight_grams INTEGER CHECK(set_weight_grams>=0)"
        )
        try database.execute(
          "ALTER TABLE workout_exercises ADD COLUMN set_ended_at INTEGER CHECK(set_ended_at>set_started_at)"
        )
        try database.execute("PRAGMA user_version=3")
      }
      if version < 4 {
        try database.execute(
          "CREATE TABLE weight_items(id TEXT PRIMARY KEY,name TEXT NOT NULL CHECK(length(trim(name))>0),grams INTEGER NOT NULL CHECK(grams>0),enabled INTEGER NOT NULL CHECK(enabled IN (0,1)))"
        )
        for (id, name, grams) in [
          ("river-book", "La rivière à l’envers", 900), ("cars-book", "1200 voitures", 2100),
          ("programming-books", "2 livres programmation", 1500),
        ] {
          try database.execute(
            "INSERT INTO weight_items VALUES(?,?,?,1)", [.text(id), .text(name), .integer(grams)])
        }
        try database.execute("ALTER TABLE workout_sets ADD COLUMN load_components TEXT")
        try database.execute("ALTER TABLE workout_exercises ADD COLUMN set_load_components TEXT")
        try database.execute(
          "CREATE INDEX history_calendar_day ON workouts(day_key DESC,started_at DESC)")
        try database.execute("PRAGMA user_version=4")
      }
      if version < 5 {
        try database.execute(
          "CREATE TABLE notification_preferences(id INTEGER PRIMARY KEY CHECK(id=1),workouts_enabled INTEGER NOT NULL CHECK(workouts_enabled IN (0,1)),photos_enabled INTEGER NOT NULL CHECK(photos_enabled IN (0,1)),photo_minutes INTEGER NOT NULL CHECK(photo_minutes BETWEEN 0 AND 1439))"
        )
        try database.execute("INSERT INTO notification_preferences VALUES(1,0,0,360)")
        try database.execute("PRAGMA user_version=5")
      }
      if version < 6 {
        try database.execute(
          "CREATE TABLE exercise_goals(catalogue_id TEXT PRIMARY KEY REFERENCES exercises(id) ON DELETE CASCADE,payload TEXT NOT NULL)"
        )
        try database.execute(
          "CREATE TABLE workout_goals(exercise_id TEXT PRIMARY KEY REFERENCES workout_exercises(id) ON DELETE CASCADE,payload TEXT NOT NULL)"
        )
        try database.execute("PRAGMA user_version=6")
      }
      if version < 7 {
        try database.execute(
          "CREATE TABLE import_recovery(id INTEGER PRIMARY KEY CHECK(id=1),payload TEXT NOT NULL)")
        try database.execute("PRAGMA user_version=7")
      }
      if version < 8 {
        try database.execute(
          "CREATE TABLE workout_support(workout_id TEXT PRIMARY KEY REFERENCES workouts(id) ON DELETE CASCADE,payload TEXT NOT NULL)"
        )
        try database.execute("PRAGMA user_version=8")
      }
      if version < 9 {
        try database.execute(
          "CREATE TABLE workout_goal_decisions(exercise_id TEXT PRIMARY KEY REFERENCES workout_exercises(id) ON DELETE CASCADE)"
        )
        try database.execute("PRAGMA user_version=9")
      }
      if version < 10 {
        // Keep elapsed timestamps precise; only recorded working-set results use tenths.
        let rounded = "MAX(100, (duration_ms / 100 + (duration_ms % 100 >= 50)) * 100)"
        try database.execute(
          "UPDATE workout_sets SET duration_ms=\(rounded) WHERE duration_ms IS NOT NULL")
        for event in ["INSERT", "UPDATE OF duration_ms"] {
          let suffix = event == "INSERT" ? "insert" : "update"
          try database.execute(
            """
            CREATE TRIGGER IF NOT EXISTS round_duration_\(suffix)
            AFTER \(event) ON workout_sets
            WHEN NEW.duration_ms IS NOT NULL AND NEW.duration_ms % 100 != 0
            BEGIN
              UPDATE workout_sets SET duration_ms=\(rounded) WHERE id=NEW.id;
            END
            """)
        }
        try database.execute("PRAGMA user_version=10")
      }
      if version < 11 {
        // Inspect columns for old test/recovery databases whose later migrations already ran.
        let columns = try database.query("PRAGMA table_info(schedule_exercises)").map {
          try $0.text("name")
        }
        if !columns.contains("set_count") {
          try database.execute(
            "ALTER TABLE schedule_exercises ADD COLUMN set_count INTEGER NOT NULL DEFAULT 4 CHECK(set_count>0)"
          )
          try database.execute(
            "UPDATE schedule_exercises SET set_count=(SELECT set_count FROM exercises WHERE id=exercise_id)"
          )
        }
        if !columns.contains("goal_payload") {
          try database.execute("ALTER TABLE schedule_exercises ADD COLUMN goal_payload TEXT")
          try database.execute(
            "UPDATE schedule_exercises SET goal_payload=(SELECT payload FROM exercise_goals WHERE catalogue_id=exercise_id)"
          )
        }
        try database.execute("PRAGMA user_version=11")
      }
      if version < 12 {
        try database.execute(
          "CREATE TABLE IF NOT EXISTS body_weight_measurements(id TEXT PRIMARY KEY,day_key TEXT NOT NULL UNIQUE,grams INTEGER NOT NULL CHECK(grams>0))"
        )
        let columns = try database.query("PRAGMA table_info(notification_preferences)").map {
          try $0.text("name")
        }
        if !columns.contains("weight_enabled") {
          try database.execute(
            "ALTER TABLE notification_preferences ADD COLUMN weight_enabled INTEGER NOT NULL DEFAULT 0 CHECK(weight_enabled IN (0,1))"
          )
          try database.execute(
            "ALTER TABLE notification_preferences ADD COLUMN weight_weekday INTEGER CHECK(weight_weekday BETWEEN 1 AND 7)"
          )
          try database.execute(
            "ALTER TABLE notification_preferences ADD COLUMN weight_minutes INTEGER CHECK(weight_minutes BETWEEN 0 AND 1439)"
          )
        }
        try database.execute("PRAGMA user_version=12")
      }
      if version < 13 {
        try GoalReconciliation.updateAll(database)
        try database.execute("PRAGMA user_version=13")
      }
      if version < 14 {
        let columns = try database.query("PRAGMA table_info(workout_goal_decisions)").map {
          try $0.text("name")
        }
        if !columns.contains("goal_payload") {
          try database.execute("ALTER TABLE workout_goal_decisions ADD COLUMN goal_payload TEXT")
          // Older markers did not capture the chosen target. Preserve their current saved choice.
          for decision in try database.query("SELECT exercise_id FROM workout_goal_decisions") {
            let id = try decision.text("exercise_id")
            if let row = try database.query(
              """
              SELECT se.goal_payload FROM workout_exercises e JOIN workouts w ON e.workout_id=w.id
              JOIN schedule_exercises se ON se.schedule_id=w.schedule_id AND se.exercise_id=e.catalogue_id
              WHERE e.id=?
              """, [.text(id)]
            ).first {
              try database.execute(
                "UPDATE workout_goal_decisions SET goal_payload=? WHERE exercise_id=?",
                [try row.optionalText("goal_payload").map(SQLValue.text) ?? .null, .text(id)])
            }
          }
        }
        try LatestExerciseGoals.update(database)
        try database.execute("PRAGMA user_version=14")
      }
      if version < 15 {
        try LatestExerciseGoals.update(database)
        try database.execute("PRAGMA user_version=15")
      }
      if version < 16 {
        try database.execute(
          "ALTER TABLE preferences ADD COLUMN stretching_enabled INTEGER NOT NULL DEFAULT 1 CHECK(stretching_enabled IN (0,1))"
        )
        try database.execute("PRAGMA user_version=16")
      }
      if version < 17 { try SkillSchema.migrate(database) }
      if version < 18 {
        let columns = try database.query("PRAGMA table_info(weight_items)").map {
          try $0.text("name")
        }
        if !columns.contains("quantity") {
          try database.execute(
            "ALTER TABLE weight_items ADD COLUMN quantity INTEGER NOT NULL DEFAULT 1 CHECK(quantity BETWEEN 1 AND 1000)"
          )
        }
        try database.execute("PRAGMA user_version=18")
      }
    }
  }

  private static let statements = [
    """
    CREATE TABLE exercises(
      id TEXT PRIMARY KEY, name TEXT NOT NULL CHECK(length(trim(name))>0),
      tracking TEXT NOT NULL CHECK(tracking IN ('repetitions','duration')),
      set_count INTEGER NOT NULL CHECK(set_count>0), minimum_reps INTEGER,
      maximum_reps INTEGER, duration_seconds INTEGER, enabled INTEGER NOT NULL CHECK(enabled IN (0,1)),
      position INTEGER NOT NULL UNIQUE,
      CHECK((tracking='repetitions' AND minimum_reps IS NOT NULL AND maximum_reps IS NOT NULL
        AND minimum_reps>0 AND maximum_reps>=minimum_reps AND duration_seconds IS NULL)
        OR (tracking='duration' AND minimum_reps IS NULL AND maximum_reps IS NULL
          AND (duration_seconds IS NULL OR duration_seconds>0)))
    )
    """,
    """
    CREATE TABLE schedules(
      id TEXT PRIMARY KEY, name TEXT NOT NULL CHECK(length(trim(name))>0),
      weekday INTEGER NOT NULL UNIQUE CHECK(weekday BETWEEN 1 AND 7),
      enabled INTEGER NOT NULL CHECK(enabled IN (0,1)),
      reminder_minutes INTEGER CHECK(reminder_minutes BETWEEN 0 AND 1439)
    )
    """,
    """
    CREATE TABLE schedule_exercises(
      schedule_id TEXT NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
      exercise_id TEXT NOT NULL REFERENCES exercises(id), position INTEGER NOT NULL CHECK(position>=0),
      PRIMARY KEY(schedule_id,exercise_id), UNIQUE(schedule_id,position)
    )
    """,
    """
    CREATE TABLE preferences(
      id INTEGER PRIMARY KEY CHECK(id=1), rest_seconds INTEGER NOT NULL CHECK(rest_seconds>0)
    )
    """,
  ]

  private static func seed(_ database: SQLiteDatabase) throws {
    let exercises = [
      ("bulgarians", "Bulgarians"), ("push-ups", "Push-ups"),
      ("pike-push-ups", "Pike Push-ups"), ("chin-ups", "Chin-ups"), ("l-sit", "L-sit"),
    ]
    for (position, exercise) in exercises.enumerated() {
      let timed = exercise.0 == "l-sit"
      try database.execute(
        "INSERT INTO exercises VALUES(?,?,?,4,?,?,NULL,1,?)",
        [
          .text(exercise.0), .text(exercise.1), .text(timed ? "duration" : "repetitions"),
          timed ? .null : .integer(8), timed ? .null : .integer(12), .integer(position),
        ]
      )
    }
    let schedules: [(String, String, Int, [String])] = [
      ("legs", "Legs", 2, ["bulgarians"]),
      ("push", "Push", 6, ["push-ups", "pike-push-ups"]),
      ("pull-abs", "Pull + Abs", 7, ["chin-ups", "l-sit"]),
    ]
    for schedule in schedules {
      try database.execute(
        "INSERT INTO schedules VALUES(?,?,?,1,NULL)",
        [.text(schedule.0), .text(schedule.1), .integer(schedule.2)])
      for (position, id) in schedule.3.enumerated() {
        try database.execute(
          "INSERT INTO schedule_exercises VALUES(?,?,?)",
          [.text(schedule.0), .text(id), .integer(position)])
      }
    }
    try database.execute("INSERT INTO preferences VALUES(1,180)")
  }
}
