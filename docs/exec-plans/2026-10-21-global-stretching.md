# Global Stretching — approved bounded change

## Objective and decisions

User approved a default-on Stretching switch in Settings → Training. Off removes stretches from preparation and all future workouts, retains warm-up/rest, and ends at final Feeling. Active/history snapshots remain immutable. This execution record follows the project documentation requirement.

## Implementation

- SQLite migration16, saved preference and TrainingSnapshot; capture only when creating workout support.
- Support zero stretches, retain one/two warm-up steps, never complete the workout at the final warm-up; finish at last Feeling when all support is complete.
- Native toggle with save/error handling; conditional preparation and correct finish label.
- JSONv5 preserves flag, accepts legacy1–4 with default on; CSV preserves current setting and carries warm-up-only snapshots.

## Verification and progress

- Two real lifecycle/validation tests observed failing (six failures/errors); transfer test observed failing before archive support.
- Six new scenarios, full281host tests/0failures (7.122s); strict Swift lint and6metadata pass.
- Legacy fixtures corrected to represent their old schemas. Independent code review found a downgrade fixture issue, corrected, and no production findings.
- Real xtool build16.90s, metadata extraction/integration2.52s, unsigned app/widget inspection pass. Initial compiler assertion caused by error shadowing in catch corrected with self.error.
- Preflight: installed1.1.0(72), unique existing effective identity; existing cached certificate valid>24h and listed by Apple. No permission/capability/provisioning configuration changes.
- USB delivery confirmed: device-run.sh exited0 (final rebuild7.43s), install/verification100%. Direct device postflight confirms one Sport1.1.0(73), same effective identity, exact cached signing certificate unchanged, app/widget CMS profiles valid and ordinary entitlements retained (no App Group/push). Physical toggle/flow review awaits the user; no GitHub push or release. Physical checklist in docs/TESTING.md.


## Follow-up — build 74

User requested removing the description below Stretching. Only that explanatory Text is removed; toggle behavior unchanged. Strict lint and six metadata tests pass; real xtool build10.99s. No new domain tests for this text-only removal; the281-test result above covers unchanged domain code. Final metadata embedding2.47s, unsigned bundle inspection passed. USB installation exited0 (rebuild2.59s), verification100%; direct device postflight confirms1.1.0(74), same identity, exact certificate unchanged and valid CMS profiles/capabilities. Visual review awaits the user.
