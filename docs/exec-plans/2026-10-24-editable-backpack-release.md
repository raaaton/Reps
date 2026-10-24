# Editable backpack and GitHub release — 1.5.1 (107)

## User request and scope
Group Backpack and Maximum Objects in one native rounded List section. Edit backpack kilograms in a saved-draft modal like Maximum Objects. Replace Save text by the existing white checkmark in all three Added Weight editors; keep accessible labels, busy/validation states and no explanatory footers. Preserve quantities, object-first filtering before500g spacing, configurable maximum and portrait lock.

User explicitly authorizes GitHub push and matching release and asks to persist that future push requests include release publication. Project AGENTS and persistent memory record this. The user subsequently corrected excessive minor numbering: these small additions require1.5.1rather than1.6.0. AGENTS now reserves minor for substantial product evolution and defaults small additions to patch.

## Implementation
Backpack defaults to3000g, strictly positive integer grams parsed with the existing kg parser (up to3decimal places), added once and excluded from physical object counts. Bodyweight remains0. SQLite20adds preferences.backpack_weight_grams; JSON9includes backpackWeightGrams, versions1…8default3000and CSV retains it. Closed private/unknown-field validation stays. Candidate totals validate before transactional writes; invalid/overflowing changes roll back atomically.

Propagate current bag grams through generator/validator/picker/store/goal/completion and legacy migration fallback paths. A changed bag weight makes incompatible exact goals show Review needed without silent substitution. Active/history component snapshots remain unchanged. No vault/key/certificate/entitlement changes.

## Verification evidence
Seven new BackpackWeightTests first failed against the missing API. Full409-test suite passes, covering exact/default/custom totals, persistence/precision, invalid/overflow rollback, old-goal review, active/history preservation, JSON/legacy/CSV and19→20migration. Strict Swift lint,13metadata/style tests, whitespace checks, real native app/widget builds and independent read-only review pass. Real compiler metadata and unsigned portrait-only app/widget inspection pass. No physical UI acceptance inferred.

Earlier1.6.0(105)was installed using the normal helper; postflight verified one Reps app, unchanged effective identity/signer/exact certificate/entitlements and CMS-valid profiles. First transient socket query failure cleared on retry. Checkmarks were included in1.6.0(106), which was published at source d98ee335c3f1c4767822b648300ee6652d4ce846. Downloaded IPA was byte-identical and inspected. The user immediately corrected that excessive minor numbering. It is being replaced by1.5.1(107), rebuilt and reverified. Generated metadata missing from the post-packaging folder was recreated from compiler output before tests; no cache deletion or test weakening.

## Publication and delivery
Build/verify107using scripts/release-local.sh, commit exact verified source, fetch/check origin/main ancestry, fast-forward push without force, tagv1.5.1and publish only Reps-1.5.1.ipa. Verify public version, exact source/tag, one IPA asset digest/bytes and downloaded unsigned bundle. Keep erroneousv1.6.0release/tag unless the user explicitly authorizes permanent deletion; automatic review rejected deletion without explicit consent. Publish correctedv1.5.1as latest and clearly mark1.6.0superseded. Install107with the existing certificate/profiles, then direct app inventory/CMS postflight. Physical grouping, keyboard, accessibility and editor interactions remain user checks.

Evidence: /tmp/reps-151-{bootstrap,release,install}.log, /tmp/reps-151-publication.json, /tmp/reps-151-remote-release.json, /tmp/reps-151-postflight.json. Prior iteration evidence remains /tmp/reps-backpack-* and /tmp/reps-160-*.

Corrected107pipeline succeeds:409host tests,13metadata checks, strict lint, actual optimized app/widget compilation/metadata, portrait-only and unsigned IPA inspection. Artifact SHA256 f83c98ddf9e592f0aa1f7be09ab21e90caea2fb717375bf7409077ab2072010d.
