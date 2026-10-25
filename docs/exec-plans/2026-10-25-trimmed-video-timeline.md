# Preserve edited video bounds — 1.5.7 (119)

## Reproduction and replacement correction — 1.5.7 (119)

The user reports exactly the same V74 error after116; session bounds alone did not fix the bug. The unavailable developer service is bypassed with a DEBUG-only fixed cache request/result harness: the user opens the synthetic screen once, then unique request tokens rerun only bundled synthetic fixtures. No private media/database is read. Normal app startup resumes after the request is consumed and the process is reopened.

Native117/118 RED: source3.211654s, prepared3.550000s, excess0.338346s.118 inspects compressed firstPTS0, outputPTS−0.338346, DTS0, source edit mediaStart0.338346/targetStart0. The fragmented writer initialization has no edit list. Thus the raw compressed timestamps are copied but the visible selection is lost. Evidence: `/tmp/reps-timeline118-red-result.json` and the bounded synthetic output117.

An isolated, synthetic-only standard MP4 edit-list experiment passes on iPhone118: precise candidate duration3.2116667s versus source3.2116536s, beginning/middle/end image hashes match, plus the full existing provider/encrypted playback/tamper/revocation probe passes. That initial image comparison uses default generator tolerances;119 tightens both tolerances to zero.

119 restores only initialization metadata before the encrypted sink: derives visible mediaStart from the first rawPTS minus outputPTS before writer startup, writes a version1 elst, and updates movie/track durations in their correct independent timescales. Compressed fragment bytes, codec descriptions, transforms, audio omission, encrypted chunking and strict100ms validation remain unchanged. The parser checks box bounds and supported versions; input and output initialization remain capped at16MiB. No plaintext private export or reencoding. A second synthetic B-frame cropped fixture exercises decoding order and negative decode timestamps; both fixtures compare exact frames after the normal encrypted stage/validate path. The extra fixture is generated exclusively from the existing test pattern.

Five host regressions cover visible offset/duration, tail-only trim, malformed containers/times, replacement of old edit lists, v1 headers and differing media/movie timescales. Complete416host tests pass9.309s;13metadata tests and full strict lint pass. Real119native build, regenerated compiler metadata, embedding and unsigned portrait-only inspection pass. Independent review finds no blocking defect; its early-size-limit recommendation is implemented, additional header/timescale tests added, native B-frame regression pending. First119installation is interrupted gracefully after usbmuxd ABRT/free-invalid-pointer; user restarts the service. Standard USB installation resumes. Native119GREEN and original-file acceptance remain pending; no publication.

119 final native result is GREEN: `/tmp/reps-timeline119-native-result.json`, unique run `timeline-119-native-a`, build119. Both cropped fixtures pass the production encrypted preparation/duration/orientation/dimensions/seek guards and exact-tolerance first/middle/end image hashes. The B-frame fixture reads firstPTS0.033333, outputPTS−0.338346, DTS0; visible source edit begins0.371680. The full provider transfer, silent remux from provider and encrypted source, authenticated chunk tamper/reorder rejection, paired transport, precision seeking, slow playback and revoked-session checks also pass. User independently reports the test screen passes. The request marker is consumed; user is asked to close/reopen normally and add their original video. Actual-file acceptance remains pending.

Normal USB helper exits0/install+verification100%; direct postflight verifies exactly one Reps1.5.7(119), unchanged effective identity/signer/entitlements. Both provisioning-cache hashes remain unchanged. Evidence: `/tmp/reps-timeline119-install-resume.log`, `/tmp/reps-timeline119-postflight-apps.json`, `/tmp/reps-timeline119-host-tests.log`. No push/release.

## Evidence and hypothesis

The user supplied the in-app 114 diagnostic: source and source-video-track duration 47.530000 s; prepared copy 47.868333 s; excess 0.338333 s; guard V74. Exact-duration loading alone did not resolve this. The tolerance remains 100 ms.

The remux currently starts its session at the first compressed sample's PTS and never explicitly ends the session. Apple's AVAssetWriter documentation says samples outside session bounds may remain for decoding but are not presented; without endSession the latest sample end sets the session end. A cropped file can contain negative-PTS preroll and trailing samples outside its visible edit. Hypothesis: the current session discards the edit bounds and exposes extra decoding samples.

The user explicitly confirms the failing video was shortened in Photos, matching this input class.

Primary references: registered SDK AVAssetWriter.h start/end session comments; https://developer.apple.com/documentation/avfoundation/avassetwriter/startsession(atsourcetime:) and https://developer.apple.com/documentation/avfoundation/avassetwriter/endsession(atsourcetime:) . Confirm with native RED before changing production remux.

## Synthetic regression

New fixture is copied from the existing synthetic test-pattern video, never private media:

```
ffmpeg -ss 0.338333333333 -i VaultVideoProbe.mp4 -t 3.2 -map 0:v:0 -c copy -avoid_negative_ts disabled VaultVideoTrimmedProbe.mp4
```

ffprobe confirms visible duration 3.211654 s and first compressed PTS -0.350000 s, with discard-marked preroll samples. Add a native stage/validate check to the existing synthetic probe. Build 115 contains only this test and fixture; production remux remains unchanged. Initial AVMutableComposition test construction hit Swift 6 non-Sendable isolation diagnostics; use a real cropped synthetic file instead, matching the actual provider input without changing production isolation.

115 passes changed-file strict lint, native compilation (13.84 s), compiler metadata generation/embedding (2.97 s) and unsigned app/widget inspection. Restoring the previously unavailable native test service via standard `mounter auto-mount --userspace` is in progress; the Cryptex developer image was obtained and Apple's TSS request succeeded, but mounting has not yet reported completion. No device media/database or certificate/provisioning changes made by the test.

The developer-image install and subsequent read-only cryptex query did not return; both were interrupted gracefully with SIGINT, without nonce changes, profile/certificate workarounds or a repeated install attempt. Native probe build 115 was installed by the normal helper (exit 0/install+verification100%). Attempting its CoreDevice launch next; no native RED result is claimed before reading its unique-token report.

## Intended fix and limits

If the synthetic failure confirms this, use the asset's visible zero-based start and exact CMTime end as writer session bounds, retaining all required decoding samples, audio omission, encryption, chunk/segment bounds and existing strict duration/orientation/dimensions/seek validation. Verify native GREEN plus the complete existing probe, then install a separately versioned final build and await original-file confirmation. Do not infer user acceptance from synthetic tests or relax the duration guard.

## Implementation and available verification

CoreDevice launch of 115 fails with `Failed to start service`; no native RED or GREEN is claimed. A host inspection of the real synthetic fixture's compressed packets independently reproduces the timing error: visible movie duration 3.211654 s versus the old sample-defined session 3.550000 s, an excess of 0.338346 s, matching the user's 0.338333 s within container-time rounding. This, the user's confirmed Photos trim, the actual old code and Apple's documented sample/session mapping support the narrow bounds correction despite the blocked native test service.

116 loads the exact CMTime source duration, starts the writer session at visible asset time zero and explicitly ends it at that exact source duration before marking input finished. All compressed samples still pass through in decode order, including required dependencies. Audio omission, encryption/lease checks, segment bounds and every validation guard (including the 100 ms duration guard) remain unchanged. No recompression or threshold change.

Full strict Swift lint, 13 metadata/style checks, whitespace checks, 411 host tests/zero failures (10.926 s), real native compilation (12.05 s), compiler metadata embedding (2.47 s) and unsigned app/widget inspection pass. The fixture packet inspection is a host timing reproduction, not an AVFoundation runtime pass. Preflight directly verifies installed 115 with the same identity/signer/entitlements as 114; provisioning-cache hashes remain unchanged. Standard USB 116 delivery in progress. Physical acceptance of the user's actual 47.53 s file remains pending. No push/release.

Final delivery: normal USB helper exits 0/install+verification100%. Direct postflight verifies exactly one Reps 1.5.6 (116), unchanged effective identity/signer/entitlements and unchanged provisioning-cache hashes. Evidence: `/tmp/reps-timeline116-install.log`, `/tmp/reps-timeline116-postflight.json`, `/tmp/reps-timeline116-host-tests.log`. The user has been asked to check actual import/save, duration and visible start/end; response pending. No claim of native probe success or actual-file acceptance yet.

## Acceptance

The user closes/reopens Reps119 normally, adds the same original Photos-trimmed video and explicitly confirms: “ca fonctionne !”. Original-file import acceptance is therefore confirmed for1.5.7(119), alongside the independent native synthetic GREEN. No original private video was copied to the host. Dedicated local commit only; no GitHub push/release requested.

## Final version consolidation and GitHub delivery

The user requests version1.5.3 for this single video-import correction, retaining the complete accepted implementation. Previous1.5.4–1.5.7 labels describe local diagnostic iterations, not separate public releases. App/widget/inspection now target1.5.3(120); the independent build number advances for delivery. Prepare verified unsigned Release IPA, install using the existing identity, publish the complete source to main without rewriting history and publish v1.5.3 with only the IPA asset. Publication and byte-for-byte downloaded-asset verification pending.

Release120verification: release-local.sh exits0;416host tests/zero failures8.727s,13metadata checks, strictlint, optimized native build91.43s, compiler metadata/embedding and unsigned portrait-only IPA inspection pass. Public artifact `dist/Reps-1.5.3.ipa`, SHA256 `5b8a075f2314da3647b89d14c542ed33b187997e53080a7cf1019bf2470eb0ad`. Standard xtool release USB delivery exits0/install+verification100%; direct postflight confirms exactly one1.5.3(120), same identity/signer/entitlements. App functionality is unchanged from the user-accepted119; only version/build metadata changes.

Publication complete: `main` and annotated `v1.5.3` initially resolve to source revision `6bd64abcded71a27523ae017893e338b1edd9ec3`. Public release https://github.com/raaaton/Reps/releases/tag/v1.5.3 contains exactly one asset, `Reps-1.5.3.ipa`. Downloaded GitHub bytes exactly match the local Release artifact and pass the full unsigned IPA inspection, version1.5.3/build120, portrait-only app/widget and no personal provisioning/data. Downloaded SHA256 matches `5b8a075f2314da3647b89d14c542ed33b187997e53080a7cf1019bf2470eb0ad`. This final delivery note is a documentation-only follow-up; the release tag remains on the verified build source. No force-push.
