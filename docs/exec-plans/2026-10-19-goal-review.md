# Accepted exercise edits and load review

## Objective and user authorization

User requests that saving an exercise change automatically accepts the corresponding future goals, without a second review. Retain explicit review for unavailable load compositions. Progress must show Review needed whenever a workout goal still needs review, instead of its generic placeholder or a misleading goal summary. No automatic selection of a replacement load.

## Decisions

Preserve each workout's set count and exact saved load composition. Keep repetition targets within the new range (clamp only when the range changes), fill new/converted repetition targets from the minimum, clear reps for duration targets, and use the newly configured duration. Preserve valid custom targets on name-only changes. Persist definition and targets together. Active workout snapshots and history never change. Migrate already-stale future goals transactionally in schema13. Apply the same normalization to JSON restore preview, keeping recovery/historical data intact.

Progress retains its native text row and Dynamic Type/VoiceOver. A review status takes precedence if any assigned goal is incompatible or its exact composition is unavailable; the load warning names the load explicitly once the exercise mismatch is resolved. This is a Sport rule, not a HIG requirement. HIG Lists and tables/Typography previously consulted; no new visual control.

## Implementation and verification

1. Tests for range/type/duration changes across workouts, unchanged active snapshots, unavailable exact compositions, rollback, migration and imports. Observe red against previous behavior.
2. Pure goal reconciliation plus transactional catalogue/timed-goal updates and schema13 data migration. Normalize restore preview. Shared review predicate used by Progress.
3. Full host suite, strict lint, independent targeted review, App Intents metadata tests, xtool build and unsigned inspection. USB installation with effective identity/certificate/capabilities checks; device rendering and interaction require user feedback before GitHub.

## Progress

- [x] Request and current goal/edit/load logic reviewed; current installed build69.
- [x] Implementation and full verification: 257 host tests, 6 metadata, strict lint, independent targeted review, xtool and unsigned inspection.
- [x] USB delivery and postflight: 1.1.0(70), same identity/certificate/capabilities.
- [ ] Physical iPhone feedback.

Keep the existing dirty checkout and all prior user changes. No reset/worktree/commit/push. Initial test compile hit an await-in-XCTUnwrap autoclosure; test corrected before product edits.


Verification so far: first six behavioral tests red with 19 assertions, then green; full 257 host tests pass / zero failures (13.327s), strict Swift lint clean. Nine new scenarios cover reconciliation, review state and rollback. Legacy restore test updated for the new explicit policy. xtool build and independent review in progress.


Final local checks: 257 tests / zero failures (13.327s), six metadata tests pass, strict lint clean. Independent scoped review: no actionable findings; physical readability and refresh still require iPhone testing. xtool61.12s + metadata packaging4.90s pass; unsigned build1.1.0(70) has expected app/widget, purposes and sound. Preflight confirms exactly one Sport1.1.0(69), same identity and exact valid certificate. USB delivery successful (code0, install/verify100%). Postflight confirms exactly one Sport1.1.0(70), identical effective identity and exact certificate, valid app/widget CMS profiles and unchanged capabilities. Physical iPhone checks pending; no commit/push/release.
