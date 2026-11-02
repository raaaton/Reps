# Optional Encrypted Vault Backup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Export training without a password, optionally include a nonempty Private Vault in a password-encrypted portable backup, and restore both without partial replacement.

**Architecture:** Keep TrainingArchive and legacy imports intact. Add a bounded authenticated streaming format and native crypto adapter. Stage vault data encrypted with the destination's biometric key, then publish vault and training in one SQLite attached-database transaction after validating rollback-journal prerequisites; prototype crash recovery before integration.

**Tech Stack:** Swift 6, SwiftUI, SQLite/CSQLite, CryptoKit, CommonCrypto, LocalAuthentication, native Files presentation; no third-party dependencies.

**Spec:** [Approved design](2026-11-02-portable-backup-design.md).

## Global Constraints

- No password for training-only exports, or when the vault has no published media or movement records.
- A custom movement without media counts as private content. An inaccessible vault is never treated as empty.
- No plaintext private files or exported biometric key; reencrypt vault contents under an independent archive key, then the destination biometric key on restore.
- Existing JSON/CSV imports preserve the vault. Complete backup import replaces both only after private preview and explicit confirmation.
- iOS 26 minimum; stable com.raaaton.sport identity, vault AAD and stored compatibility identifiers.
- Preserve all four tabs, existing training behavior and Apple-native presentation; English product copy.
- No private device database/media access for agent tests. No GitHub push/release requested.
- Independent security review and actual native/iPhone evidence required; host tests are not native crypto or Face ID proof.

## Review Focus

1. Vault containing movements only must still require encryption: task 1 tests this case.
2. Corrupted/inaccessible vault must fail without silently exporting training only: tasks 1 and 4 test this case.
3. A crash after changing one database must restore an all-old or all-new pair on reopening: task 3 uses file-backed crash probes.
4. Files/Face ID temporary inactivity must not erase a valid operation; background must revoke it: task 4 generation/lifecycle tests and physical recipe.
5. Existing but inaccessible biometric keys must never be replaced by an import: task 3 native key setup failure probe.

## Task 1: Bounded vault inventory and consistent capture

**Files:** Create Sources/RepsCore/VaultBackupModels.swift, Sources/RepsCore/VaultBackupRepository.swift, Tests/Host/Tests/RepsCoreTests/VaultBackupTests.swift; extend Sources/RepsCore/SQLiteDatabase.swift for scoped streaming row iteration.

**Interfaces:** `VaultBackupInventory` carries photo/movement/video counts; `isEmpty` ignores technical state and pending rows but includes movement records. `VaultRepository.backupInventory()` returns inventory without decrypting; `VaultRepository.captureBackup(lease:consume:)` synchronously emits validated encrypted record values via a throwing @Sendable callback inside a transaction. `VaultBackupRecord` identifies id, role, position and bounded encrypted payload; its role is a closed enum.

- [ ] Write tests using temporary SQLite databases for empty/new vault, initialized empty vault, movements-only, published photo/video/chunks, incomplete video admission and revoked lease. Assert movement-only nonempty, interrupted imports rejected, exact content and associations retained, no duplicate or missing chunks admitted.
- [ ] Run `swift test --package-path Tests/Host --filter VaultBackupTests`; observe the missing interfaces/failures before code.
- [ ] Implement the inventory/capture interfaces using known schema, SQL length checks and one-row/block iteration; throw on damaged state or pending work, never fallback to empty. Coordinate training snapshot capture with vault capture under database locks before releasing an immutable encrypted staging snapshot.
- [ ] Rerun the focused tests and existing VaultRepositoryTests/VaultVideoTests; verify all pass. Commit only this tested deliverable.

## Task 2: Portable authenticated streaming and native crypto

**Files:** Create Sources/RepsCore/PortableBackupFormat.swift, Tests/Host/Tests/RepsCoreTests/PortableBackupFormatTests.swift, Sources/Reps/Features/DataTransfer/PortableBackupCrypto.swift, PortableBackupStream.swift, PortableBackupProbe.swift. Add a CommonCrypto system-library module only if the native SDK import probe requires it.

**Interfaces:** `PortableBackupHeader` parses/encodes fixed magic/version/KDF/salt/wrapped-key parameters. `PortableBackupCrypto.deriveKey(password:salt:) throws -> SymmetricKey`; synchronous file-handle writer/reader functions accept a cancellation check, bounded records and a record consumer. `PortableBackupManifest` authenticates the training payload, record inventory, identities and exact archive completion.

- [ ] Write host framing tests for unknown versions/roles, oversized lengths/KDF parameters, arithmetic overflow, truncated headers/records and trailing data. Run focused tests and observe failures.
- [ ] Fix format limits before implementation: 1 MiB streaming blocks, <=10 MiB training JSON, <=1000 photos, <=5000 videos, <=500 MiB per video, photo/metadata bounds matching existing validators. Bound manifest size by inventory and enforce a checked total-byte budget rather than unbounded allocation.
- [ ] Prototype actual CommonCrypto/CryptoKit with constant synthetic data, PBKDF2-HMAC-SHA256 600000 rounds and 16-byte random salt, independent random 256-bit archive key, authenticated key wrapping and unique GCM nonces. Authenticate header, archive identity, record identity/role/index/length and final manifest. Require password >=12 characters and exact confirmation; do not trim or normalize secrets.
- [ ] Implement framing and streaming only after RED. Never serialize the source vault key; decrypt and reencrypt one bounded payload at a time. Use protected backup-excluded encrypted staging and file URLs, not a whole-archive Data/FileWrapper.
- [ ] Run host tests plus native synthetic known-vector, round-trip, different-ciphertext, wrong-password, tamper/reorder/truncation/append and revoked-operation checks. Measure native KDF latency; keep runtime proof separate from compilation. Commit after verified results.

## Task 3: Atomic restoration and protected recovery

**Files:** Create Sources/RepsCore/PortableBackupRestore.swift, Tests/Host/Tests/RepsCoreTests/PortableBackupRestoreTests.swift, Sources/Reps/Features/DataTransfer/PortableBackupDestination.swift; modify Sources/RepsCore/TrainingTransferRepository.swift, SQLiteDatabase.swift, Sources/Reps/Features/Vault/VaultKeychain.swift.

**Interfaces:** Extract existing training replacement body into an internal transaction-free helper while preserving the existing public transactional API. `RepsRepository.applyCompleteBackup(preview:vaultPath:stagedPath:lease:now:) throws` attaches only app-owned validated vault/staging paths and publishes training plus encrypted vault in one synchronous transaction. Store a recovery snapshot of replaced vault rows under the existing destination key in protected local storage within the same transaction.

- [ ] First write file-backed SQLite tests for training+vault replacement, old JSON/CSV preserving vault, stale preview, active activity, invalid associations, failed SQL after first database mutation, and recovery snapshot consistency. Run focused tests and observe RED.
- [ ] Prototype ATTACH atomicity with rollback journaling on both files, synchronous FULL and a file-backed main database. Verify actual journal_mode, secure_delete and transaction prerequisites; reject unsupported WAL/memory/off modes instead of claiming cross-file crash safety. Source: https://www.sqlite.org/lang_attach.html and https://www.sqlite.org/atomiccommit.html.
- [ ] Use a child-process synthetic crash probe during multi-file mutation and reopening. Assert neither main nor vault is independently published; SQLite performs hot/super-journal recovery before normal repository use. Do not delete/rename recovery journals.
- [ ] Implement bounded validated import staging, reencrypted under an authenticated existing destination key. For a genuinely new vault, prepare its biometric key before publication, use rollback-safe cleanup, and never delete an existing or still-needed recovery key. A failed existing-key load is fatal.
- [ ] Publish staged rows in foreign-key-safe order and training via the extracted helper; check cancellation/lease before entering commit. Once commit starts, complete/rollback synchronously, then suppress stale UI publication if covered.
- [ ] Run focused tests, all transfer/vault regressions and native key/lease failure probes. Confirm disk-full and SQL failure preserve both previous datasets. Commit tested restore machinery.

## Task 4: Native export/import UI and lifecycle

**Files:** Modify Sources/Reps/Features/DataTransfer/TrainingTransferView.swift, TrainingFileDocument.swift, Sources/Reps/Shared/TrainingStore.swift, Sources/Reps/Features/Vault/PhotoVaultStore.swift, Sources/Reps/App/RepsApp.swift; create PortableBackupStore.swift, PortableBackupPasswordView.swift, PortableBackupPreviewView.swift and PortableBackupFileTransfer.swift; declare the encrypted archive document type in app plist/config as needed.

**Interfaces:** MainActor `PortableBackupStore` owns phase, operation generation, cancellation, protected staged file URLs and memory-only secrets; supplies `beginExport(includeVault:)`, `beginImport(url:)`, `cancel()` and `background()`. `PhotoVaultStore` supplies explicit authenticated export/restore access without silently creating/replacing inaccessible keys or exposing a gallery outside the vault screen.

- [ ] Add behavior tests for the transfer decision/state model: toggle off, toggle on+empty, movement-only, auth cancellation/error, password mismatch, generation expiry, cancel and background. Verify only nonempty private exports reach password/encryption state. Observe RED before state implementation.
- [ ] Add native Include Private Vault toggle, initially off and retained only while screen exists; preserve two transfer actions. Training-only path still writes current JSON, with accurate exclusion copy. Nonempty complete path obtains Face ID and SecureField password/confirmation, then exports one encrypted document by file URL.
- [ ] Detect encrypted archive by validated magic, retain bounded legacy CSV/JSON parsing, request password only for encrypted format, authenticate complete file before preview, then confirm replacement of both domains. Legacy previews remain vault-preserving.
- [ ] Cover passwords/private previews during inactivity; clear and cancel on background/disappearance, distinguish expected Files/Face ID inactivity, and remove abandoned encrypted staging on startup. Avoid logging private metadata, URL paths, key material or password-derived data.
- [ ] Refresh stores, photo activity, reminders and Live Activities after committed restore. Test invalidated callbacks and repeat taps with actual generation logic; complete actual Files/Face ID device recipe after deployment.
- [ ] Run lint, relevant tests and native compilation before committing UI integration.

## Task 5: Review, documentation, version and iPhone delivery

**Files:** Update README.md, docs/SECURITY.md, docs/DESIGN.md, docs/TESTING.md, docs/BUILD.md, this ExecPlan, app/widget versions and scripts/verify-foundation.py.

- [ ] Obtain independent security review with scoped requirements and diff, including format authentication, memory bounds, no plaintext staging, key lifecycle, SQLite atomicity prerequisites, recovery storage, cancellation and stale previews. Fix material findings and rerun their regressions.
- [ ] Advance patch to 1.5.4 and build to 123 if no intervening local delivery; verify actual current version first. Keep app/widget/inspector consistent and retain installed identity/capabilities.
- [ ] Run `swift test --package-path Tests/Host`, `python3 -m unittest discover -s Tests/Metadata -v`, strict Swift format lint, `xtool dev build`, `python3 scripts/build-live-metadata.py`, final `xtool dev build`, `python3 scripts/verify-foundation.py` and `git diff --check`. Record exact outcomes and runtime limits.
- [ ] Document what is shipped, password loss consequences, complete versus training-only behavior, bounded format/KDF and measured crypto proof. Remove obsolete blanket claims that every export excludes private media without rewriting historical evidence.
- [ ] Inspect existing signer/identity/capabilities then use `~/omarchy-apple-dev/device-run.sh` if signing/transport conditions permit. Stop on unexpected signing failure without replacing certificates. Verify installed version; commit verified feature changes, no push.
- [ ] Report pending physical recipe: toggle/password, export and restore from Files, legacy import preserves vault, wrong password/corruption/cancel, photos/videos/movements/associations, relaunch/background/Face ID, larger media, Dynamic Type and VoiceOver. User's device confirmation is required for actual UI/private-media acceptance.

## Progress

- [x] Design approved by user with “implémente”; export password/inclusion requirements fixed.
- [x] Read current repositories, transfer UI, keychain/leases, archived prototype limits, build instructions and SQLite atomic-commit primary documentation.
- [x] Plan self-review: each design section mapped to tasks, interfaces and review-focus cases specified.
- [x] User explicitly instructed direct implementation again; execute inline without further approval prompts.
- [ ] Implementation and all validation/delivery steps above.


## Execution ledger — 2 November 2026

- Baseline: clean existing feature branch except this plan; 419 XCTest cases pass. Work stays on the existing feature branch with its native caches, following the user's repeated direct implementation instruction.
- Ruling: use SQLite attached-database rollback/super-journals with verified DELETE/file-backed modes, EXTRA synchronous/fullfsync instead of a separate bespoke restore journal. This follows SQLite's documented atomic commit; wrong prerequisites fail closed. Source: https://www.sqlite.org/lang_attach.html .
- Task 1 complete: inventory/snapshot/staging tests observed RED for absent APIs then GREEN; snapshots contain only source ciphertext. Record iteration bounds memory per photo or video chunk, not the whole archive.
- Task 2 implemented: native proof compiled RED before the engine interfaces, then the real CryptoKit/CommonCrypto actor/stream compiled GREEN. Actual native runtime result remains pending.
- Task 3 implemented: SQL failure after training replacement rolls back both databases; encrypted recovery and stale stamp checked. Child process termination with dirty pages reopens both old datasets. Pending-key preparation missing-method RED then GREEN across database reopen; native Keychain half-publication recovery remains a physical/API validation limit.
- Ruling: authenticate complete import into staging under an ephemeral memory-only key before target authentication/initialization. Only confirmed restoration obtains destination Face ID and rekeys staging, so incorrect passwords cannot initialize a live vault.
- Task 4 implemented: native switch/password/preview/Files flow, renamed-file magic sniff, generation/background cancellation, private cover, abandoned workspace cleanup and retriable staging. Empty initialized vault verifies key access before no-password JSON fallback. Current/incoming counts shown before destructive confirmation.
- Independent security review identified busy fallback, cleanup and key crash-window findings; fixed. Focused key/import review reports no remaining material issue. No claim of Keychain/Face ID runtime acceptance from host tests.
- Local candidate 1.5.4 (123); signer preflight matches installed 122 and existing certificate is valid beyond 24h. Connected iPhone detected. Full suite/lint/build/metadata/bundle/device results recorded below as they complete.


### Final available verification and delivery block

- 419 existing XCTest +8 Swift Testing backup tests pass (427 total); final outputs `/tmp/reps-backup-host-verified.log`. Strict lint passes (`/tmp/reps-backup-lint-final.log`);13metadata tests pass. Final native build123, real App Intent metadata generation/embedding and unsigned inspection pass (`/tmp/reps-backup-{build123,live-metadata,embed123,inspection123}.log`). Independent review found no remaining material issue after scoped fixes.
- Standard USB installation attempted only after preflight matching signer and valid existing certificate. It fails during profile provisioning with Apple409 ENTITY_ERROR, “There are no current IOS devices on this team matching the provided device IDs.” No certificate/profile replacement or revocation; no provisioning retry. Read-only device inventory is empty. App metadata postflight verifies installed1.5.3(122), same signer and entitlements; no new123app was installed.
- The fixed synthetic probe request was written for the attempted123delivery and then removed after failure. No personal media/training database was accessed. Native proof did not run; no report is claimed. Its compiled tests include known KDF vector, multiblock exact bytes, rekey/two-database publication, distinct exports, wrong password, tamper/reorder/truncation/append and revocation.
- Remaining: resolve Apple registration/provisioning before another delivery; run native proof, measure KDF/export timing and validate prepared-Keychain recovery/inaccessibility, then user Files/Face ID/private-media/large-text/VoiceOver recipe. Do not mark device/native validation complete based on compilation. No push, tag or release.


### Delivery retry — 2 November 2026

User requests reinstall. The renewed standard USB attempt passes Apple registration/provisioning/signing, then encounters a transient `noDevice`. Read-only checks still find the same iPhone on122; a second standard attempt succeeds with installation/verification100%. Direct postflight verifies Reps1.5.4(123), same signer, byte-identical certificate and unchanged entitlement dictionary (`/tmp/reps-backup-postflight123.json`); helper exits0 (`/tmp/reps-backup-reinstall123-usb.log`). No certificate was replaced/revoked.

Remote developer launch is unavailable because no Tunneld is running; no daemon/system configuration was changed. The fixed `timeline-123-backup-` synthetic request is prepared in Caches, awaiting the owner opening Reps. Only synthetic report/readback will be used. Native crypto proof, measured timing, prepared-Keychain behavior and real Files/Face ID/media acceptance remain pending; successful installation does not establish them.
