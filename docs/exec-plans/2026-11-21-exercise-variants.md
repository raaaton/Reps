# Exercise variants Implementation Plan

> **For agentic workers:** Use executing-plans to implement inline, task by task.

**Goal:** Independent manual progressions per exercise and lossless targeted L-sit/V-sit fusion.
**Architecture:** Explicit variant identities and frozen variant metadata in exercise snapshots; variant/context goals, schedule selections, persistent session lock. Legacy catalogue identities remain forensic facts and resolve through a targeted alias map.
**Tech Stack:** Swift, SwiftUI, SQLite, existing xtool/SDK; no dependencies.
**Spec:** docs/exec-plans/2026-11-21-exercise-variants-design.md

## Global constraints

Real Reps repository requested: no worktree relocation. Preserve existing ROADMAP diff and caches. iOS 26 minimum. Manual selection only. No changed signing identity or vault crypto. Patch 1.5.9 and new delivery build. User requests direct implementation on 21 November.

## Review focus

- A cancelled countdown must not unlock variant selection.
- Different variants with identical names must retain separate goals.
- Renamed variants must keep frozen historic labels.
- Old archives and CSV must remain readable without inventing results.
- A workout containing both old identities must preserve both occurrences.

## Task 1 — Variant model and transactional migration

Files: new ExerciseVariant.swift, ExerciseVariantRepository.swift and ExerciseVariantSchema.swift; TrainingModels.swift, TrainingSchema.swift, RepsRepository.swift; ExerciseVariantTests.swift.
Interfaces: ExerciseVariant with stable id/exerciseID, metadata and settings; snapshot.variants; schedule.variantIDs; TrainingExercise.variant snapshot; saveVariant/archiveVariant.
- [x] Write tests for base migration/reopen, decimal parsing/free units, named distinct variants and rollback.
- [x] Run filtered host tests and observe missing feature failures.
- [x] Implement model, migration, repository and schedule persistence.
- [x] Run filtered tests and full host suite.

## Task 2 — Goals and sessions

Files: GoalRepository, GoalReconciliation, LatestExerciseGoals, ExerciseGoal, WorkoutRepository/Models/Reading, HistoricalWorkoutEditing, ManualWorkout, SetCorrection, analytics.
Interfaces: variantID-aware goalContext/history/previousPerformance; selectWorkoutVariant(workoutID:exerciseID:variantID:); frozen snapshots and persistent lock.
- [x] Write failing independence, context, selection/locking and historical rename tests.
- [x] Implement variant filtering and goal persistence without cross-variant fallback; preserve workout set counts and program selection.
- [x] Run new tests and complete host suite; resolve regressions.

## Task 3 — Transfers and targeted fusion

Files: TrainingTransferModels/Repository/Validation, TrainingJSONShape, TrainingCSV, PortableBackupRepository; targeted fusion repository; tests.
Interfaces: versioned legacy decoding; alias and migration metadata survive restore; explicit targeted manifest with exact source IDs.
- [x] Write failing archive/CSV roundtrip and old-format tests, merge dual-occurrence/idempotence/rollback/active tests.
- [x] Implement backward-compatible transfers and targeted transaction with recovery snapshot.
- [x] Acquire consistent training-only copy from connected device; inspect exact identities and prepare manifest. Never infer identity by name alone.
- [x] Run targeted tests and full suite.

## Task 4 — Native UI and delivery

Files: TrainingStore; Settings variant editor and workout rows; Workout selection; Progression/History; plist/version inspection; README/DESIGN/BUILD/SECURITY.
- [x] Implement native forms, menu selection, frozen history labels and progression filtering.
- [x] Strict Swift lint, metadata tests, host suite, actual xtool build, metadata embedding and unsigned bundle inspection.
- [x] Independent final review and fixes; update documentation with actual evidence.
- [x] Verify installed identity/capabilities/provisioning, deliver with device-run.sh and verify postflight. Stop on provisioning/signing error.
- [x] Dedicated local version commit; no push requested. Report physical accessibility/UI checks honestly.

## Progress

Planning: source inspected; schema 21/archive 10/CSV 2. Existing unique(workout,catalogue) forbids replacing both old identities blindly. Personal source IDs not established yet. No application edits at plan creation.


## Implementation and review evidence

21 November: implemented schema 22, archive 11 and CSV 3; native variants editor,
program selection, persistent first-set lock, frozen metadata, per-variant goals,
charts and historical/manual-entry support. Exact personal IDs were verified from
a consistent USB schema-21 training-only copy. The targeted manifest reactivates
l-sit and maps the verified V UUID to its own stable variant; startup/restore
snapshot reads apply only this exact manifest, defer while affected work is active,
and keep a full SQLite recovery copy before the transaction.

Real-copy test preserves every workouts/workout_sets/workout_rests/
workout_goal_decisions row, all six L and one V occurrences, and idempotent reopen.
Host recovery: outputs/recovery/2026-11-21-exercise-variants/ (ignored, mode 0700;
training copy mode 0600). No private-vault file read, no personal data committed.

Independent review by variant_review found goal-base projection/restore loss,
untrained-variant goal recomputation, progression initial-task identity,
parent/base-editor overwrites, stale schedule selections, aliased-history purge,
dual-slot goal/picker issues, switched-variant load decisions, mixed summary facts
and timed-variant goal reconciliation. Corrected these paths and added regressions.

Ruling: editing a variant measurement preserves its identity and frozen historical
labels, per the explicit user requirement; no unrequested auto-fork or prohibition.
Ruling: historical edits retain the established product rule of not automatically
recalculating future goals (docs/DESIGN.md); suggestions remain variant-filtered.
Native execution in the real repository follows the user's explicit request;
no worktree relocation or push/release.

Final verification before install: 467 XCTest / zero failures (10.18 s) and
10 Swift Testing / zero failures (0.066 s), strict full Swift lint, 13 metadata
checks, real xtool app/widget build (15.02 s), compiler metadata generation,
embedding build (2.24 s), unsigned 1.5.9 (131) inspection and git diff --check pass.
Preflight verifies installed 1.5.8 (130), existing effective identity/capabilities,
exact cached certificate and CMS-valid app/widget profiles expiring 28 November.
Delivery completed: standard helper exits 0/install+verification 100%; device postflight verifies 1.5.9 (131), identity/signer/entitlement/certificate continuity and CMS-valid app/widget profiles. CoreDevice launch failed with code 10002; owner opened Reps manually. On-device training readback verifies schema 22, one recovery copy and one merge marker, six L and one V occurrences, correct V program assignment and exact preservation of every row in workouts, workout_exercises, workout_sets, workout_rests, workout_goal_decisions and workout_goals. Actual copy and readbacks remain ignored/local.

Physical owner acceptance of native menus, large text and VoiceOver is pending; no further milestone is started. Local dedicated commit follows verified delivery. Final host evidence: 467 XCTest / zero failures (10.18 s), 10 Swift Testing / zero failures (0.066 s).
