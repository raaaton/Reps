# Object priority before spacing and configurable limit —1.5.0(102)

## User request and scope
Correct the prior interpretation: prioritize physical object count across different total weights before filtering choices by500g proximity. Example10kg/5objects versus10.2kg/1object retains10.2kg. Rank count ascending, then total grams ascending for deterministic ties; accept a choice only if500g away from every already accepted higher-priority choice, then present ascending by total weight. Preserve bodyweight/backpack, saved selections, active/history snapshots and portrait.

Add Maximum Objects in Settings→Added Weight, default10excluding the backpack, configurable1…1000through a native numeric field/stepper in a saved draft. Inventory quantities remain independent. Apply the chosen maximum consistently to generation, progression, validation, goals and UI; reject invalid/too-complex changes atomically, with existing error handling.

## Persistence and compatibility
SQLite19 adds preferences.maximum_weight_objects default10, JSON8 includes maximumWeightObjects and accepts1…7with default10. CSV keeps the preference. No vault/signing identity/capability change. No push/release authorized.

## Verification
Red tests for heavier/lighter preferred neighbors before spacing, physical copy counts, exact500boundary/ties and reverse input. Preference tests for default/persistence, limits below/above10, invalid/complex rollback, active/history snapshots, JSON/legacy/CSV/migration. Full host suite, lint, metadata, real xtool/compiler metadata/portrait-only inspection, independent review, usual same-identity USB pre/postflight and delivery. Device UI/selection behavior remains user review.

## Results
- Three new spacing cases reproduce four failures before implementation. Five preference cases then fail on the missing API. After implementation all 402 host tests pass (9.804 s). The initial Swift tuple-expression inference timeout was resolved with explicit types/separate sorting rather than changed behavior.
- Ranked candidates are filtered using adjacent 500 g buckets, preserving exact boundaries, deterministic lower-weight ties and safe nonnegative Int differences. Output is sorted by grams; existing feasible filtered-out selections retain their exception.
- Default 10 and configurable 1–1,000 propagate through generation, validation, saved goal availability/review, progression and UI, including completion and legacy migration helpers. SQLite 19 / JSON 8 restore the preference; older archives use 10 and CSV preserves it. Active/history snapshots are unchanged.
- Native Saved draft form in Added Weight uses a numeric field/stepper with Cancel/Save, disabled during saving; invalid/complex updates leave state intact with an error.
- Strict lint, 13 metadata/style/branding tests and whitespace checks pass. Actual native compilation 45.18 s, compiler metadata embedding 2.85 s, unsigned app/widget inspection passes without warnings/errors and confirms portrait-only. Final incremental native check covers disabled Cancel while saving.
- Independent read-only reviewer approves object-first spacing, bucket boundaries/overflow safety, policy propagation, transactional rollback, migrations/closed JSON/CSV compatibility and snapshot preservation without actionable findings.
- Fresh preflight verifies one installed 1.4.1 (101), same expected identity/capabilities, exact existing certificate valid over 24 h and CMS-valid app/widget profiles. USB delivery/postflight follow before physical review. No GitHub push or public release.
- Evidence: /tmp/reps-priority-{red,host,build,metadata,install}.log, /tmp/reps-limit-red.log and /tmp/reps-priority-{preflight,postflight}.json.

USB delivery confirmed: device-run.sh exits 0, install/verification 100%, final deployment rebuild 3.35 s. Direct postflight verifies exactly one Reps 1.5.0 (102), identical effective bundle identity/signer/exact existing certificate/entitlements and valid CMS-verified app/widget profiles. Final native checks after disabling Cancel during saving took 10.91 s + 2.71 s. Physical Maximum Objects editing/persistence, object-first near-weight choices and portrait remain user review. No GitHub push or public release.
