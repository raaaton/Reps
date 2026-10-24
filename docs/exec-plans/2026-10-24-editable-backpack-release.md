# Editable backpack and GitHub release — 1.6.0 (105)

## User request
Group Backpack and Maximum Objects in one native rounded List section, make backpack kg editable in a modal like Maximum Objects, preserve removed explanatory footers. User explicitly authorizes GitHub push and a matching release, and asks to persist that future push requests include release publication. Memory note and project AGENTS rule record that instruction.

## Decisions and implementation
Backpack defaults to3000g, strictly positive integer grams with up to3kg decimals, added exactly once, separate from bodyweight0and excluded from object counts. Keep object-first filtering before500g spacing and configured maximum. Changing the preference affects future choices/validation but never rewrites active/history components. Saved unavailable goals show review rather than silently substituting a composition.

SQLite20 adds preferences.backpack_weight_grams default3000. JSON9 includes backpackWeightGrams;1…8default3000, CSV retains the setting. Propagate to generator/validator/picker/store/goal/completion paths, including legacy-migration fallbacks. Transactional invalid/overflow refusal. No vault/certificate/entitlement changes.

## Verification and publication
Write regressions first for exact totals/default/custom validation, persistence, invalid/overflow rollback, existing goal review, active/history snapshots, JSON/CSV/legacy and19→20migration. Complete host suite/lint/13metadata checks, real debug build/compiler metadata/portrait inspection, independent review and same-identity USB delivery/postflight. Physical UI is user validation, not inferred from build. User explicitly requests publication now.

Use scripts/release-local.sh to build/verify unsigned Release IPA, no personal profile/key/database. Commit verified source, fetch and inspect remote divergence, fast-forward push without force. Tag the exact pushed source version v1.6.0 and publish one IPA asset, no checksum attachment. Verify GitHub main/tag/release and downloaded asset bytes. No duplicate release/tag overwrite.

## Verification results
- Seven new regressions first fail on the missing backpack API. Full409-test suite then passes10.242s. Custom bag is added once; default/persistence/validation/atomic rollback, old-goal review, active/history snapshots, JSON/legacy/CSV and migration covered.
- All production generation/validation/picker/store/goal/completion calls receive current bag grams, with safe default fallbacks during earlier migrations. Object priority, maximum, bodyweight and portrait remain.
- UI groups the two settings in one native Section; Backpack uses a saved-draft kg form with the same cancellation/saving/error conventions. No description footer restored.
- Strict lint,13metadata/style/branding checks, whitespace checks and independent read-only review pass. Actual xtool43.22s plus real metadata embedding2.32s and unsigned app/widget portrait-only inspection pass without compiler warning/error.
- Fresh preflight verifies installed1.5.0(104), expected identity/capabilities/exact existing certificate and CMS-valid app/widget profiles. USB delivery105underway; physical UI feedback is not asserted.
- Remote main has no divergent commits (0remote/5local at initial fetch); releasev1.6.0does not exist. User explicitly authorizes source publication and matching release; project/persistent rules updated. Release packaging and remote publication verification follow.
- Evidence:/tmp/reps-backpack-{red,host,build,metadata,install}.log and /tmp/reps-backpack-{preflight,postflight}.json.

USB delivery confirmed: standard device-run.sh exits0, installation/verification100%. A transient socket connection failure on the first inventory query cleared on retry with usbmuxd active; direct postflight verifies exactly one Reps1.6.0(105), unchanged effective identity/signer/exact certificate/entitlements and CMS-valid app/widget profiles. Grouped settings/editor UI acceptance remains physical user review. Public Release build and authorized publication continue separately.

Final user refinement: replace Save text with the existing white, icon-only checkmark in Backpack, Maximum Objects and inventory item editors, preserving accessibility labels and disabled save states. Build106 identifies this final delivered source. Rebuild/reinspect Release and install before publication.

Final refinement adds white icon-only checkmark Save controls to all three Added Weight editors with accessible Save/Saving labels and existing validation/busy states. Build106 is being revalidated for publication. The initial rerun found missing generated metadata in the post-packaging app folder; regenerated actual compiler metadata before rerunning the pipeline, without deleting caches or changing tests.

Final1.6.0(106) Release pipeline succeeds:409host tests,13metadata/style tests, strict Swift lint, optimized app/widget builds, actual compiler metadata, portrait-only bundle inspection and unsigned IPA verification. Public artifact is dist/Reps-1.6.0.ipa; SHA256 d4014d3a08d2005a2fb48cdc9696bb8370f29ae174700a1d82ac801c11056b4d. No profiles/signing credentials/user database. Rebuilt missing packaging-folder metadata from actual compiler declarations before rerun.
