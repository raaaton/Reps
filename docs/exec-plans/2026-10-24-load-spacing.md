# Available load spacing —1.3.2

## Objective and decision
Reduce near-identical load choices: ascending exact gram totals, retain the lightest then require at least500g from the last retained value. Exactly500g stays. User explicitly chose10/10.2/10.5→10/10.5. Keep raw inventory validity and saved goal/history/active compositions intact; retain an already selected valid load in its picker even if filtered from new choices.

## Implementation
Add one shared projection after exact subset generation, use it in inventory display, load pickers and progression choices. Do not prune intermediate subset sums (three200g items must still produce600g). Existing bounds on exhaustive generation stay; this change reduces offered choices and does not claim to change exponential worst-case generation. No schema/key/vault change.

## Verification
Tests before helper implementation: strict500g boundary, chained neighbors, exact sums, disabled/unavailable selection handling and existing-choice retention. Add progression behavior regression; run host suite, metadata, strict lint, xtool build and app/widget inspection. Increment patch to1.3.2, next delivery98, same identity/signature USB preflight/postflight; wait for physical feedback and no push.

## Progress
- Read current generator/validation/progression/picker and prior weight ExecPlan. Generator already deduplicates exact totals. Full available-load lists also validate saved goals, so replacing that shared list with the filtered projection would incorrectly invalidate existing choices; leave validation exact.
- Tests written, expected failure before implementation pending observation. No delivery yet.

## Results
- New helper tests first failed compilation because spacedLoads did not exist; after implementation all378host tests pass (7.869s), including4projection cases and progression behavior. Existing goal/workout/history/transfer regressions stay green.
- Shared full available-load validation is unchanged; only inventory display, picker projection and next/lower progression choice use500g spacing. No stored data rewritten, no inventory item deletion, no rounding.
- Strict Swift lint,9metadata/style checks and whitespace checks pass. Actual xtool13.12s, real compiler metadata regeneration, embedding2.15s and app/widget1.3.2(98) inspection pass without warnings/errors.
- Fresh installed97preflight validates expected identity/capabilities, existing certificate valid>24h and CMS app/widget profiles. USB delivery started; no claim of physical interaction acceptance or public publication.
- USB delivery complete: device-run.sh exits0, installation/verification100%. Direct postflight confirms exactly one Sport1.3.2(98), unchanged effective identity/signer/exact existing certificate/entitlements and verified valid app/widget CMS profiles. Evidence:/tmp/sport-load-spacing-{host,lint,build,install,metadata-tests}.log and /tmp/sport-load-spacing-postflight.json.
- Self-review confirmed nonnegative integer subtraction cannot overflow, comparisons use last retained value, selected-load exceptions require exact membership in full inventory, and progression does not replace stored current goals. No vault/media access or new data migration.
- Ready for physical review: Settings→Added Weight and a picker with a previously saved near-neighbor load. No GitHub push/release.
