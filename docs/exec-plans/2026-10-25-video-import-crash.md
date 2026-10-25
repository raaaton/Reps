# Video import error presentation — 1.5.3 (109)

## Objective and evidence

The user reports a reproducible crash immediately after selecting one 48-second, roughly 200 MiB video. Read-only USB retrieval found three Reps crash reports on 25 October at 11:03:20, 11:03:49 and 11:04:31 (device timestamps). All terminate with SIGABRT from UIKit's `+[UIAlertController _alertControllerContainedInViewController:]` assertion during an alert transition, rather than a jetsam memory termination. Reports are in `/tmp/reps-video-crashes/`; private videos and databases were not accessed.

The root vault alert observes the same error as video sheets, but only excludes its own photo sheets. A movement import can therefore activate two alert presenters simultaneously. This concrete presentation conflict is addressed first. The reports do not identify the underlying failure of this particular video.

## Changes

- Restrict the root photo error presenter to Physique; give Movements an error presenter only while its own detail/editor sheets are closed.
- Render video-import failures inline in the existing form, avoiding an alert racing the Photos picker dismissal. Preserve retry, explicit Save, original media and encryption.
- Log only numeric remux phase/error code on a preparation failure; never paths, media, names or private metadata. The actual file may need a subsequent retry to establish its rejection reason.
- App, widget and package inspector advance together to 1.5.3 (109). No push/release authorized.

## Verification and progress

The three physical crash reports establish the failing UI path. Linux tests cannot execute UIKit alert transitions; no source-text test pretending to reproduce UIKit was added. Run strict Swift lint, existing metadata and host tests, real xtool build, compiler metadata generation/rebuild and bundle inspection. Check existing installed identity and entitlements before the normal USB helper, then verify the installed build. User must retry the original video to confirm the physical path and report any remaining inline error.

Local checks passed: 409 host tests (11.248 s), 13 metadata/style tests, full strict Swift lint, whitespace checks, xtool builds (14.41 s and 17.46 s), compiler metadata generation and unsigned app/widget inspection for 1.5.3 (109). Numeric error instrumentation was included in the second compilation. No synthetic Linux test establishes UIKit behavior.

USB delivery blocked before replacement: the standard helper completed its build (2.29 s), then Apple provisioning returned `409 ENTITY_ERROR`: `There are no current IOS devices on this team matching the provided device IDs.` Per AGENTS.md, stop without certificate/profile replacement, revocation or repeated install attempts. Preflight verified exactly one existing Reps 1.5.2 (108); read-only verification after the attempt confirms it is still installed with unchanged identity/signer/entitlements. Existing provisioning-cache files remain byte-identical by SHA-256. Build 109 is not delivered or physically validated. No push/release.

### Delivery resumed after user reconnect — 25 October

USB discovery and pairing succeed. Read-only Apple device listing returned no entries; the standard helper was resumed once following the user's reconnect message, without an isolated registration command or certificate/profile workaround. This time provisioning, signing, installation and verification all reached 100%; helper exits 0. The cause of the transient Apple state remains unestablished. Direct postflight verifies exactly one installed Reps 1.5.3 (109), the same effective bundle identity, signer and entitlements. Both existing provisioning-cache files retain their pre-install SHA-256. Evidence: `/tmp/reps-video-install-resume.log`, `/tmp/reps-video-postflight.json`. Physical retry of the original video and its underlying import failure remain pending user feedback. No push/release.
