# Detailed video-import errors — 1.5.5 (114)

## User request and scope

The user reports that 112 still fails with the generic message, then explicitly asks to show the precise error inside the app. Implement that visibility without relaxing media validation or trying another remux change. A precise failing stage/code does not guarantee the ultimate root cause. The 112 attempt was not captured because the earlier live-log connection terminated; do not infer a new diagnostic from the repeated wording.

## Implementation

Create a memory-only diagnostics actor per import, captured with the existing lease when FileRepresentation is requested. Record the original importer failure before throwing through CoreTransferable; preserve the first report when the outer provider emits a generic wrapper. Isolate requests and retain the existing session/request/cancellation checks before publishing the report. Locking clears the displayed error as before.

Show the specific failing pipeline/validation stage and code. At duration guard 74 show source, prepared-copy and source-track durations, the difference, and the unchanged 100 ms threshold. Other errors include localized system messages, domain/code and up to four underlying causes. These details appear only in the existing covered import form; they are not added to logs, storage, notifications or generated screenshots. The message is selectable for explicit user copying. Saving the staged encrypted video also uses the detailed formatter. No media/crypto/schema/permission changes.

## Verification

First regression run failed because VaultVideoImportDiagnostics did not exist. Two new actor regressions cover original failure surviving provider wrapping and isolation/provider-only failure across imports. Full host suite: 411 tests, zero failures (7.914 s). Full strict Swift lint, 13 metadata/style tests, whitespace checks, actual xtool compilation (24.05 s), compiler metadata generation, embedding (1.98 s) and unsigned app/widget 1.5.5 (113) inspection pass. Final small wording/save-error adjustments are rebuilt by the normal build path before delivery.

USB preflight sees connected iPhone and installed 112 with unchanged identity/signer/entitlements; usbmuxd is active/success. Delivery and direct postflight pending. Original-file import remains unresolved; the user will provide the detailed message after delivery. No GitHub push/release.

113 was installed by the standard helper; a final adjustment extends detailed reporting to an early repository-open failure while saving. Final delivery therefore increments to 114 so the installed build will match the complete reviewed source. No media behavior changed between these builds.

Final 114 native build 10.09 s, compiler metadata generation/embedding 2.42 s and unsigned bundle inspection pass. Normal USB helper exits 0, installation/verification100%. Direct postflight confirms exactly one installed Reps 1.5.5 (114), same effective identity/signer/entitlements, and both preflight provisioning-cache SHA-256 values remain unchanged. Final metadata tests and whitespace checks pass. Evidence: `/tmp/reps-import-errors-{red,green}.log`, `/tmp/reps-video114-install.log`, `/tmp/reps-video114-postflight.json`. Physical detailed-message rendering and actual original-file outcome remain user checks. No push/release.
