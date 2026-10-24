# Audit corrections — approved 22 October 2026

## Objective and decisions

User approved applying the audit in `plans/2026-10-22-sport-audit.md`. Fix stale future goals after history add/edit/delete, preserve explicit load decisions on metadata-only edits, retain recorded duration tenths and distinguish camera cancellation from cleanup failure. Preserve existing uncommitted Stretching changes, active snapshots, custom goals, privacy, dependencies and native motion. No GitHub push before physical feedback.

Bounded corrections to existing flows; audit recommendations and user approval supply the design. Implement inline with independent final review. Existing dirty working tree is the target and stays in place; no reset/worktree switch or cache cleanup.

## Implementation steps

1. Add failing real-SQLite regressions for history mutations, explicit decision preservation/invalidation, custom-goal preservation and rollback. Derive prior automatic goals before mutation and only reconcile assignments still matching them; clear an automatic goal when its final source disappears. Preserve unchanged decisions across history row reconstruction.
2. Display duration tenths through the existing performance formatter without altering rest timers. Camera reports a generic import failure and keeps fail-closed cleanup; no cryptography/key/protection-policy change.
3. Make attendance columns lazy, avoid rebuilding attendance for unchanged day/history/schedule, and adapt metric controls at large text sizes. Preserve full-history semantics. Camera encoding optimization requires measured device evidence and remains a profiling item.
4. Full host suite, strict lint, metadata tests, independent review and real xtool build/metadata/bundle checks. Verify installed identity/certificate/capabilities before authorized USB deployment; stop on provisioning errors. Record postflight and manual iPhone checklist.

## Verification and progress

- Baseline audit: 281 host tests, six metadata tests and strict lint passed. Two domain failures plus duration truncation reproduced with real sources on fictional data.
- [x] History reconciliation and explicit-decision preservation/invalidation.
- [x] Duration tenths and generic session-guarded camera errors.
- [x] Lazy attendance, cached off-main projection and adaptive metric picker.
- [x] Tests, independent review, real build, USB delivery and device postflight.
- [ ] Physical user feedback. No commit/push/release.

Initial six SQLite regressions failed with 11 assertions, then passed. Three legacy tests assuming manual history never creates a baseline were updated to retain their stale-editor/persistence/schedule-structure checks with the approved baseline. Review found three further cases: edited actual set count, name/enabled metadata in inherited-goal matching, and an unprojectable newer source clearing the old exact goal. All were reproduced before correction. Full **290 tests / zero failures in 6.573 s**, strict lint and six metadata tests pass. Completed-source count normalization is shared by both rated/completed SQL readers and remains in memory; stored program/goal snapshots and generic engine guards remain intact. Matching ignores only name/enabled metadata. An existing unprojectable source retains the exact goal; final-source removal permits clearing.

Ruling: without stored provenance, a goal differing from its old computable automatic baseline is treated as personalized and preserved. No guessed retroactive repair of preexisting stale goals or previously lost decisions. Camera encoding stays a device-profiling item; no speculative concurrency change. Attendance workload is confirmed by 20,752 valid days; optimization preserves the requested historical span without claiming measured iPhone FPS.

An isolated actual-source probe verifies manual result 12 → adopted/next goal 12, accepted 4,500 g → new assignment 4,500 g after rename, and 18,700/500 ms → localized 0:18.7/0:00.5. Fictional in-memory data only. Independent scoped re-review approved with no remaining actionable findings; static review only.

Final reviewed xtool build **11.20 s**, generated compiler metadata, embedding **2.25 s**, unsigned app/widget inspection and six metadata tests passed. Initial sandbox blockers were Swift CFSocket, read-only xtool cache and denied usbmuxd socket; necessary escalations were sent directly to automatic review. No SDK/cache reset or credential/certificate replacement.

Preflight: one Sport 1.1.0 (74), expected effective identity and installed signer matching the existing cached certificate, valid over 24 hours. `device-run.sh` exited **0**, final rebuild **2.29 s**, installation/verification **100%**. Direct postflight confirms **one Sport 1.1.0 (75)**, same identity/signer, exact cached certificate unchanged, effective entitlements identical and installed ProfileValidated true. Device provisioning profiles were retrieved read-only with ideviceprovision and checked with openssl CMS verification: Sport app/widget profiles valid, unexpired, same certificate/team, no App Group/push. No profile removed or certificate revoked/replaced.

## Physical checklist

1. Rename a historical workout with an accepted load choice; inspect its next goal. Correct history and check inherited targets refresh while personalized targets remain. Confirm duration tenths in history and chart details.
2. Progress: metric selection at largest text, full-history scrolling/day selection, return and midnight refresh.
3. Vault: camera Cancel/success, background/return and Face ID. Generic cleanup-error handling was reviewed statically; physical failure injection and camera latency profiling remain unperformed.

Await user feedback before GitHub. Build/install success does not validate these interactions.

## Subsequent scope change

User subsequently requested a selective revert of history-goal recalculation, duration tenths in recorded labels and attendance optimization. See 2026-10-22-selective-audit-revert.md for the replacement build76. Other fixes remain. The evidence above describes the former build75.
