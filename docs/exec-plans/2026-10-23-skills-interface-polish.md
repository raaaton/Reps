# Skills interface polish — 23 October 2026

## Objective

Address the user's physical iPhone screenshots: make the next action obvious, reduce duplicate controls and reading overhead, expose a readable roadmap, place Skills between Consistency and Body Weight, use US English throughout app-owned copy, and make destructive icons red along with their labels. Retain data, manual progress, custom steps, assignment independence and activity snapshots. No GitHub push.

## Design

Use native list navigation and one prominent Practice action. The skill overview shows the current/default starting step and a numbered roadmap, with optional extensions under Beyond the Goal. Tapping a step opens a focused step detail with clearly labeled instructions, cues, practice guidance, explicit progress and current-step adoption. Browsing never silently adopts a step. Move editing/archiving to a toolbar menu; keep history discoverable. Primary/secondary semantic text replaces uniform accent-colored rows; no decorative glass or gradients.

HIG basis: Designing for iOS says “Limit onscreen controls to keep primary content and tasks prominent; make secondary details and actions discoverable with minimal interaction.” Buttons recommends “In general, use a prominent style (accent-color background) for the most likely action.” These guide the hierarchy; the exact roadmap and grouping are Sport design choices. References read from apple-hig, plus emil-design-eng and write-swift.

## Steps

1. Save dirty baseline and inspect docs, screenshots and existing views.
2. Fix US copy including previously persisted preset text without rewriting custom input or historical snapshots; cover this compatibility with a domain test.
3. Reorganize skill overview and step detail; reuse destructive button styling on all explicit destructive icon buttons; move Skills row.
4. Strict lint, host tests, metadata tests, real xtool build and bundle inspection.
5. Install next build using existing identity/capabilities, verify actual installed version. Await physical feedback.

## Verification and progress

- Baseline preserved in `/tmp/sport-skills-ui-before/dirty-files.tar.gz`; 84 Markdown files inventoried/read into `/tmp/sport-skills-ui-before/markdown.txt`.
- Implementation, host/SDK verification and installation completed. Physical interaction acceptance pending. Existing unrelated work remains intact.

## Extension of scope explicitly requested in pasted brief

Implement all eleven requests, preserving the preceding visual corrections. Use typed sheet payloads for Add to Workout and a sheet owned by ScheduleEditor with a private block draft committed only on Save. Progress reconciliation uses ordered steps; advancing marks predecessors consistent, regressing demotes later consistent statuses to first-success so the previous achievement evidence is retained. Completion requires all main steps and extensions consistent; main completion alone unlocks continued Beyond the Goal work without putting the skill in Completed. Archive retains history, permanent deletion removes the archived definition/progress/future assignments, reset clears progression while preserving recorded history. History deletion removes the chosen terminal practice, including a mixed-workout child, without deleting strength history; block deletion is refused while its workout is active.

Kavi investigation: requested local path iOS/Kavi absent; existing iOS/Flashcards is Kavi. GitHub raaaton/Kavi BulkImportParser.swift matches the local source byte-for-byte. Kavi uses explicit external AI handoff (prompt clipboard, provider app, pasted JSON validation/preview), no AI API/backend/key. Sport adopts this functional flow with a strict bounded JSON decoder, generated local IDs, explicit preview/save, and no write before Save. No invented integration or embedded secrets.

Reviewer for initial polish identified red ink on red swipe backgrounds; keep native destructive swipe buttons with contrasting foreground, explicit semantic red-ink components for unfilled list/menu controls. Reviewer became unavailable due usage limit before completing the review; remaining work will be checked locally, with that limitation reported.

## Final development and delivery evidence

- Implemented the eleven follow-up requests. New controls/styles are scoped to Skills; the workout editor changes are the requested block-presentation bug fix. Native filled swipe actions retain contrasting white ink on destructive red backgrounds; unfilled destructive text/glyphs use system red. No security or database-schema migration was introduced.
- 328 host tests / zero failures, strict lint without output, nine Python metadata/style checks pass; git diff --check passes. Logs: `/tmp/sport-skills-expanded-tests.log`, `/tmp/sport-skills-expanded-lint.log`, `/tmp/sport-skills-expanded-metadata.log`.
- Last real xtool compilation code0 (10.86s), metadata regenerated/reembedded; `verify-foundation.py` code0 confirms app and widget1.2.0(80), configured identity and declared capabilities. Source changes were complete before this final build. Logs: `/tmp/sport-skills-expanded-final-build.log`, `/tmp/sport-skills-expanded-inspection.log`.
- USB helper code0, installation and verification100%. Direct postflight confirms a single installed Sport1.2.0(80), exact prior identity/signer/entitlements and ProfileValidatedtrue. The old version79 was the preflight target, not an artifact mismatch. An automatic reviewer rejected the first installation attempt on that misunderstanding; explicit four-plist80 checks resolved it and the same helper was approved. Logs: `/tmp/sport-skills-expanded-install.log`, `/tmp/sport-skills-expanded-postflight.json`.
- Kavi local/GitHub parser matches byte-for-byte; functional external-provider handoff implemented, not a model API. No generated data is written until validated preview is explicitly saved.
- Curated video provenance and browser-player opening checks are documented in TESTING; full video playback/technique auditing and UIKit/provider behavior remain physical/manual limits.
- The independent reviewer reported a swipe-action contrast issue, fixed by retaining native filled swipe appearance. Its full review could not finish because the account usage limit was reached. No second reviewer was simulated. Host/SDK checks do not establish physical UI acceptance.
- Next user review: both Add to Workout paths end-to-end; Skills controls across forms/menus; archive/delete/reset distinctions; main versus all-goal completion and regression; real external AI response and retry. The actual SQLite persistence and domain transitions have host coverage; modal lifecycle, VoiceOver/Dynamic Type and real app handoff require iPhone testing.
- No commit, push, public release, cache deletion or certificate replacement.

## Follow-up — Kavi creation flow and targeted controls

User requests: white neutral Skills plus, inline centered title matching Body Weight, Archived Skills below Completed, icon-only archive swipe deletion with long-press deletion retained, neutral transparent Liquid Glass white cancel glyphs (only confirmation checkmarks stay accent/black), and the actual Kavi AI-creation UX. User reports Review Skill does nothing. Read Kavi's NewDeckCreationFlow and parser: separate name/provider/editor navigation, provider logos/rows, bottom opening/paste panel, clipboard parse-and-advance, visible alerts. Sport's prior monolithic Form has inline errors below the response controls; its decoder rejects prose surrounding valid AI JSON. Reproduce wrapped responses with host tests; adopt Kavi's JSON candidate extraction while rejecting ambiguous multiple objects and retaining strict semantic validation. No assumption that this covers every possible user response, since the actual response was not supplied.

Target implementation: named root flow with a stable NavigationStack, provider selection screen and safe-area bottom panel, one Paste from Provider action that parses and advances directly to an editable review. No raw JSON editor or separate Review Skill button. Preserve drafts when returning from review, close the whole creation sheet only after saving, and show errors as alerts. Provider logos are the existing Kavi vector assets, rendered once to bundled template PNGs using already-installed rsvg-convert; no runtime library or asset compiler change.

Baseline of target files: `/tmp/sport-skills-kavi-followup/baseline.tar.gz`. Re-read/inventoried85Markdown documents. New physical review remains required after build81 installation.

### Build81 verification and delivery

- Completed targeted controls, archive ordering/actions and the Kavi multi-screen creation flow. Draft edits survive explicit back navigation; Continue Reviewing reopens them. Accessibility text sizes move the action panel into scrolling content.
- Regression RED: wrapped/prose AI responses failed in two of six selected cases before implementation. GREEN:331 host tests, zero failures (7.69s); nine metadata/style checks pass; strict lint and git diff --check have no output. Logs: /tmp/sport-skills-kavi-followup/tests.log, metadata.log, lint.log, diff-check.log.
- Final real xtool build succeeds (9.72s), metadata embedded; package inspection passes for app/widget1.2.0(81). All four source/compiled plists verified81 before USB delivery; three provider PNGs present in the SwiftPM resource bundle. No identifier, schema, entitlement or dependency changes.
- Authorized device-run.sh succeeds with installation/verification100%, code0. Direct installed-app postflight confirms exactly one Sport1.2.0(81), same effective identity, signer and entitlements, ProfileValidatedtrue. Logs: /tmp/sport-skills-kavi-followup/install.log and postflight.json.
- User clarified Review Skill previously did nothing. The actual clipboard response is unavailable; reproduced parser rejection is evidence for a fixed failure path, not proof of the specific reported cause. The replacement action parses and navigates directly, with visible errors.
- Physical acceptance of navigation, app handoff, Dynamic Type/VoiceOver and styling remains pending. Existing independent-review limitation remains; no completed fresh independent review is claimed. No commit, push, public release, cache cleaning or certificate replacement.

## Semantic version correction — 1.2.1 (82)

User requests patch increments for fixes, minor increments for important features, and explicit approval before a major increment. Persist the rule in AGENTS.md. Reclassify the latest corrective delivery as1.2.1 with a new independent build82; preserve historical build81 evidence. Only app/widget version metadata and expected inspection version change. Rebuild, inspect and install using the existing identity; confirm actual installed version. No functional code changes or new test cases required.

Delivery complete: fresh nine metadata/style checks, strict lint, xtool compilation (final2.11s), regenerated embedded metadata and app/widget inspection pass. Device helper exits0; direct postflight confirms exactly one Sport1.2.1(82), same effective identity, signer and entitlements, ProfileValidatedtrue. Logs: /tmp/sport-version-121/. No functional source changes, so the331-test build81 domain evidence remains applicable without rerunning the suite. No push/release; physical interaction acceptance remains pending.

## Physical corrections — 1.2.2 (83)

User supplied IMG_5332 showing nested glass on the AI cancel button; neutral toolbar controls were explicitly styled glass inside system glass toolbar items. Remove the inner style, retaining native toolbar glass and explicit white ink. Provider PNGs are nonempty132×132 template artwork in the packaged resource bundle; bypass named-image lookup using Bundle.module URL and UIImage file decoding. Confirm actual rendering on iPhone. Menu adaptation can ignore SwiftUI foreground colors: use original UIKit SF Symbol ink (systemRed unfilled, white on filled destructive swipe backgrounds) while retaining destructive roles.

Separate settingAchievement from settingCurrent: changing any achievement touches only that step and never moves current or certifies predecessors/demotes other achievements. Explicit current-step changes keep their existing reconciliation behavior. Updated domain regression first failed on current displacement, predecessor auto-validation and later demotion; now passes. The complete suite332 tests/zero failures (7.23s), nine metadata/style checks and strict lint pass. New prompt regression first failed, then passes with explicit web search/verification for every step's video; null is reserved for steps with no result after a real search, unavailable browsing must be disclosed. Sport itself does not verify external provider browsing.

User reports two ChatGPT responses rejected while Gemini succeeds. Requested an exact failing response asynchronously; not yet supplied. No parser change or claimed ChatGPT resolution without a reproducible payload. Existing bounded strict validation remains. Backup and logs: /tmp/sport-skills-123/ (folder name is only an evidence label; target version is1.2.2 build83). No dependency/schema/capability change, push or release.

Build83 package inspection passes for both app/widget1.2.2(83). USB delivery blocked after compilation: direct app-list query reports "Failed to connect to usbmuxd socket. Make sure it's running." systemctl confirms usbmuxd failed, while lsusb still lists the iPhone. Authorized sudo -n systemctl restart usbmuxd cannot proceed: "sudo: a password is required". Asked user to restart the service in their terminal and leave iPhone connected/unlocked. Sent SIGINT only to the checked stalled xtool process to prevent duplicate installers on resume. No signing error, certificate/profile mutation or cache cleanup. Build83 is ready but NOT confirmed installed; last confirmed installed version remains1.2.1(82). Exact ChatGPT response also remains requested for reproduction.

### Resume: concrete ChatGPT formatting and restored USB

User supplied the rejected Muscle-up response and confirmed restarting usbmuxd. The received representation contains Markdown backslash hard breaks and literal HTML-encoded indentation (&#x20;). A regression using that exact formatting pattern fails with the reported missing-JSON error before correction; do not assume transport formatting proves what every clipboard contains. Normalize these known artifacts and nonbreaking spaces only outside JSON strings; preserve all text/URL escapes inside strings, retain strict schema/semantic validation, size bounds and ambiguous-roadmap rejection. A guard test retains escaped quotes, backslashes and literal entities in instruction text, and rejects an invalid escape. Full334 host tests/zero failures(7.548s), nine metadata/style checks and strict lint pass. Logs: tests-final.log, chatgpt-red.log, metadata-final.log, lint-final.log under /tmp/sport-skills-123/.

Direct USB app inventory works again and confirms last installed1.2.1(82). Build83 was not delivered, so the remaining ChatGPT fix joins the same corrective1.2.2(83) package. Rebuild and delivery resumed; no extra version increment needed for an uninstalled intermediate artifact.

Delivery complete after USB service recovery: final ChatGPT-inclusive real build12.41s, metadata regenerated/reembedded and app/widget inspection passes. Helper install-resume.log exits0 with install/verification100%. Direct postflight confirms exactly one Sport1.2.2(83), unchanged effective identity, signer and entitlements, ProfileValidatedtrue. All requested corrections now included in the installed package.334 host tests, nine metadata/style checks, strict lint and diff whitespace checks pass. Physical UI and original clipboard round-trip remain user acceptance checks; the supplied representation's formatting normalization is reproduced in host tests. No push, release, schema/capability/dependency changes or certificate replacement.
