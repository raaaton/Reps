# Precise video-import duration — 1.5.4 (112)

## Objective and evidence

Preserve the resolved error-alert crash and diagnose the original 48-second/~200 MiB import failure. The user confirms no crash on 109, but generic import failure remains. Builds 110 and 111 add error-only stage/domain/code instrumentation without paths, names, content, error descriptions or media metadata.

Live original-video reproduction on 110 identifies transfer phase 7 (post-remux validation). On 111 the exact failed guard is 74, code 0: output asset duration differs from the staged source duration by at least 0.1 s and also differs from the source video-track duration by that tolerance. This is not the remux size guard or a failed decode/readiness/seek check. CoreTransferable wraps the original error, explaining why the earlier outer diagnostic never matched. Evidence: `/tmp/reps-video-import110-diagnostic.log`. Private media and databases were not read.

## Hypothesis and minimal change

AVURLAsset without AVURLAssetPreferPreciseDurationAndTimingKey may supply an estimated duration. Comparing these estimates to a 100 ms tolerance can reject a valid fragmented MP4. Request precise duration/timing for both the provider source and the encrypted playback asset. Preserve the actual 100 ms guard, no-audio/transform/dimensions/readiness/seek checks, encryption, revocable leases and bounded byte-range loading. Apple reference: https://developer.apple.com/documentation/avfoundation/avasset/duration?language=objc . The original file must pass on-device before treating this hypothesis as confirmed.

## Verification and progress

111 keeps the failing guards intact and establishes physical RED at check 74. 112 passes strict changed-file Swift lint, 13 metadata/style tests, native compilation (8.59 s), compiler-derived metadata generation, embedding (2.14 s), unsigned app/widget inspection and diff checks. USB installation in progress. Run the existing synthetic native transfer/remux/playback/seek/revocation probe on 112, then return to normal launch and request original-video validation. Do not equate synthetic PASS with the user's file passing. No GitHub push/release.

112 standard USB helper exits 0/install+verification100%. Direct postflight verifies 1.5.4 (112), same effective identity/signer/entitlements, and preflight provisioning-cache SHA-256 values remain identical. Attempting the existing synthetic probe via CoreDevice failed before launch with `Failed to start service`; read-only `mounter list --userspace` reports no mounted developer image. No SDK/image download, installation or device-setting change performed. Thus there is no new native synthetic PASS. Normal app remains available; original-video retry requested with live diagnostic capture active.

User feedback: 112 still rejects the original file with the generic message, so precise timing alone is insufficient and this hypothesis is not confirmed. The live-log connection had terminated before that attempt; its specific guard was not recaptured. The user now requests precise in-app errors. Continue with [visible original diagnostics](2026-10-25-visible-video-errors.md), without relaxing validation or guessing another media fix.
