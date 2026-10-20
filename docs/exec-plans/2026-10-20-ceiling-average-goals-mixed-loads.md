# Ceiling-average exercise goals and mixed-load correction

## User feedback and scope

Build71 screenshot: learned per-set targets are too verbose. User requests a single ceiling-average target: Pike Push-ups12,12,10,12 ->12reps; L-sit17.4,16.1,18.9,17.3 ->18seconds. Actual history retains original numbers. User corrects exercise name: Bulgarians stayed4×8at6.6kg after a completed mixed session1×12at6.6kg plus10,12,11at7.5kg. Root cause confirmed in GoalEngine.lastSessionGoal: uniform-load guard returnsnil for a mixed session, leaving old persisted goal.

## Decisions and implementation

Latest completed exercise session remains the source across workouts; never merge earlier sessions. Select its highest actual load; average only sets at that load, rounding repetitions upward to whole reps and duration upward to whole seconds. Repeat the resulting target for the assignment's own set count. Preserve exact load components and existing explicit different-load decisions. A lower-load high-repetition set must not inflate the heavier target. Same-load custom editing still works. Existing stored results, chart values/totals/callouts, active snapshots, inventory and privacy stay unchanged.

Tests before implementation: examples, exact/fractional seconds, overflow, mixed weighted sets, real live completion and one-time schema14→15 repair with historical snapshots preserved. Schema15 reruns carry-forward once, so installed71 stale goals update on next launch. Full host suite/lint/metadata/xtool/inspection; targeted independent review; authorized same-identity USB delivery and device feedback, no push.

## Progress

- [x] Screenshot/request and actual source guard investigated; exercise clarified as Bulgarians.
- [x] Reproduced behavioral failures and implementation.
- [x] Full verification and independent review.
- [x] USB pre/postflight and delivery.
- [ ] iPhone feedback.

Evidence: five newtests observedred12assertions, then allgreen. Full275/zero failures6.801s; strictlint and6metadata pass. xtool28.68s then metadata embedding2.37s, unsigned72inspection pass. Independent review: no actionable finding; checked exact integer ceiling, overflow, selected highest-load composition, choice normalization and migration15. Preflight oneSport71/same identity/cached certificate valid>24h; app/widget CMS valid/capabilities unchanged. USB delivery in progress.

Delivery blocked before installation: usbmuxd crashed withSIGABRT (`free(): invalid pointer`) while the phone remains visible inlsusb. xtool finished compilation2.39s, then waited for the device; the waiting attempt was stopped gracefully. No provisioning/signature error was reported, no certificate changed. Direct diagnostic confirms usbmuxd.service failed(core-dump); `sudo -n systemctl restart usbmuxd` returned `sudo: a password is required`. User must run `sudo systemctl restart usbmuxd`, then resume the standard USB delivery/postflight. Device last confirmedSport71; do not claim72installed.

USB delivery resumed after user confirmed restartingusbmuxd: serviceactive and app/widget preflightvalid. device-run.sh exited0, build2.33s, installation/verification100%. Direct postflight confirms exactly oneSport1.1.0(72), same effective identity and exact cached certificate; app/widget CMS profiles valid, entitlement dictionaries identical to preflight. Physical validation of goals/mixed-load correction remains pending; no commit/push/release.
