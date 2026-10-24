# Added Weight description cleanup — 1.5.0 (104)

## User request
Restore approved 1.5.0 behavior, including the Maximum Objects modal. Remove small explanatory descriptions in Added Weight and its item/maximum forms (backpack note, limit note, available-load algorithm note and editor footers). Preserve labels, values, empty states, confirmations and actionable errors. User explicitly keeps visible version 1.5.0; delivery build advances to 104.

## Implementation and preservation
Restore the prior modal/source and discard the rejected inline control. Save a recoverable patch outside the repository before restoring tracked files. No domain/schema/backup/history/active/portrait changes. Keep object priority before500g and configurable maximum intact. Do not publish.

## Verification
Swift lint, metadata checks, actual xtool build/compiler metadata/unsigned portrait-only inspection and targeted independent review. Domain is byte-identical to approved baseline; no new or repeated domain tests required. Cancel the pending rejected delivery gracefully, verify actual installed identity/version, then normal USB delivery/postflight under the same certificate/capabilities. Physical UI confirmation remains the user’s check.

## Results
- Discarded the rejected uncommitted inline control and restored modal from approved bb590a3. Recovery patch retained outside repo. Current source diff is exactly five removed explanatory footers; domain and TrainingStore are byte-identical to baseline. No rejected-release commit or plan remains in the project.
- Gracefully interrupted pending deployment with SIGINT; direct installed inventory verifies phone remained 1.5.0 (102), profile validated. Fresh certificate/CMS profile preflight passes unchanged identity/capabilities.
- Strict Swift lint, 13 metadata/style/branding checks and whitespace checks pass. Actual xtool12.73s, real metadata extraction/embedding3.77s and unsigned app/widget inspection verify1.5.0(104)and portrait-only with no compiler warning/error.
- Independent targeted review approves restoration/description-only scope; labels, modal, values, errors and confirmations retained. No new or repeated domain tests needed for unchanged core code.
- Normal USB104delivery in progress. Evidence:/tmp/reps-clean150-{build,metadata,install}.log and /tmp/reps-clean150-{preflight,postflight}.json. No push/release; physical review pending.

Delivery blocked before replacement: usbmuxd crashed at 21:49:32 with SIGABRT / free(): invalid pointer; systemd reports failed(core-dump). Build104helper completed its incremental build (2.58 s) and waited without successful installation. sudo -n systemctl restart usbmuxd requires a password. Pending delivery interrupted gracefully with SIGINT. Last direct installed identity verification remains Reps1.5.0(102), not104. User next action: sudo systemctl restart usbmuxd, then resume normal helper and postflight. No certificate/profile changes, GitHub push or release.
