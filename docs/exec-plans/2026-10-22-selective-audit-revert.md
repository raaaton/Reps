# Selective audit revert — approved 22 October 2026

## Scope and decisions

User explicitly selected **only the three listed changes**, not a complete rollback to GitHub build72. Restore GitHub1.1.0 behavior for history mutations (no future-goal recalculation), recorded-duration labels (whole seconds) and attendance grid (original eager columns/minute calculation). Keep global Stretching/schema16, preserved explicit load decisions, camera error handling and adaptive metric menu. No reverse migration or personal-data rewrite. Previously changed goals cannot be guessed back; this changes future behavior only.

GitHub refreshed: origin/main `648683677f1c405131562b1bc52753fe21a6e72c`, the published1.1.0 source. Full source recovery backup created at `/tmp/sport-before-requested-revert-20261022-162758`, all58changed/untracked files archived and verified. GitHub72 rejects schema16, which justified the user's scope clarification. Skills installed during the audit remain installed.

## Steps and verification

1. Reinstate baseline readers/mutation paths/formatter/attendance views; retain historical decision preservation separately. Remove only audit reconciliation/cache helpers and their superseded tests.
2. Restore baseline test expectations; retain explicit-decision tests and add coverage that history edits never change future goals.
3. Full host/lint/metadata, real xtool build and bundle inspection; independent scoped review, authorized USB install and identity/certificate/profile postflight. Keep caches and existing local changes outside this scope. Build76; no commit/push/release.

## Progress

- [x] Source backup and exact scope confirmed.
- [x] Seven selected source files and two baseline test files restored exactly from fetched origin/main; decision preservation retained separately. Superseded reconciliation/attendance-cache helpers removed.
- [x] Baseline assertions plus the new unchanged-goal scenarios failed before revert (39 selected tests, seven failures including two stale-editor errors); final **284 host tests / zero failures, 7.184s**. Strict lint and six metadata tests pass.
- [x] Real xtool **22.93s**, regenerated metadata, embedding **2.09s**, unsigned app/widget inspection succeed. Independent scoped review approves the exact selective scope and retained corrections.
- [x] Actual-source probe confirms newer manual12 still leaves adopted/next8, accepted4,500g still seeds4,500g after rename, and18,700/500ms display0:18/0:00. Fictional in-memory data only.
- [x] USB installation/postflight: after transient lock/disconnection, device-run.sh exited0 (final rebuild2.40s), installation/verification100%. Direct inventory confirms one Sport1.1.0(76), same identity/signer/exact certificate/entitlements as verified75. Installed app/widget CMS profiles valid, with matching certificate/team and unchanged capabilities. No reverse migration, signing repair or data deletion. Evidence: `/tmp/sport-selective-postflight.txt`.
- [ ] Physical feedback; no push/release.
