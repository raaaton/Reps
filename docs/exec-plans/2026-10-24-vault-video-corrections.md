# Vault video corrections — 1.3.1

## Objective
Fix system-modal/Face ID recovery, restore native transitions, group movement clips by day with confirmed contextual/swipe deletion, stabilize linked comparison and permanently remove audio tracks. Photos originals remain untouched. Existing encrypted clips must remain recoverable until a validated silent replacement commits atomically.

## Decisions
The user confirmed permanent audio removal and described drift, stuttering and one-sided comparison startup. No plaintext video output owned by Sport is permitted. Prototype segmented AVAssetWriter output encrypted directly, including reading an existing encrypted asset, before enabling conversion. Do not bypass iOS sensitive-content intervention. Keep private presenters mounted beneath an immediate opaque privacy cover; background still revokes the session.

## Steps
1. Correct privacy-surface identity and symmetrical active notification; preserve native sheet/navigation animation.
2. Add day grouping and contextual/swipe deletion with confirmation.
3. Stabilize player surfaces, cancel stale transport operations, prepare both players before scheduled common playback.
4. Prototype video-only passthrough to an encrypted sink. Validate zero audio and seeking on synthetic iPhone fixtures; integrate future imports and atomic existing-video replacements only if protections pass.
5. Independent security review, host/metadata/lint/build/bundle checks, normal identity/signature preflight, USB installation and postflight. Await physical feedback before GitHub publication.

## Verification
Regression coverage for day grouping, transactional replacement/deletion, interruption/revocation and transport state. Native synthetic probe must exercise actual comparison transport and audio removal. Physical review: system sensitive-video warning/recovery, folder and editor transitions, context menu/swipe deletion, aligned slow playback, backgrounds, large text/VoiceOver and existing photos.

## Progress
- Initial inspection: privacy wrapper destroys its content on inactive and disables animation for every descendant transaction. Comparison reassigns AVKit player every timer tick and schedules unprepared players, with stale seek completions unguarded.
- Implementation, independent review, local verification and USB delivery complete as recorded below. Physical acceptance remains pending; no GitHub publication.

### Prototype evidence
- 93 and diagnostic94 installed using normal helper, same identity/certificate/entitlements and valid app/widget CMS profiles. Reports are limited to a bundled synthetic sample and fixed cache report with unique run token; no private container/media enumeration.
- 94 isolated the first failure to passthrough reader input before append. The SDK AVAssetReaderOutput header documents marker-only buffers with zero samples, which are now skipped before video-frame validation. 95 tests that correction.
- 372 host tests pass; CAS source-metadata mismatch leaves the original published and candidate hidden, successful replacement removes the old chunks atomically. Day grouping preserves separate same-day videos and excludes other movements. Old encrypted metadata decodes with missing audio-removal flag.
- Independent prototype review found no security blocker, and identified independent playback incorrectly pausing the other player; corrected before95. Privacy cover also explicitly pauses players and a non-key/noninteractive UIKit window covers native full-screen AVKit and private navigation bars. Physical snapshot/intervention validation remains required.
- 94 diagnostic result: `provider remux, phase1, code0`. The bundled sample triggers documented zero-sample markers. 95 skips only buffers with zero samples; compressed video order, timeline and sample bytes stay unchanged. Prototype95 USB install and app/widget inspection complete; native report pending.
- 95 native report PASS: provider and encrypted-source video-only passthrough, zero audio, paired controller at0.5× retaining0.5s independent alignment, cryptographic tamper/reorder, seek and revocation.
- 96 native report PASS additionally includes real NSItemProvider→FileRepresentation under the captured lease capability and encrypted-candidate duration/size/transform/seek validation. Integration enabled only after95;96 verifies the publication validator too. No private media used by probes.
- Final independent review found a5000-video admission edge case. Replacement-specific transient admission now validates the source and permits at most one extra incomplete row; ordinary publication still cannot exceed5000 complete rows. New regression passes with5000 stored clips.373host tests pass (11.663s).
- Final97 adds an interruption nonce checked before scheduled paired start, covering inactive→active between view updates. Probe expanded to0.25×, common-end positions, independent concurrent playback and interrupted preparation; synthetic AAC fixture rotated90° for transform validation. Final delivery pending.


### Final delivery97
- Actual xtool compilation17.87s, compiler metadata regeneration, embedding3.65s, final app/widget inspection1.3.1(97), strict lint and9metadata/style checks pass without compilation warnings.373host tests/zero failures11.663s. Whitespace checks pass.
- Independent review final: no blocking finding.5000-clip admission and privacy nonce reviewed;18VaultVideoTests pass. Existing encryption/key/permissions/capabilities preserved.
- Normal device-run.sh exits0, installation and verification100%. Direct installed-app postflight confirms exactly one Sport1.3.1(97), same effective identity/signer/exact existing certificate and entitlements, valid CMS app/widget profiles.
- Final97native report PASS with unique token/build verification. Covers rotated AAC source through actual NSItemProvider authorization capture, encrypted-source video-only remux, zero audio, duration/transform/dimensions/seek validation, precise0.5× and0.25× aligned transport, common end, simultaneous independent playback, inactive→active preparation cancellation, tamper/reorder and lease revocation. No personal media or database read by the probe.
- Evidence:/tmp/sport-video-fixes97-{build,install,lint,metadata-tests}.log,/tmp/sport-video-fixes97-postflight.json,/tmp/sport-video-native-probe-result.txt. Production launch restored after the synthetic probe.
- Physical user acceptance still required for actual iOS sensitive-content intervention/Home gesture, visible motion/AVKit full-screen snapshot, large text/VoiceOver and existing photo regression. No GitHub push/release. A build/probe does not establish these physical paths.
