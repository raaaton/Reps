# Complete backup import memory — 1.5.5 (126)

## Evidence and scope

The owner freed space after export returned snapshot.copy.vault_video_chunks / SQLite13/13 and confirms export works. No export snapshot redesign is needed. The remaining failure is a process termination after password entry during import. The filtered iPhone Jetsam report at 2026-11-02 21:59:06 +0100 reports Reps active/frontmost, per-process-limit, 196608 resident pages of16384 bytes (3GiB). No personal archive, database, media, password or vault key was read.

A DEBUG synthetic probe creates an encrypted portable archive with32MiB of fixed chunk payloads and invokes the actual PortableBackupEngine.read into temporary encrypted staging. Build125 on the physical iPhone reproduces excessive growth: peak42→146MiB, +103MiB, exceeding the unchanged96MiB growth ceiling. This is measured RED evidence, independently retrieved with matching build/run token and also reported by the owner.

## Correction

Drain Foundation autoreleased temporary objects around every logical import record, including authenticated frame reading, JSON shape validation/decoding, validation, encryption and SQLite append. Also drain each VaultBackupFile.readRecords callback, covering export and destination rekey. The helper is synchronous/rethrows and a no-op on platforms without Objective-C autorelease pools. Archive framing, KDF, cryptography, validation, cancellation, file protection, atomic publication and source data are unchanged.

The hidden DEBUG probe supports32 or500MiB of synthetic payload, with a free-space guard, one bounded block at a time, generated thumbnail and fresh non-Keychain keys. It never touches the real repositories.500MiB is the existing maximum per video; synthetic bytes test encrypted streaming, not AVFoundation playback. Fresh process launches and reported absolute peaks matter because getrusage ru_maxrss is a historical high-water mark, not instantaneous residency. A SKIP is never treated as PASS. Large fixture byte generation truncates the counter explicitly instead of trapping above255.

## Verification

429host tests, strict Swift lint and13metadata tests pass. Independent read-only security review finds no concrete issue in object lifetimes or preserved auth/validation/cancellation/publication; notes the historical-peak measurement limitation above. Native126 build, identity checks, physical results and installation are recorded below when obtained. The owner's original failing archive remains the final acceptance test. No push/release requested.

## Physical iPhone measurements

Standard USB installation/verification126 reaches100%, helper exits0. Direct device query confirms1.5.5(126), unchanged signer/entitlements; exact cached certificate matches preflight. First developer launch loses its transient userspace USB transport; retry succeeds without system configuration changes. Every synthetic report is retrieved from its fixed report path and checked against a fresh token and build126, using a fresh process launch each time.

- Before correction,125 /32MiB: peak42→146MiB, growth103MiB, FAIL.
- Corrected126 /32MiB: peak42→47MiB, growth5MiB, PASS.
- Corrected126 /500MiB: peak51→55MiB, growth3MiB, PASS.

Values are individually truncated to integer MiB; subtracting the displayed truncated peaks can differ from the displayed truncated growth. The absolute peak remains55MiB for500MiB of streamed payload instead of increasing with archive size. These are actual iPhone synthetic measurements, not Linux memory estimates or proof of original-file acceptance. Evidence: /tmp/reps-import-memory125-result.json, /tmp/reps-import-memory126-result.json, /tmp/reps-import-memory126-large-result.json. No personal archive was opened.

Native126 full synthetic backup regression also passes: KDF known vector, real vault-schema snapshot capture, complete encrypted round-trip with different destination key, multiblock video, atomic restore/rekey, random exports, wrong password, tamper/reorder, truncation, appended data and revocation. Measured synthetic export110ms. This uses only generated data and temporary repositories, not the personal vault. Report: /tmp/reps-import-memory126-crypto-result.json.

Final postflight rechecks1.5.5(126), signer, entitlements and exact cached certificate. The app is relaunched normally without probe arguments after tests (developer launch exits0). Final strict lint, whitespace check, native rebuild after whitespace-only formatting and bundle inspection pass. The original archive still requires owner retest.
