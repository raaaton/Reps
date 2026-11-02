# Private Vault export storage failure — diagnostic 1.5.5 (124)

## Objective and evidence

The owner reports “Unable to access local data” after entering the export password in installed123. This is TrainingError.storage; the old message loses both the operation and SQLite status. No personal database, media, password or vault key is read by the agent. The precise cause of the real failure remains unknown; do not describe this candidate as fixing export.

## Diagnostic implementation

Capture records fixed stages for snapshot creation, each attachment, transaction begin, authorization, inventory, each known table copy, training read and commit. The SQLite wrapper preserves numeric primary/extended status at prepare/bind/step failure while keeping its existing thrown TrainingError contract. Capture wraps storage failure into a backup-specific localized error. The transfer UI also labels storage errors from authentication/workspace/encryption boundaries when no lower-level numeric code is available.

Only fixed labels and numeric statuses appear in the covered UI. No SQLite error text, SQL statement/arguments, filesystem path, media ID, key/password or personal value is displayed, persisted or logged. SQLITE_FULL13 gives storage guidance; other causes retain no-delete/retry guidance. Ciphering, source key/AAD, vault schema, capture SQL, snapshot transaction and restore behavior are unchanged.

The previous native PASS tested an independently constructed encrypted snapshot, not the source capture. Extend the hidden synthetic test to create the real VaultRepository schema with movement/photo/multiblock video, then run the actual captureCompleteBackup before encryption and full round-trip. Its result remains synthetic, never an inspection of the real vault.

## Tests and review

- Missing source chunk table: type absent RED, then diagnostic reports snapshot.copy.vault_video_chunks and SQLite1/1, with no private sentinel/path/key or SQL text. Original source state retained.
- Independent focused security review identified cleanup overwriting the original code after SQLite auto-rollback. Reproduce with UNIQUE ON CONFLICT ROLLBACK: RED1 instead of constraint19/2067. Latch first failure until capture resets it; GREEN19/2067 survives failed cleanup.
- Full419XCTest +10Swift Testing cases (429 total), strict Swift lint and13metadata tests pass. Build124/native metadata/inspection and installation tracked below. Host coverage does not prove original-file export or iPhone behavior.

## Device recipe and remaining work

Deliver124 with the existing identity/certificate/capabilities. Retry the owner's original export path normally and report the exact displayed stage/codes (or a successful saved file). Do not ask for the password, private media or an export upload. Root-cause correction depends on that evidence or an actual matching synthetic native failure. No push or public release.


## Available verification and device delivery

429host tests, strict lint and13metadata checks pass. Actual iOS124build, App Intent metadata regeneration/embedding and unsigned bundle inspection pass. Existing signer/certificate/entitlements verified before standard USB helper; helper exits0 with installation/verification100%. Direct postflight confirms1.5.5(124) with the same signer, entitlements and byte-identical certificate (`/tmp/reps-backup-diagnostic124-postflight.json`). No synthetic request marker is queued: the owner should reopen the normal app and retry the original export to obtain the precise in-app failure. The strengthened native capture probe compiles but has not run; original export success and exact cause remain pending. No private device database/media read, no push/release.


## Owner diagnosis and next correction

The owner reports snapshot.copy.vault_video_chunks, SQLite13/13 (disk full), then confirms export succeeds after freeing storage. That original export issue is resolved without a snapshot redesign. The subsequent import process termination is separately investigated and corrected in exec-plans/2026-11-02-backup-import-memory.md.
