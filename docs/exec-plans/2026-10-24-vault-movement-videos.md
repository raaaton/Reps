# Private Vault movement videos — 1.3.0

## Objective and approved design

Implement the user-approved 24 October plan: Private Vault with Physique and Movements; automatic current Following Skills plus vault-only custom movements; dated Photos-only video imports; individual and side-by-side aligned playback at 1/0.5/0.25x. Preserve photos, training and all four tabs. Completed/archived/deleted Skills retain saved videos. No recording, posture analysis, video export, public video activity or GitHub publication.

## Implementation sequence

1. Prototype bounded encrypted byte-range playback and seeking with AVAssetResourceLoader using synthetic media, before enabling real imports. Same biometric key and revocable leases; no clear video file created by Sport for real media.
2. Add vault schema 2→3, encrypted movement/video metadata and thumbnails, 1 MiB AES-GCM chunks, staged atomic publication and abandoned-import cleanup. Authenticate chunk identity/index and validate the complete manifest. Preserve the original photo format and key.
3. Add Following/custom/saved movement projections and vault-only CRUD. PhotosPicker imports MOV/MP4, playable AVFoundation assets, <=300 seconds and <=500 MiB, unmodified original bytes. Date from media if available, otherwise today; editable.
4. Native individual player and paired comparison with independent seek, shared rate/play/pause, preserved alignment, pause both at first end, muted comparison. No PiP/external playback. Immediate stop/invalidation/clear at lock, cover at inactive.
5. Independent security review; host tests, strict lint, metadata, xtool build, compiler-derived metadata embedding and bundle inspection. Version 1.3.0, build after current90. Same identity/certificate preflight, normal USB installation and verified postflight. Physical acceptance remains the user's responsibility; do not inspect private media.

## Interfaces and constraints

New SportCore value models for movement/video metadata, manifests, byte ranges and comparison state; repository methods stage/append/finish/cancel/read/update/delete. Native video pipeline owns AVFoundation and CryptoKit; private vault session owns player revocation. SQLite is the only persisted media source. Movement names, Skill links, video dates and previews remain encrypted. The existing photo-only public day index stays photo-only. Delete All Photos stays photo-only; Reset Vault includes all videos/movements/chunks and the original key.

## Verification

Real SQLite migration/reopen/rollback; staging failure/cancellation/recovery; missing/oversized chunks; range bounds; Following→Saved retention and custom independence; comparison alignment/end; revoked session. Native synthetic CryptoKit tamper/reorder and AVPlayer seek/playback validation on iPhone. Real media are only used by the user after delivery. Full tests: swift test --package-path Tests/Host; metadata tests; swift format lint --strict; xtool dev build; build-live-metadata.py; rebuild; verify-foundation.py.

## Progress and decisions

- Baseline: clean main at0af8352;355host tests pass. New branch codex/vault-movement-videos.
- Ruling: use the existing checkout and caches on a feature branch, rather than create another worktree; all installation/build tooling already targets this workspace. No pre-existing changes.
- Approved in-chat plan is the binding specification. Track progress here rather than introducing a second skill-specific plan format or modifying ignored agent configuration.
- Not started: native prototype, schema/models/tests, UI, independent review, final verification and delivery.

### Progress update

- Migration test observed RED (schema2/table absent), then GREEN. Domain stubs observed8failures before implementation;6video domain/repository tests now pass, including cleanup after revocation. Full first run360tests found one old fixture expecting vault schema2; expectation updated to3 while preserving byte-for-byte photo assertions.
- Native loader/probe compiles against registered SDK; generated four-second 320×240 H.264 test pattern is1,388,803bytes, crosses the1MiB boundary and has normal MOV/MP4 seeking requirements. Probe has a DEBUG-only launch argument and fixed synthetic report file, no private key/Photos access. Independent targeted reviewer found no concrete security blocker; runtime not yet claimed.
- Encrypted-only staging avoids the Photos provider URL escaping its FileRepresentation closure. A fresh ephemeral key protects that staging, then each block is authenticated and reencrypted under the existing biometric vault key. Cancellation cleanup is restricted by the original import session UUID and cannot touch published videos.
- Following built-in Skill IDs are strings (e.g.handstand), not UUIDs. Ruling: retain those IDs only inside encrypted movement metadata; each persisted vault movement gets a random UUID. This avoids leaking built-in Skill names through SQLite relationships.
- UI/store integrated with real video import disabled pending native synthetic result. Current prototype version1.3.0(91); final delivery increments build again if91is installed. No GitHub push.

### Verification checkpoint

- Full368host tests pass (10.155s),9metadata/style checks pass, strict lint clean after formatting, real prototype build11.27s and compiler-metadata/bundle inspection pass. Import remains disabled until native probe result.
- Automatic review initially rejected device-run citing first-install HelloSport approval. Read-only evidence confirmed docs/exec-plans/2026-10-11-native-foundation.md:44-45 records that approval and completed installation; docs/SECURITY.md confirms it, and current preflight directly verifies existing1.2.8(90). Resubmission with this evidence was approved. Standard USB installation91in progress, no permission-mode change or workaround.

### Independent final review

Reviewer inspected the full implementation and ran13video tests successfully. Two concrete findings: reset wording still announced only photos despite video/movement cascades(P1); movement name in navigation title remained visible under inactive coverage(P2). Fixed by explicit full reset scope and generic title whenever covered/not authorized. Privacy purpose/Settings copy now include videos. No other concrete issue found in transfer/AAD/bounds/leases/migration/transactions. Native/UI behavior still requires the probe and physical recipe. Wording/SwiftUI coverage fixes are checked by source review/build and physical recipe, not artificial host tests that mirror view text.

### Native proof and final preparation

- USB daemon aborted with free():invalid pointer during first attempt. coredump metadata confirms SIGABRT;6.9GiB memory available rules out simple memory exhaustion. Client interrupted gracefully. sudo restart required the user's password; user explicitly restarted the service. Fresh preflight then normal helper retry succeeded:91installed/verified100%, direct postflight same identity/exact certificate/capabilities, both CMS profiles valid.
- DEBUG probe launched via developer tools with fresh UUID run token. Read only its fixed synthetic result file, never vault/training databases or private media. Native result: PASS AES-GCM, altered/reordered blocks rejected, two encrypted players, precise seek,0.5xplayback and revoked session. This proves the native API path, not personal Photos import/Face ID/UI acceptance.
- Final build92activates imports after that native proof. Source/widget/inspector agree1.3.0(92). No third-party dependency, microphone permission, broad Photos permission or capability added. Native menu symbols use the existing original UIKit accent rendering pattern.
- Additional real compatibility finding: linked Skills allow4096UTF8-byte names and256-byte IDs; the initial100-character/200-byte vault limit could make a saved linked movement fail to decode later. Observed3RED assertions, fixed linked validation to existing TrainingText limits and widened only movement metadata ciphertext bounds to32768bytes; custom names remain100characters and invalid NULs are refused. Validate before saving automatic linked metadata. Canonical yyyy-MM-dd validation also observed RED→GREEN.
- Movement sync attempts each snapshot once; clearing busy after a failed write no longer loops automatic retries. Reopening Movements or a changed snapshot permits another attempt.

## Final verification and delivery

- [x] Core models/schema, migration/reopen/rollback/limits/ownership/compatibility;370host tests pass8.68s.
- [x] Native encrypted byte-range prototype and actual synthetic iPhone runtime proof on91.
- [x] Following/custom/saved vault-only movements; Photos import/date/edit/delete; individual and aligned comparison controls; lock/cover/revocation integration.
- [x] Independent review; reset-scope and inactive-title fixes applied. Additional name/date regressions observed RED→GREEN. No deferred concrete finding.
- [x] Strict lint,9metadata checks, real xtool9.80s final build without warnings, regenerated/embedded metadata and unsigned app/widget92inspection.
- [x] Normal USB final helper exits0/install+verification100%; direct postflight one1.3.0(92), identical effective identity/signer/exact existing certificate/entitlements and valid CMS app/widget profiles.
- [x] Product/design/security/testing/build/roadmap/README documentation updated. Dedicated local commit follows; preserve feature branch, no push/merge/publication before explicit iPhone feedback/authorization.
- [ ] User physical acceptance: real Photos picker/import/cancel/date; native controls/portrait/landscape/large type/VoiceOver; paired seek and shared/independent speeds; background/cover/title/Face ID; existing photos. Installation and synthetic native checks do not establish these.
