# Progress — shared next-workout presentation

## Objective

Correct excessive top list margin and the false Review needed on variant exercises.
Show the same program-specific Next Workout block regardless of the historical
progression being viewed, with a native menu choosing the progression planned for
that program. Suppress Choose a Goal when any progression already has a saved goal;
never reuse another progression's numeric targets.

## Decisions

User correction on 21 November supersedes variant-filtered Next Workout presentation
from 1.5.9. Charts/results retain their selected progression; future workout targets
resolve the program's saved selection. Each real workout context remains distinct.
Use native List content margins, Picker menu and existing schedule save workflow.
No schema or transfer change. Preserve existing ROADMAP diff. Patch 1.5.10 (132).

## Execution

- [x] Regression tests: resolved program targets, same next workout across viewed
  variants, no false review, genuine incompatible/unavailable goal still reviewed,
  absence of Choose prompt when another progression has a goal without adoption.
- [x] Implement shared target projection, future-workout picker and tighter top margin.
- [x] Full host tests, strict Swift lint, metadata, xtool build/metadata/inspection.
- [x] Verify unchanged iPhone identity/capabilities/certificate, install/postflight,
  document physical owner checks, dedicated local commit. No push requested.


## Verification and review

Four presentation regressions first fail on missing projection APIs, then pass.
Full472XCTest +10SwiftTesting pass, including the real-copy L/V summary and
unchanged history checks. A fifth regression covers the merged dual-slot case:
select canonical base for the former V slot, retain both entries and 3/5 set
counts, preserve both stored goals, then independently select V on both slots and
start successfully. Independent reviewer found the alias metadata and full-program
save risks; fixes keep metadata on aliased bases and use setScheduleVariant to
write only one selection. Reading goals resizes for the assignment without masking
stale repetition/duration settings; original-goal conflict checks run before timed
variant edits update their metadata.

Native25.00s build, metadata/2.11s embedding, unsigned inspection, strict full lint,
13metadata tests and diff whitespace pass. Version1.5.10/build132. Initial USB
preflight verifies installed131, exact existing certificate, identity, entitlements
and CMS-valid app/widget profiles. Preinstallation training snapshot is local only.
Delivery verified: device-run.sh exits 0, install/verification100%; direct postflight
verifies1.5.10(132), unchanged identity, signer, entitlements and exact certificate,
with valid CMS-verified app/widget profiles. All28training tables have identical
rows before/after installation. No schema/format migration, personal data change,
uninstall or GitHub publication. Physical top margin/menu/Dynamic Type/VoiceOver
remain owner acceptance. Dedicated local commit follows verified delivery.
