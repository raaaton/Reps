# Cropped video tail duration investigation

## Objective

Import the two additional Photos-trimmed videos without exposing frames outside their visible selections. Preserve compressed video, silent output, encrypted staging and existing validation. Keep diagnostic iterations on1.5.3 with independent build numbers; no new public release or push is part of this investigation yet.

## Evidence

After successful original-file acceptance and publication of1.5.3(120), the user reports two failures out of three new cropped videos. Both failV74/code0: source/source-track30.723333s versus prepared30.838333s (extra0.115s); source/source-track39.121667s versus prepared39.251667s (extra0.130s). The previous original clip still has its confirmed acceptance; this does not establish all edited input classes work.

The existing two native cropped fixtures retain decoding preroll but have no independently shortened edit tail: their raw sample end minus edit mediaStart equals visible duration. The container-only unit tail test checks bytes, not AVFoundation's fragmented duration interpretation. Hypothesis to test: raw samples after the visible edit end still contribute to fragmented asset duration despite mvhd/tkhd/elst lengths. Do not raise100ms tolerance or change production remux without native reproduction.

## Native reproduction

New synthetic fixture `VaultVideoTrimmedTailProbe.mp4` copies the existing bundled B-frame pattern byte-for-byte except movie/track/edit-list durations shortened to2.230013s. No real media is accessed. Raw compressed samples, codec descriptions and media duration remain unchanged. This introduces approximately132ms of hidden tail while preserving the previous338ms crop/preroll class.

Diagnostic121adds this fixture to the existing native encrypted stage/validate and exact-frame probe, with first/last compressed/output sample timing inspection for synthetic input only. Production preparation is unchanged from120. The DEBUG request harness also supports comparing a fixed patched synthetic container to this new bundled source, enabling isolated metadata experiments without repeatedly rebuilding or selecting private media. All existing crypto/provider/paired-playback tests still run after the cropped cases pass.

## Verification and progress

- Detailed original errors supplied by the user; pending native RED on the new synthetic fixture.
- Changed-file strict lint passes; native121build in progress.
- Keep existing source/key/lease/identity/provisioning and strict validation intact.
- After reproduction, inspect the synthetic prepared container and native timings, test one correction, then run regressions and request original-file confirmation only on an installed candidate.

## Native evidence and architectural correction

121's new tail case passes the production100ms guard but does not have the correct exact duration. A separate native comparison reads source2.230013s versus fragmented output2.261667s:31.654ms of hidden presentation tail. The stricter20ms comparator fails. Adding a standard mehd total-duration hint changes nothing. Evidence: `/tmp/reps-tail121-baseline.json`, `/tmp/reps-tail121-mehd-result.json`.

A synthetic-only ordinary MP4 remux, with original edit start restored and visible duration declared2.23s, passes native precise-duration and exact first/middle/near-end frame hashes plus the complete existing crypto/provider probe. First attempt without restoring the edit start correctly failed image comparison and was discarded. Native GREEN evidence: `/tmp/reps-tail121-flat-edit-result.json`. FFmpeg is used only on synthetic host fixtures for this experiment; no new app dependency or clear private output is introduced.

The fragment-streaming container itself is the architectural mismatch for completed cropped files.122continues streaming encrypted media but completes a normal movie index. New pure `VaultVideoMovie` retains only bounded sample/chunk metadata, marks provisional moov/moof boxes as same-size free boxes, then appends a final moov with actual stts/ctts/stsc/stsz/co64/stss tables and the visible edit. Media bytes and their positions are unchanged. Original decode time is rebased in edit metadata, signed composition offsets and sync flags are preserved, mvex is removed, and mdhd describes the complete decoding samples. No threshold change, recompression or dropping required reference images.

All final index bytes go through the existing encrypted chunk accumulator and aggregate500MiB/per-piece16MiB limits. Parser bounds cap100000samples and reject malformed, missing or discontinuous timing. Delegate cancellation now occurs after releasing the sink lock; the first concrete sink error is retained for in-app diagnostics. Failure removes encrypted staging before any database import. Independent review approves arithmetic, offsets, bounded memory, encryption/lease/cancellation/error paths; exact helper native proof remains pending.

Host regressions first fail on missing helper, then pass for direct media offsets and unchanged bytes, visible edit rebasing, signed reordered-frame offsets, sync indexes, malformed/truncated fragments and decode continuity. A second RED catches live moof tables conflicting with the final movie; same-size free headers resolve it. Exact Swift helper output is parsed by host ffprobe as156frames with2.230000s visible duration.419host tests pass9.853s, strict lint and13metadata checks pass.122adds HEVC/B-frame tail coverage and requires2ms duration agreement plus exact first/middle/last1ms images for all cropped fixtures. DEBUG test screen prevents automatic sleep while visible and restores normal idle behavior when dismissed. Native122build and delivery in progress; original new clips not yet accepted.

122delivery completed: native compilation14.65s, actual compiler metadata regenerated/embedded, unsigned portrait-only inspection pass. Normal USB helper exits0/install+verification100%; direct postflight verifies exactly one Reps1.5.3(122), same effective identity/signer/entitlements. Both provisioning-cache hashes remain unchanged. Fixed request `timeline-122-completed-movie-a` is installed; user is asked to reopen Reps. No122native report yet, so neither integrated native GREEN nor acceptance of the two new clips is claimed. Existing public v1.5.3 remains120; no new publication. Evidence: `/tmp/reps-tail122-{build,metadata,embed,inspection,install}.log`, `/tmp/reps-tail122-postflight.json`.

## Integrated native GREEN

User opens122and reportsPASS. Directly retrieved `/tmp/reps-tail122-native-result.json` verifies build122/run`timeline-122-completed-movie-a`PASS for the actual production encrypted stage/validate path. All four cropped fixtures pass2ms duration agreement and exact first/middle/last1ms decoded image hashes; the final HEVC case reports source2.2300130208333333s, prepared2.23s. Full provider authorization, silent imports from provider/encrypted asset, native authenticated chunks/tamper/reordering, dual-player comparison, precise seeking, slow playback and revocation checks also pass. The request marker is consumed. User is asked to close/reopen normally and import the two actual failing videos; original new-file acceptance remains pending. No public release update or push.

## Original-file acceptance

After closing the test screen and reopening normally, the user adds both previously failing videos and explicitly confirms: “c bon aucun erreur ca marche”. Both115ms/130ms original-file failures are therefore resolved in installed1.5.3(122), together with native four-fixture/exact-frame/encrypted-probe GREEN and419passing host tests. Original videos never leave the device. Final source/verification/documentation is saved in one local corrective commit. Public v1.5.3(120) is unchanged; no new push/release performed in this follow-up.
