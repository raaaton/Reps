# Consistency photo activity — 1.2.5 (87)

## Objective and approved design

Remove the Consistency legend; replace missed-workout dots with xmark; use camera.fill on dates containing progress photos, retaining the accent background for completed workouts. Photos never count as completed workouts. User approved the design, then requested a baseline GitHub push followed by another push after verification. Baseline 1.2.4 (86) is committed/pushed as 4907c05. Each version-worthy change now receives its own commit.

## Scope and decisions

Keep the existing AES-GCM media/metadata, Keychain, Face ID and revocable leases. Vault schema1→2 adds nullable day_key only; existing encrypted bytes are unchanged. Unauthenticated activity reads aggregate dates/counts only. Existing dates are backfilled during the next normal successful Face ID unlock, using authenticated metadata only, without reading originals or thumbnails. Backfill compares the encrypted metadata snapshot and exact IDs in a transaction to reject stale results. Inserts/metadata edits update ciphertext and indexed date atomically; deletion/reset naturally remove activity. Training database, exports, capabilities and dependencies stay unchanged.

Include photo-only dates in the grid/list/detail and its natural date range. VoiceOver preserves both workout and photo information. Incomplete legacy indexing is disclosed in Progress; photo read failures use a generic message without private identifiers. Settings explains dates/counts are visible outside the locked vault. No real media or on-device databases are read by the agent.

## Implementation and verification

- [x] Add real SQLite migration/preservation, public counting after lock/reopen, mutation/deletion/reset, invalid dates, stale/expired backfill and rollback tests.
- [x] Integrate indexed activity refresh with vault writes/unlock and public attendance, preserving lock cleanup for decrypted state.
- [x] Test photo-only dates, photo plus missed/completed workout, earliest photo range and invalid/future dates.
- [x] Independent security/code review; resolve actionable findings.
- [x] Full host suite, strict Swift lint, metadata/style checks, real xtool build, regenerated metadata and final unsigned inspection.
- [x] Preflight existing identity/signer/certificate/profiles; normal USB installation and postflight. Stop on signing errors. Physical UI/Face ID validation remains the user's responsibility.
- [x] Update documentation and prepare version1.2.5(87) for the authorized dedicated commit/push after checks. Git history and the remote ref establish the publication result. No public IPA Release requested.

## Progress

Baseline: 334 host tests, nine metadata/style checks and strict lint pass. Initial migration test encountered sandbox CFSocket blockage and a test-fixture constructor error; neither is a behavioral RED. Isolated baseline migration regression rerun with guaranteed restoration of temporary source swaps. Current implementation in progress.

## iPhone recipe

Before opening Private Photos, inspect missed crosses/no legend and the one-time legacy-index message. Unlock normally, return to Progress and check camera icons and counts, including a completed-workout day. Relaunch without unlocking the vault: activity persists, images still require Face ID. Add, change date, delete one photo and delete a whole date: counts/icons follow. Confirm original viewing/zoom, background masking and immediate lock remain intact. Check light/dark, Dynamic Type and VoiceOver. Do not reset real photos merely to test the reset branch.

## Verification and delivery results

345 host tests/zero failures7.291s; strict Swift lint empty; nine metadata/style checks pass. Actual xtool build25.46s, regenerated App Intents metadata and embedding2.17s, final unsigned app/widget1.2.5(87) inspection pass without warnings. Isolated migration regression against baseline failed one schema-version assertion; new attendance tests failed seven assertions before implementation. Additional backfill mutation/security/rollback scenarios pass; no separate RED claimed for them.

Independent security/code review found no actionable issue. Its recommendation for a second-row index failure is covered by a real SQLite trigger test, also checking stale backfill after deletion. No original/thumbnail content or actual iPhone databases were read.

Preflight and direct postflight confirm exactly one Sport app, updated1.2.4(86)→1.2.5(87), identical effective identity, signer, entitlements and exact cached certificate, valid >24h; both installed app/widget profiles have valid CMS signatures and match that certificate. Standard device-run.sh exits0, installation/verification100%. Existing SDK/caches/certificates preserved; no signing repair, new capability or dependency. Physical UI/Face ID acceptance remains pending.

Evidence (temporary, not published): /tmp/sport-streak-all-tests-final.log, lint-final.log, build.log, build-embedded.log, inspection.log, install.log, device-preflight.json and device-postflight.json, all with sport-streak- prefix. The initial sandbox SwiftPM attempt stalled at CFSocket and was interrupted; subsequent required tests/builds used normal automatic escalation. No approval rejection or permission-mode change.

## White camera glyph — 1.2.6 (88)

User requests a separate commit before the streak feature. Only the camera.fill foreground becomes white on both neutral and completed-workout cells. Shape/background, dates/counts, vault and attendance logic stay unchanged. Independent app/widget versions and bundle inspector advance to1.2.6(88). Nine metadata/style checks, strict lint, actual xtool build, compiler-derived metadata regeneration/embedding and unsigned bundle inspection pass. No redundant domain tests for a color-only change; last full suite remains345passing on87. Preflight confirms installed87 and same identity/certificate/capabilities with CMS-verified app/widget profiles. Standard USB delivery in progress; physical white-symbol contrast remains to check on iPhone.

White camera delivery confirmed: helper exits0 after a slow final transfer, installation/verification100%. Direct postflight confirms1.2.6(88), same identity/signer/entitlements/exact cached certificate and valid app/widget CMS profiles. Separate commit3c393ca created before the streak implementation; actual white-glyph rendering remains physical feedback. Logs:/tmp/sport-white-camera-*.
