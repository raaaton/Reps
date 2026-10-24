# Sport → Reps —1.3.3

## Objective
Apply the user-authorized Reps rename to the app, widget, native source/package/build artifacts, active docs, local project directory/registration and GitHub repository/presentation. Keep device identity and all persisted data compatible. User explicitly authorized GitHub changes and push for this rename; no new release binary publication is implied.

## Compatibility boundaries
Keep com.raaaton.sport and .rest-widget, Keychain services, vault AAD/verification bytes, sport.sqlite, preference/notification identifiers, JSON sport.training and CSV sport_csv_version unchanged. Existing exports must remain readable. Add reps:// and continue accepting sport://. Preserve historical Git commits/tags and HelloSport skeleton/caches. Historical documents remain evidence of the old name; update active instructions and new references. Renaming cached compiler files is unnecessary; keep caches.

## Implementation
1. Capture a compatibility baseline and add metadata regressions before edits.
2. Rename public native products, source directories/files, icon resource identifiers, build scripts and active public-facing copy; preserve stable identifiers explicitly. Keep internal Swift module names Sport/SportRestWidget/SportLiveSupport because ActivityKit/AppIntents may serialize them; RepsCore can be renamed safely. Version1.3.3 next build99.
3. Verify host tests, metadata, strict lint, actual xtool build/icon/metadata regeneration and app/widget inspection. Independently review security byte/identity invariants. Install normally and verify same device app/keychain identity.
4. Rename GitHub repository to raaaton/Reps, update origin and public metadata/release presentation, fast-forward authorized verified source to default branch without rewriting history.
5. Move local folder to iOS/Reps, keep a documented compatibility symlink for existing tooling/chat paths, preserve caches and update only project display/path registry (never permission/writable-root settings). Validate clean checkout, origin and new path.

## Verification and progress
- Clean checkout1fe63dd, feature branch exactly3commits ahead of origin/main, no divergence. GitHub raaaton/Reps does not exist. Existing profile/identity must be checked again before installation.
- Current vault AAD uses literal Sport bytes; blind replacement would corrupt access. Exact baseline tests will protect these constants and persisted identifiers. No private device data needs to be read for rename verification.
- Work pending; no external rename or new install claimed.

### Review findings and corrections
- Metadata regressions were observed failing before rename, then passing. Twelve persistence baselines remain unchanged; VaultCryptography implementation is byte-identical except its module import.
- First structural build exposed a stale widget symlink; corrected it to ../Reps/Features/LiveActivity/RestPauseIntent.swift. Host fixture path mismatch corrected by renaming the CSV demo file, not its contents/schema. All378host tests then pass10.303s.
- Independent security review confirms no crypto/SQLite/Codable business changes after normalizing names; only additive reps:// URL acceptance. To avoid unproven ActivityKit/AppIntent serialized-type migration, internal UI/live modules retain their old identities while products/executables/folders/display names use Reps. Metadata generation now separates module and executable names, with a regression protecting legacy type identities.
- actool required the normal escalation after sandbox CFSocket failure; existing caches retained. Icon geometry is the same barbell, no obsolete lettermark to replace.

### Delivery and external rename
- Reps1.3.3(99)normal USB helper exits0, installation/verification100%. Direct installed-app postflight verifies exactly one same-bundle app, display name/executable Reps, identical signer/exact certificate/entitlements and valid CMS app/widget profiles. Native synthetic video probe99passes after checking unique run token; no personal media/database read.
- GitHub repository ID preserved while renaming raaaton/Sport→raaaton/Reps; origin updated. All23release titles and23asset filenames renamed, same asset IDs/tags/IPA bytes retained. Each historical release explicitly identifies its binary as predating the rename, avoiding a false claim that those embedded app names changed. No new binary release created.
- Real checkout moved to /home/raton/Documents/Code/iOS/Reps with .build/host caches and git history preserved. /home/raton/Documents/Code/iOS/Sport is a compatibility symlink so existing tools/chat paths do not break.
- Codex project registration is cached in the running app: a targeted name/path file update was overwritten by the running app. The old registration remains valid through the compatibility symlink; no permissions or writable-root settings changed. Native UI project-rename capabilities are unavailable in this session, so its visible cached sidebar label needs refreshing/reopening from the new path. Do not claim this UI label changed.


### Final verification
-378host tests/zero failures10.303s before moving the root;13metadata/style/branding/compatibility tests, strict Swift lint and whitespace checks pass. Final post-move host rerun is recorded below.
-Actual native compilation33.26s+2.56s metadata embedding, icon compilation, app/widget inspection and independent review pass. A further clean-path incremental build and metadata regeneration also succeed from iOS/Reps, with all caches preserved and all symlinks resolving.
-Reps99installed and direct postflight verified; synthetic encrypted-player/audio/transport probePASS, normal app interface restored. This does not replace physical Face ID/privacy/UI acceptance, which remains user feedback.
-No new schema, secret, permission, profile, certificate or public IPA introduced. User explicitly authorized GitHub rename/publication of this code; old Git history/tags remain intact.

-The first post-move build emitted stale-cache path warnings referring to the compatibility alias. It completed successfully; the following metadata-embedding build completed without those warnings. Caches were retained as required, with no cleanup to hide the diagnostics.

-The post-move host run exposed a duplicate Clang module cached under both alias paths. The entire prior host cache was preserved at .build/host-before-reps-directory-rename, and normal host outputs regenerated at Tests/Host/.build. No cache bytes were deleted; this is necessary relocation recovery rather than an unverified cache cleanup. Final result recorded below.
-Final normal host run from the moved root passes378tests/zero failures7.878s;13metadata/compatibility tests, lint and unsigned bundle inspection also pass from the moved root. No remaining compile/test failure.
-GitHub public verification confirms all23release/asset names, same repository ID, same tag names and same asset IDs/sizes/digests. Source fast-forward publication is the final authorized step; no new release binary.
