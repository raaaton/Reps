# Preserve edited video bounds — 1.5.6 (116)

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
