# Portrait and weight quantities — 1.4.0 (100)

## Objective and accepted design
Lock all iPhone app presentations to portrait. Add per-item available quantities, default1, unit weight, grouped identical copies and unique exact load totals. Example10×100g books gives1kg added objects plus the existing3kg bag, once. Preserve500g offered-choice spacing and all historical/active snapshots.

## Decisions and implementation
- Bounded extension of existing inventory/editor/generator; quantity1…1000, native stepper and direct integer entry.
- Bounded-count generation per item, no individual-copy identities/permutations. Deterministic by item id and count; retain one composition per total. Existing4095total/200000component-work bounds retained.
- Snapshot component grams remain total component weight; additive quantity (default1 for legacy), computed unit weight and grouped label across preparation/picker/history/inventory.
- SQLite18 adds inventory quantity default1 transactionally; old rows and snapshots unchanged. JSON7 writes quantities, reads1…6 with default1; unknown/private fields still rejected. CSV component JSON retains quantities.
- Portrait declaration plus app delegate mask covers system fullscreen presentations without changing media assets.
- No push/public release. Existing same-identity USB delivery authorized; physical review remains separate.

## Verification
Tests first: ten books/count totals, mixed-count dedup/order, disabled inventory, invalid quantity/overflow, persistence/rollback,17→18migration, active/history snapshot preservation, JSON/CSV restore and legacy imports. Then complete host suite, strict format lint, metadata tests, real xtool build, compiler metadata embedding and unsigned bundle inspection (including portrait). Independent code review; USB preflight/install/postflight preserving certificate/identity/capabilities. Physical rotation including video, quantity editing and ten-book preparation need user review.

## Progress
- User approved design and explicitly repeated portrait requirement. Canonical root is Reps; old chat writable-root metadata is stale. Changes use normal automatic review; permissions configuration unchanged.
- Baseline clean7c303cc. Tests prepared before implementation.

## Verification results
- Seven new regressions first fail compilation because quantity is absent, then pass. Complete suite385tests passes9.209s. Earlier six failures exposed derived legacy JSON fixtures still containing new fields and two partial historical SQL fixtures lacking the existing weight_items table; fixtures corrected, production compatibility rules retained.
- Strict Swift lint,13metadata/style/branding checks and whitespace checks pass. Actual xtool24.51s, compiler metadata regenerated/embedded2.66s, no compiler warnings/errors, unsigned app/widget inspection verifies1.4.0(100)and portrait-only final plist. Inspection output now derives version from the inspected plist to avoid stale human-readable text.
- Independent read-only reviewer approved algorithm/determinism, migration/import compatibility, snapshot preservation, native editor and global portrait wiring without actionable findings.
- Preflight directly validates installed1.3.3(99), exact existing certificate valid>24h, expected same identity/capabilities and CMS-valid app/widget profiles. Standard USB delivery in progress; physical behavior remains user validation.
- Evidence:/tmp/reps-quantity-{red,green,host,build,metadata,install}.log and /tmp/reps-quantity-{preflight,postflight}.json. No private media/database read, certificate replacement or GitHub publication.

USB delivery confirmed: device-run.sh exits0, install/verification100%. Direct postflight validates exactly one Reps1.4.0(100), identical effective bundle identity/signer/exact cached certificate/entitlements, and valid CMS-verified app/widget profiles. Actual rotation, quantity editor/layout/accessibility and personal-data review remain physical user checks. No GitHub push/public release.
