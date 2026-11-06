# Shared exercise catalogue order

## Objective and scope

Owner requests reordering exercises from Progress and Settings → Exercises.
Continue the authorized implementation/delivery workflow without another design
confirmation. Use native Edit/Done and reorder handles in both screens, with one
shared persisted catalogue order. Workout assignments, active/history snapshots,
archives, goals and private media remain independent.

## Decisions

Reuse exercises.position and existing JSON array order; no schema/backup-format
change. Validate the complete unique current catalogue ID set in a transaction.
Temporarily move positions to the negative range, then assign nonnegative indices
without UNIQUE collisions. Reject stale membership and roll back storage errors.
One shared UI controller provides optimistic order, one in-flight write and error
rollback. Native edit mode wraps both List and EditButton. List identity depends on
sorted membership, preserving reorder continuity and the existing deletion workaround.

## Steps and verification

- [x] Host tests before implementation: missing API RED, then three tests GREEN.
  Restart/JSON restore/order persistence and unchanged schedules/goals/active
  snapshots; malformed/stale orders rejected atomically; second-phase trigger
  failure restores every original position.
- [x] Implement catalogue reorder transaction, TrainingStore forwarder, shared
  optimistic controller, native edit controls and both list move handlers.
- [x] Independent review, full host suite, strict lint, metadata and native build.
- [x] Version1.5.8/build130, unsigned inspection, same-identity iPhone delivery,
  local commit and final manual UI recipe. Preserve existing ROADMAP changes.

## Progress

Initial targeted three tests pass (0.05s). Full verification and USB delivery pass.
Real native drag handles/VoiceOver/scroll and cross-tab updates need owner testing;
host/build checks are not proof of rendered iPhone behavior.

Full447XCTest (10.924s) +10SwiftTesting (0.067s), strict lint,13metadata checks,
native build26.42s +compiler metadata embedding2.69s and unsigned app/widget
inspection pass. Independent read-only review finds no actionable issue in EditMode
scope, optimistic rollback, exact ID validation, uniqueness, transfers or workout
preservation. No schema, backup-format, crypto or capability change. Existing
ROADMAP diff stays untouched. Initial USB preflight was blocked: usbmuxd exited
normally when the phone was removed; no Apple USB device is currently visible.
Owner reconnected the cable; preflight verifies129with the same installed identity
and entitlements. Standard USB helper then exits0, installation/verification100%.
Direct postflight confirms one1.5.8(130), same signer, entitlements and exact cached
certificate. No service restart, certificate/profile replacement or data reset.
Evidence:/tmp/reps130-{order-red,order-green,host,lint,
metadata,build,embed,inspection}.log.

Manual owner recipe: tap Edit in Progress, move one exercise and tap Done; verify
the same order in Settings → Exercises, then move from there and check Progress.
Relaunch to confirm persistence; workout-specific order remains separate. Check
native drag handles/scroll/VoiceOver on iPhone. /tmp/reps130-postflight.json records
only app metadata, not personal history or private media. Local commit follows
successful verification; no push/release requested.
