# Photo stencil and daily session — implementation plan

## Objective and authorization

Owner explicitly requests implementation without further confirmation after brainstorming. Build a private in-app camera with previous-photo overlay at50% adjustable opacity and a sequential photo session copied exclusively from the latest existing daily photo folder. No configurable pose checklist, no AI alignment, no public media/cloud, no schema/key/crypto change. Version1.5.6/build127.

## Context and decisions

A capture plan is a value frozen at launch. Session has one step per PHOTO in the latest folder (owner correction during implementation), including repeated poses, Other and unassigned legacy photos. No photos gives an explanatory empty state. Each step references its exact source photo, in the same stable order as the daily gallery. Unassigned remains unassigned on save; no pose is invented. Historical metadata contains no capture time. Single photo uses newest available photo of its pose across folders. Photos taken during the flow cannot change references. Photos save individually after explicit validation; Retake/Skip/Close preserve earlier saves. Default timer off with3/10seconds choices. New captures use today's date for session, existing selected date for single capture. Both camera devices supported, fixed1× wide lens and portrait camera orientation; aspect-fill viewport and saved image share the reference aspect ratio (default3:4 without reference), with in-memory centered crop after EXIF normalization and no stretching. Opacity toggle does not affect output bytes.

AVFoundation native photo output provides in-memory capture without app-created clear files. Session lifecycle runs on one serial queue, camera rendering on main; All start/retry/switch operations belong to the cancellable SwiftUI lifecycle task. UI cancels delayed captures and wipes unsaved bytes/reference on inactivity, stops camera on disappearance/lock. Face ID session checked on every async boundary, loading references and save. No new permission/entitlement/dependency. Match mirrored front-camera preview and saved photo.

## Steps and verification

1. [x] Add host behavioral tests first: latest day only, every photo including repeated/unassigned poses, no fallback to older folders, empty/single without reference, per-pose newest reference, frozen plan. Observe missing-API RED, implement value model, run host suite GREEN.
2. [x] Add native AVFoundation pipeline, preview, camera flow and routing; validate/retry/skip save one at a time through existing encrypted store. Strict lint, native compile and metadata checks.
3. [x] Independent security review focusing stale callbacks/countdown, lock/inactive wipe, queues, mirrored output/preview, no clear files or logs; fix material findings.
4. [x] Full host suite/metadata, actual iOS build/metadata/inspection, same certificate/identity preflight, standardUSB installation/postflight. Preserve original vault and do not read its contents. Physical owner review needed for live camera alignment/front-mirror/timer, session progression, permission denial and privacy. Synthetic probes must not photograph the owner automatically.

## Progress

Original import accepted by owner: “ok c bon”. Previous backup regression reports retained; no backup-format change in this feature. Implementation, independent review, verification and delivery complete; real camera/UI owner acceptance remains pending. No push or release requested.


## Verification obtained

Seven new host tests: one-step-per-photo semantics includes repeated types and unassigned photos, latest-folder-only selection, single pose reference selection, snapshot immutability; centered frame arithmetic and invalid geometry rejection. The corrected one-photo rule has observed runtime RED (two failing cases under deduplication), then GREEN. Frame API missing first gives RED then GREEN. Full426XCTest +10SwiftTesting (436) pass. Strict Swift format,13metadata tests and actual native app/widget build pass. Compiler metadata and final unsigned bundle inspection follow.

Independent review catches Retry's unstructured task potentially starting after close/inactivity; fix makes retry/device switch part of one cancellable view task with session/phase guards after awaits. Capture callbacks also require matching settings ID and model request token; stop invalidates them. Follow-up review of the owner-changed scope and image crop finds no concrete remaining issue. No clear photo file, Photos write, microphone, dependency, entitlement or private log added.

A hidden DEBUG native probe uses only generated two-color pixels, temporary in-memory encryption keys and no camera or real repository: it checks centered crop, EXIF orientation normalization, unchanged encrypted originals/nullable pose metadata and unique per-photo steps. It must be retrieved by exact run token/build before being reported PASS. Actual camera shutter/lens/mirror alignment, permissions and UI are separate owner acceptance; no automatic photograph of the owner is taken by an agent test.


## Native result and delivery

StandardUSB device-run.sh exits0 with installation/verification100%. First userspace developer launch loses its transport transiently; retry succeeds, without daemon/system changes. Direct matching build127+fresh-token report is PASS for centered crop, EXIF orientation normalization, actual encrypted original/nullable metadata round-trip, and unique per-photo steps including duplicate types. The native full backup regression also passes (KDF known vector, source snapshot capture, encrypted round-trip, different destination key, atomic restore/rekey, multiblock payloads, wrong password, tamper/reorder/truncation/append/revocation; synthetic export283ms).

Direct final postflight confirms1.5.6(127), unchanged signer, identical entitlements and byte-identical cached certificate. Normal developer launch without probe arguments exits0 afterward; no persistent probe request is queued. No personal image/database/key read or automatic camera capture. Source/build/native synthetic proof is complete; actual live camera/Files/Face ID/UI acceptance is not inferred. Evidence: /tmp/reps-stencil-{host,final-lint,final-build,metadata,embed,inspection,install}.log, /tmp/reps-import-memory127-{stencil,crypto}-result.json, /tmp/reps-stencil-postflight.json. No push or release.
