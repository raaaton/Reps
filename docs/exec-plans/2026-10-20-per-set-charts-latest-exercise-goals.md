# Per-set chart values and latest exercise goals

## Objective and accepted scope

20 October: chart points use the average per recorded working set (volume, repetitions, duration); added weight remains maximum actual load. Drag callouts and detailed results retain workout totals and add `• N sets`. Period totals remain exact sums. Every exercise's latest completed session, across all workouts, supplies future targets after completion. Preserve each assignment's set count: truncate ordered targets or repeat the last known set when adding sets. User explicitly confirms timed goals also follow actual durations, at existing tenth-second precision. Apply once to existing history on upgrade, without reading/exporting personal device data. Preserve explicit load decisions, historical/active snapshots, unrelated local edits; no push.

## Implementation

1. Regression tests against current chart values and real SQLite live completion/migration. Add per-set duration targets to the existing goal snapshot, preserving legacy decoding and strict validation/backup shape.
2. One transactional carry-forward path shared by completion and upgrade, selecting latest completed exercise globally. Propagate resized targets across assignments. Exact saved load composition remains visible if unavailable; no silent replacement. Preserve explicit transition decisions. No goal from cancelled/incomplete or incompatible metric data.
3. Average chart projection; totals unchanged in summaries/callouts/details. Explicit per-set axes, descriptions and VoiceOver values. Render duration targets in goal rows, working sets and warm-up snapshot. Timed manual customization remains available.
4. Full host suite, strict Swift lint, metadata, xtool builds and bundle inspection. Review targeted diff. USB install via authorized device workflow after identity/certificate/capability checks; wait for iPhone feedback before GitHub.

## Evidence and limits

Current checkout contains prior uncommitted features through build70; preserve them. HIG Charts reviewed: descriptive content must explain values and units; access to exact details remains available without dragging. Averages and last-set extension are Sport rules. Physical gestures, layout, Dynamic Type and VoiceOver require iPhone checks.

## Progress

- [x] Scope and latest-exercise (not workout) clarified; actual timed targets confirmed.
- [x] Behavioral red/green tests and implementation.
- [x] Full verification and targeted review.
- [x] USB delivery with pre/postflight.
- [ ] Physical iPhone feedback.


Evidence: seven initial new tests observed red (chart, global completion/upgrade/atomicity, duration Codable validation), then green. Two review regressions red with four assertions before fixes. Full270tests/zero failures (7.633s),6metadata/strictlint pass. xtool14.89s + metadata2.61s, unsigned71 inspection pass. Reviewed corrections include repeat-last resizing, seeding only newly assigned exercises, captured decision payload, same-load target refresh and untimed clear. No remaining actionable review findings. Schema14 captures explicit goal payloads; older markers can only preserve their currently saved choice because older builds did not store the original decision payload. JSONv4 adds validated durationsMS, readsv1/2/3. First sandbox test/build blocked by CFSocket/cache; elevated runs used existing caches. Initial test fixture date/argument/XCTest-constructor errors corrected before final suite. Preflight device confirms oneSport70, existing exact certificate valid>24h, app/widget CMS profiles valid and normal capabilities. USB installation in progress.


Delivery complete: device-run.sh exited0, installation/verification100%. Direct postflight confirms exactly oneSport1.1.0(71), same effective identity and cached certificate; app/widget CMS profiles valid and entitlement dictionaries identical to preflight. No private training/media read or exported. First app launch applies schema14 refresh; actual device display/state still requires user review. No commit/push/release.
