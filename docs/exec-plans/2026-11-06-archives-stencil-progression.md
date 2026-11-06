# Archives, photo alignment and Feeling threshold

## Objective and authorization

Owner approved the three behaviors and requested implementation without further confirmation on 6 November 2026. Explicit exercise archiving with preserved results in Progress, green live stencil when contours align, post-capture translation/rotation/uniform-scale registration with preview and validation, and load increase only after every set reaches its maximum with Feeling strictly below 9, including bodyweight.

## Constraints and decisions

Keep the existing offline Swift/SQLite app and installed identity. Preserve unrelated ROADMAP edits. No body deformation, perspective warp, new dependency, clear private media file, automatic shutter or save. Reject uncertain alignment and preserve the original capture for review/retake. Never equate synthetic proof with a real camera test. Existing archive deletion remains explicitly destructive. New archived catalogue entries must survive restart and transfers, including those with no performances.

## Implementation plan

- [x] Archive domain: test persistence/history/active workout/transfer before changes, add explicit archive state using existing model conventions, route archived exercises to a dedicated Progress destination, preserve schedule/history invariants.
- [x] Progression domain: tests at Feeling 8/8.5/8.9/9 and incomplete maximums including bodyweight, then update the rule and relevant user copy.
- [x] Camera domain: shared bounded image registration and contour scoring, live low-resolution frames, stable green indicator, in-memory post-capture registration and crop, original/aligned review, cancellation/privacy guards. Add synthetic geometric tests and native image probes.
- [x] Run full host tests, strict lint, metadata and native iOS build; independent review and fixes.
- [x] Increment patch/build, package inspection and same-identity standard iPhone delivery where available; record exact outcome and remaining owner camera/UI checks.

## Progress

Implemented explicit archived catalogue storage (schema21, closed training JSON10;
legacy imports initialize the optional old archive as empty), preserving disabled
semantics and frozen workouts. Repetition-only load threshold is <9 with no
bodyweight bypass; the unrelated <8 add-repetition rule remains unchanged.

Bounded pure Swift contour matcher estimates similarity transforms, rejects blank/
unrelated images and requires central support as well as global bidirectional edges.
Independent review reproduced background-only false green; a new regression failed
then passed after the central guard. The camera uses throttled discarded frames,
three consecutive matches, stencil-only green tint and accessible text. Native
renderer and encrypted optional registration crop metadata support direct same-crop
reference comparison. No body warp, automatic shutter/save or clear media file.

Reviews also found cancellation at timer expiry could accept an old capture;
per-shot UUID and locally captured processing task now reject cancelled/superseded
callbacks. Fresh final independent reviews found no additional actionable issue.

Full host verification:444 XCTest +10 Swift Testing pass (11.426s +0.066s);
13 metadata checks and strict lint pass. Native build19.30s, final metadata embedding/
probe build10.93s, unsigned inspection pass. Standard USB helper exits0, build2.61s,
installation/verification100%. Direct inventory confirms1.5.7(128), unchanged effective
identity, signer, exact cached certificate and entitlements. Initial native probe
launch fails CoreDevice10002; nested cause is Locked. Owner unlocked phone and final
generated-image renderer/metadata probe detected a real vertical inversion in the
CoreGraphics grayscale adapter (exact128token). Removed the redundant UIKit CTM
flip; build129 compiled10.47s, metadata embedding2.43s, unsigned inspection/lint/
13metadata checks pass. Corrective30host tests pass. USB delivery stalled before
replacing128; read-only diagnostics find usbmuxd still active but its device list
empty, despite physical USB detection. No daemon restart. Own pending commands
stopped gracefully; owner reconnected/unlocked and129delivery resumed. No personal media, key or
training database read, no automatic camera capture, no GitHub push/release.

Evidence: /tmp/reps128-{host,lint,metadata,build,inspection,install}.log,
/tmp/reps128-{preflight,postflight}.json, /tmp/reps128-stencil-result.json.
Actual camera framing/mirror/lighting/retake/countdown and archive UI remain owner
acceptance, distinct from source/build/synthetic evidence.

## Final delivery and native RED to GREEN

Preserved only the existing helper's signed129IPA in /tmp; app/widget profiles pass
CMS verification, expire >24h and contain the exact existing certificate. Classic
xtool and installation_proxy attempts stall. The streaming alternative gives an
explicit iOS coordinator error: an existing process-scoped install owns the identity.
Closed only our clients. After the owner completed a full power-cycle, the same
verified IPA installed successfully via streaming without any new signing operation.
Direct postflight confirms one1.5.7(129), same identity/signer/entitlements and cached
certificate. No uninstall, daemon restart, data reset or profile/certificate mutation.

Exact native report build129/run timeline-stencil-129-final-20261106 is PASS:
top-left grayscale adapter, actual UIKit/CoreGraphics similarity renderer and common
crop improve generated-image pixel agreement, flat-image rejection, centered crop,
EXIF normalization, encrypted registration/nullable-pose metadata and per-photo steps.
This is the observed native GREEN after128failed the asymmetric orientation check.
Files:/tmp/reps129-final-stencil-result.json,/tmp/reps129-postflight.json,
/tmp/reps129-final-install.log. Normal launch is restored without probe arguments
before owner review. No push or public release requested.
