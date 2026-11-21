# Historical progression correction

## Objective

Let the owner change an exercise's progression while editing an existing historical
workout. Preserve workout/exercise/set IDs, timestamps, loads and Feeling; move the
record to the correct variant's history. Keep future program selections and goals.

## Decisions

Existing historical snapshots stay frozen when the progression is unchanged.
An explicit change captures the selected progression's current metadata/settings
on the existing occurrence, retaining its captured parent name and set count.
Historical corrections may use archived progressions; an unavailable current
progression remains selectable as its original frozen identity.
Different tracking modes are permitted only after a native confirmation clears
performance text in the local draft, requiring explicit re-entry. Set IDs/count,
weights and Feeling remain; Cancel or closing without Save leaves stored data alone.
A changed progression invalidates only that occurrence's old progression-specific
goal/decision, matching existing decision invalidation on result corrections.
No automatic recalculation of future goals, schema/format/dependency changes.
Patch1.5.11/build133. Preserve preexisting ROADMAP diff; no push requested.

## Execution and verification

- [x] Failing regressions for stable IDs and values, separated variant history,
  frozen unchanged metadata, archived and cross-metric choices, other-exercise
  isolation, old goal/decision invalidation, unknown/cross-parent rejection.
- [x] Shared historical selection resolver, repository persistence and native menu;
  protect tracking-mode changes with local-draft confirmation.
- [x] Full host tests, strict lint, metadata, native build/embedding/inspection;
  independent review and fixes.
- [x] Same-identity USB installation/postflight and training-data preservation;
  documentation, dedicated local commit and owner iPhone acceptance checklist.


## Review and verification evidence

Targeted initial12tests pass; explicit changing-variant cases preserve IDs/values,
archived selection, new metric validation and unknown/cross-parent rejection.
Additional regressions preserve frozen original metadata after rename/archive and
invalidate only the old variant-specific captured goal/decision, leaving future
goals unchanged.

Independent review found two important existing-path hazards: rebuilding a
historical workout discarded all recorded rests and unrelated interrupted-set
fields; retagging both legacy occurrences to one progression duplicated chart IDs
and counted a session twice. Both were reproduced RED, then fixed. Retained rest
IDs/rows are restored for their original surviving source-set positions; untouched
occurrences retain pending timing/load/components. Chart point IDs now identify
occurrences, displayed workout counts use distinct session IDs, and latest-record
queries consistently break intra-session ties by descending exercise position.
Both histories and both chart points remain available without double-counting the
workout. The targeted41test suite passes after fixes.

Final full480XCTest / zero failures (10.656s) plus10SwiftTesting / zero failures,
strict recursive lint,13metadata checks and whitespace checks pass. Native build,
metadata embedding, unsigned inspection and USB delivery remain in progress.
Preflight verifies the installed132identity/capabilities and exact existing
certificate with valid app/widget CMS profiles. No schema/format migration.
HIG Alerts reference consulted for native confirmation of a changed result type:
https://developer.apple.com/design/human-interface-guidelines/alerts
Physical menu, confirmation cancellation, Dynamic Type and VoiceOver remain owner
checks; no real historical record is retagged automatically by this delivery.


Native compilation first exposed a SwiftUI type-check timeout in the chart delta
label after duplicate-entry support. Moving text construction to typed String
helpers fixes the compiler issue without changing calculated values. Corrected
native build passes10.83s; metadata regeneration/embedding and delivery follow.


## Delivery

Standard USB helper exits0, installation/verification100%. Direct postflight
verifies Reps1.5.11(133), unchanged effective identity, signer, entitlements and
exact existing certificate, with CMS-valid app/widget profiles. All28training
tables are unchanged before/after delivery; no real history was edited for a test.
Corrected native build10.83s, metadata/embedding2.21s and unsigned inspection pass.
480XCTest+10SwiftTesting pass; strict lint and13metadata checks pass.

Owner checklist: History → workout → Edit → exercise → Progression; choose another
progression of the same metric, Save, check its results/IDs and filtered history.
Check archived selection and Cancel; for another metric, verify confirmation then
explicit re-entry before Save. Check large text and VoiceOver. These physical
checks remain owner acceptance. No next milestone, push or public release.
Local dedicated commit follows verified delivery; ROADMAP diff preserved.
