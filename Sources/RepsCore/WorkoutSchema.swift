enum WorkoutSchema {
  static let statements = [
    """
    CREATE TABLE workouts(
      id TEXT PRIMARY KEY, schedule_id TEXT NOT NULL, name TEXT NOT NULL, day_key TEXT NOT NULL,
      started_at INTEGER NOT NULL CHECK(started_at>=0), ended_at INTEGER,
      status TEXT NOT NULL CHECK(status IN ('active','completed','cancelled')),
      rest_seconds INTEGER NOT NULL CHECK(rest_seconds>0),
      CHECK((status='active' AND ended_at IS NULL) OR (status!='active' AND ended_at IS NOT NULL))
    )
    """,
    "CREATE UNIQUE INDEX one_active_workout ON workouts(status) WHERE status='active'",
    "CREATE INDEX workout_history ON workouts(started_at DESC)",
    """
    CREATE TABLE workout_exercises(
      id TEXT PRIMARY KEY, workout_id TEXT NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
      catalogue_id TEXT NOT NULL, name TEXT NOT NULL, tracking TEXT NOT NULL CHECK(tracking IN ('repetitions','duration')),
      set_count INTEGER NOT NULL CHECK(set_count>0), minimum_reps INTEGER, maximum_reps INTEGER,
      duration_seconds INTEGER, position INTEGER NOT NULL CHECK(position>=0),
      feeling_tenths INTEGER CHECK(feeling_tenths BETWEEN 0 AND 100), set_started_at INTEGER,
      UNIQUE(workout_id,position), UNIQUE(workout_id,catalogue_id)
    )
    """,
    """
    CREATE TABLE workout_sets(
      id TEXT PRIMARY KEY, exercise_id TEXT NOT NULL REFERENCES workout_exercises(id) ON DELETE CASCADE,
      number INTEGER NOT NULL CHECK(number>0), repetitions INTEGER, duration_ms INTEGER,
      weight_grams INTEGER NOT NULL CHECK(weight_grams>=0), completed_at INTEGER NOT NULL,
      UNIQUE(exercise_id,number),
      CHECK((repetitions>0 AND duration_ms IS NULL) OR (repetitions IS NULL AND duration_ms>0)),
      CHECK(repetitions IS NOT NULL OR duration_ms IS NOT NULL)
    )
    """,
    """
    CREATE TABLE workout_rests(
      id TEXT PRIMARY KEY, workout_id TEXT NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
      exercise_id TEXT NOT NULL REFERENCES workout_exercises(id), after_set INTEGER NOT NULL,
      status TEXT NOT NULL CHECK(status IN ('running','paused','finished','skipped','cancelled')),
      deadline INTEGER, remaining_ms INTEGER,
      UNIQUE(exercise_id,after_set),
      CHECK((status='running' AND deadline IS NOT NULL AND remaining_ms IS NULL)
        OR (status='paused' AND deadline IS NULL AND remaining_ms>0)
        OR (status IN ('finished','skipped','cancelled') AND deadline IS NULL AND remaining_ms IS NULL))
    )
    """,
    "CREATE UNIQUE INDEX one_live_rest ON workout_rests(workout_id) WHERE status IN ('running','paused')",
  ]
}
