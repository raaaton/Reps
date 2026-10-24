# What Sport's tests prove

An assertion is the final check, not the whole test. Its value depends on the setup and actions that happen before it.

## Real scenarios

The host package builds the same `SportCore` and SQLite sources as the iPhone app. Tests use temporary or in-memory databases, not personal on-device data.

| Scenario | What actually runs | What the assertion checks |
| --- | --- | --- |
| Persistence | Save a workout, create a new repository instance, reload SQLite | The saved state and results survived reopening |
| Migration | Create an older database shape and real rows, run migrations | Settings and history remain intact under the new schema |
| Pause/resume | Start rest, advance a controlled clock, pause, reopen, resume | The remaining duration stays frozen and the new deadline is exact |
| Stale actions | Deliver an old Pause or duplicate set completion | An old command does not change the current timer or create another set |
| Transaction failure | Submit invalid configuration or import data | The complete prior state remains unchanged |
| Warm-up flow | Record warm-up sets, expire or skip rests, finish work and stretch | Each required stage occurs in order and only the final stage completes the workout |
| Clock regression | Complete a warm-up, move time backward, try cancellation | Inconsistent end dates are rejected and exports remain usable |
| CSV round trip | Export actual repository records, parse them, import into a fresh database | Results, loads, goals and auxiliary stages are preserved |

Examples are in [WorkoutSupportTests](../Tests/Host/Tests/SportCoreTests/WorkoutSupportTests.swift), [WorkoutTests](../Tests/Host/Tests/SportCoreTests/WorkoutTests.swift), [RestActivityTests](../Tests/Host/Tests/SportCoreTests/RestActivityTests.swift), and [TrainingTransferTests](../Tests/Host/Tests/SportCoreTests/TrainingTransferTests.swift).

Checking `restored == original` after all those operations is useful: it verifies a complete persisted snapshot, not merely a hand-written constant. However, a test can still be weak if the expected value just repeats the implementation, or if it never exercises failure and boundary cases.

## Validation layers

- **284 host tests:** business rules, real SQLite persistence, migrations, transactions, timer state, progression and transfers.
- **6 metadata tests:** compatibility and strictness of the App Intents metadata adapter, using recorded compiler fixtures.
- **Swift lint:** formatting and source consistency, not functional correctness.
- **xtool builds:** the app and extension compile against the configured iOS SDK.
- **Bundle and IPA inspection:** identities, versions, arm64/iOS target, embedded resources and metadata, packaging, and absence of personal provisioning in public IPAs.
- **iPhone tests:** rendering, gestures, lifecycle, permissions, biometrics, haptics, system notifications and Live Activity interaction.

## What remains manual

Linux host tests do not execute SwiftUI, a camera, Face ID, or the iPhone's WidgetKit runtime. There is currently no automated XCUITest or simulator UI suite in this Linux workflow. The preview of an icon or chart is not proof of its physical-device appearance.

The installed 1.0.1 build was accepted by the user before publication. Detailed individual device scenarios remain useful: verify the new inter-exercise rest while rating Feeling, exact automatic stretch completion and sound, goal carry-forward, lighter-load proposals above 9, toolbar glyph contrast and unfiltered timed charts on the iPhone. Resume after backgrounding during the final stretch while an exercise chart is already open: the completed workout must appear without another user edit. Detailed accessibility, large text, notification delivery, suspension and supported icon-appearance checks remain manual where no specific device result has been reported. Historical development notes must not be read as proof that every manual scenario passed.

## Commands

```sh
swift test --package-path Tests/Host
python3 -m unittest discover -s Tests/Metadata -v
swift format lint --strict --recursive Package.swift Sources Tests/Host/Package.swift Tests/Host/Tests
```

These tests never require the user's private photos or real training database.

The stretch deadline is persisted and reconciled to the exact target after suspension. The foreground app uses its existing completion sound. Background sound at the deadline is not scheduled by a new notification or Live Activity and is not guaranteed while iOS suspends Sport.

1.0.3: attendance tests cover no completed history, current day, rest days, cancellation, completed off-schedule days, first workout outside the window and Paris DST. iPhone checks: missed-day dot and labels, no Partial, native Cancel neutral in both appearances, destructive action still red, confirmation dismisses on vault lock/background.

Photo category follow-up57: synthetic metadata tests cover Other decoding/roundtrip, category ordering before unassigned photos and same-category/different-date comparison constraints. Existing legacy metadata test remains unchanged. Verify add/edit/select/compare on iPhone; no agent access to real private media.

Build60 tests add direct load-goal batch projection/adoption, whole-batch stale rejection, forced SQL rollback and real completed-live-to-next-workout goal inheritance. Native popup consent/Cancel and Accent-filled circular toolbar with black glyph need physical review.

Build61 replaces completion-batch tests with transition-decision tests: explicit Keep preserves old goal, Update applied before next exercise, both preserved after real stretching completion and cancellation, restart and next-workout inheritance, stale goal/inventory rejection, SQL rollback and migration8→9 preserve active data. Full199tests pass. Native timing on Next Exercise/Continue to Stretching remains iPhone recipe; no end summary prompt.


1.0.6 :219tests hôte, dont11nouveaux scénarios WorkoutSetCountTests : 2séries mardi/4samedi, réouverture, instantanés actifs figés, fin après le bon nombre, objectifs indépendants, ajustement des cibles, catalogue/réordonnancement/suppression, migration10→11, ancien JSONv1 et nouveau v2, rollback SQL, refus des doublons sans crash et objectifs incompatibles toujours exportables. Revue indépendante : trois défauts identifiés puis corrigés (doublons v1, export d'objectifs obsolètes, contexte Today à minuit). Recette iPhone : modifier les séries dans Workouts/Annuler/Enregistrer ; même exercice sur deux jours ; Today/préparation/suivi ; objectifs par workout ; relance ; tailles de texte/VoiceOver.


Build67 (présentation uniquement) : les219tests existants passent,6metadata/lint strict/build xtool/inspection aussi. Revue UI ciblée sans défaut concret. Recette physique : menu au niveau de chaque exercice, coche1...8 et valeur Custom actuelle, sélection2/4, Custom positif/0/1001/vide, Cancel sans changement, annuler le workout, noms longs/grands textes, VoiceOver, Edit/déplacement/retrait. Pas de nouveau schéma, logique métier ou test hôte simulant SwiftUI.


## Body Weight — 1.1.0 (68)

242 host tests pass, including 23 new tests for daily weight persistence, parsing and validation, corrections/deletion/stale records, SQLite migration 11→12, JSON v3 and legacy/CSV preservation, weekly reminders and DST, shared calendar periods, trend summaries, and Add/Edit target transitions. The complete suite retains all existing workout, vault-domain and notification-test coverage. Six App Intents metadata tests, strict Swift lint and unsigned bundle inspection also pass. Independent review found two UI state issues; both were fixed and re-reviewed.

Physical-device checklist (not validated by host tests):

- Progress → Body Weight: empty state, one point, multiple dates, latest value and delta; inspect chart points and switch 3/6/12 months. Check exercise charts, including archived exercises, retain existing calculations.
- Add a weight with comma/point, edit the same date, visit an occupied date then a free date, Cancel, move an existing entry, and confirm deletion. Relaunch and check persistence.
- Settings → Notifications → Body Weight: explicit weekday/time, Cancel, Save, permission refusal, disable and re-enable. Verify the 28-day explanation.
- Tap a reminder with Progress idle, under an attendance sheet, and with the vault open: dismiss/lock before presenting entry. Save today's measurement and check that its reminder disappears while subsequent weeks remain scheduled.
- Check light/dark, long dates, largest text sizes, period menu fallback, decimal keyboard dismissal, VoiceOver labels/order and chart accessibility.

A successful USB install does not validate these visual and system-notification interactions.


## Main workout goal in Progress — build 69

Six new PrimaryExerciseGoalTests exercise the actual snapshot selection used by the subtitle: total weighted volume rather than individual load, weighted priority over bodyweight repetitions, sum of different per-set repetition targets, total isometric duration regardless of load, stable ties/untimed targets, and missing/unassigned/stale goals. All six were observed failing against the former single-assignment behavior (seven assertion failures), then passing with the selection rule. Full suite: 248 tests, zero failures.

Physical check: the same exercise in two workouts should show the selected workout's exact repetition/duration and load summary, rather than Goal and Progress. Edit either goal or its set count and check the row refreshes; inspect long target strings with larger text and VoiceOver. Workout-specific goals and exercise history remain independently accessible in the detail screen.


## Accepted exercise changes and load review — build70

257 host tests / zero failures, including nine GoalReconciliationTests: per-workout ranges/counts and exact loads after accepted edits; transitions repetitions/duration/untimed; a timed goal updates the other workouts; unavailable exact composition remains unavailable; catalogue and migration rollback; upgrade preserves active snapshots; Progress flags any affected workout even if its main goal is available; name-only edits retain custom repetitions and missing goals stay absent. The first six tests failed with 19 assertions against the old behavior, then passed after reconciliation. A legacy archive test now verifies preview/restore adapts a stale four-set goal to the actual two-set assignment before starting. Existing stale-command and atomic timed-goal tests remain green.

Device checklist: change repetition range or duration and save once; goals in every assigned workout should match without Review needed. Rename/disable/remove a saved inventory component and verify Progress shows Review needed, details explain the composition issue, and reselecting an available load clears it. Check two-workout exercise with only its secondary goal unavailable. Check readable status/goal subtitles with larger text and VoiceOver. An already active workout and recorded history must retain their snapshots.


## Per-set curves and latest exercise targets — build71

270 host tests / zero failures (7.633s), including13 new scenarios: heavier two-set session outranks lighter four-set session at equal reps; fractional per-set averages with exact totals; global latest-session propagation and truncation/last-set extension; once-only upgrade with active snapshots unchanged; failed completion/migration rollback; actual timed targets and frozen warm-up; later manual history with cancelled sessions ignored; new assignments; same-load Keep refresh; strict timed goal validation/legacy decoding; JSONv4 restore and explicit untimed clearing. Initial seven tests failed behaviorally (17 assertions across two red runs), then passed. Two review regression scenarios failed with four assertions before fixes. Two existing migration fixtures lacked the full schema; lazy inventory reading preserves these additive tests. New fixture compiler/date mistakes were corrected and are not counted as behavioral failures.

Strict Swift lint, six App Intents metadata tests, xtool build14.89s plus metadata embedding2.61s and unsigned app/widget inspection pass. Independent review found resize/new-assignment/timed-clear issues, corrected and reviewed again without further actionable findings.

Device checklist: compare2vs4sets at the same reps; curve means vs unchanged period/workout totals; drag bubble `• N sets` at both edges; complete an exercise in either workout and verify both future targets; timed per-set tenths before/during effort and warm-up; edit duration fields and clear all to untimed; relaunch, large Dynamic Type and VoiceOver. Build/install do not establish these physical results.


## Ceiling-average goals and mixed-load regression — build72

275host tests/zero failures (6.801s), including five new scenarios first observed red with12assertions: screenshot Pike/L-sit values; exact mean seconds; unequal loads with lower-load reps excluded; large valid values without sum overflow; real Bulgarians live completion and14→15repair, history unchanged and manual customization retained on subsequent reopen. Existing latest-exercise expectations now reflect uniform mean targets; legacy Codable/manual-target tests retain exact values. Strictlint,6metadata, xtool28.68s plus metadata embedding2.37s, unsigned72inspection and independent targeted review pass.

Device checklist: Progress shows Pike4×12 and L-sit4×18s for the reported data; Bulgarians latest mixed session gives11reps at7.5kg, repeated for each workout count. Newer2×10at7.5kg must supersede an older mixed session for that same exercise. Recorded history and graph details retain exact source values. Verify Today/preparation/goal detail and relaunch; physical results remain user validation.


## Global Stretching — build 73

281 host tests pass (7.122 s), including six added scenarios: persisted flag across reopen and toggling without rewriting active snapshots; every schedule; JSONv5 restore/legacy v4 default/CSV preference preservation; schema15→16 preservation; one/two warm-up-only support validation; warm-up/rest → working sets → last Feeling completion with CSV/JSON round trip. Two lifecycle/validation tests first failed with six assertions/errors; the transfer test failed before JSON shape/restore support. Legacy migration fixtures now include their original preferences table or remove the new column before simulated downgrade. Strict lint and six metadata tests pass. Independent review found a fixture downgrade issue, corrected; no production findings.

Device checklist: Settings → Training → Stretching off; prepare a workout (warm-up visible, stretch selector absent); complete it (Finish Workout after final Feeling, normal summary). Reopen Sport and check off persists; enable again and verify stretch selection/flow returns. A workout already started keeps its original stages. Check large text, VoiceOver state and light/dark rendering. Host tests/build/install do not establish these physical results.
## Audit corrections — build 75

290 host tests pass. Nine new HistoryGoalReconciliationTests cover latest manual history, edited/deleted sources, removal of the final source, personalized targets, active snapshot preservation, preserved/invalidated explicit decisions, forced SQL rollback, historical set-count corrections, catalogue renaming and an unprojectable exact load. Original six scenarios failed with 11 assertions before implementation; three additional reviewer cases were reproduced before correction. Legacy history/goal tests now expect an automatically inherited baseline while retaining their stale-command, persistence and schedule-structure checks.

The isolated actual-source probe also verifies 18,700 ms → 0:18.7 and 500 ms → 0:00.5 (localized decimal separator), new manual result 12 → next goal 12, and accepted 4,500 g → newly assigned goal 4,500 g after rename. The probe uses in-memory fictional data and the exact WorkoutLabels source, not SwiftUI rendering. Full lint, six metadata tests and real iOS compilation/bundle inspection pass. Physical checks: rename/edit history and reopen future targets; seconds/tenths across History and selected chart details; long history scroll and midnight refresh; largest text metric menu; camera import/cancel plus background/session locking. A cleanup failure requires injection on a test device to validate the error branch physically. No iPhone FPS or camera-encoding latency claim.

## Selective revert — build 76

284 host tests pass (7.184s). Restored baseline ExerciseGoalTests/HistoryEditingTests expectations were observed failing before the revert. Three HistoryDecisionTests cover history add/edit/delete leaving future goals unchanged, preservation of an explicit load decision after rename, and invalidation of a corrected performance decision for a new assignment without rewriting existing future goals. Strict lint, six metadata tests, xtool22.93s plus metadata embedding and unsigned app/widget inspection pass. Independent scoped review approved; device delivery currently awaits USB connection. Physical checklist: history correction preserves the existing future target, recorded sets display whole seconds, original Consistency scroll works, retained metric-menu/camera/Stretching behavior remains.

## Skills — 1.2.0 — build 78

New host coverage exercises catalogue seeding and reopening, personal-step validation/duplication/deletion, separate volumes and explicit adoption across workouts, free-practice pause accounting, persisted activity, countdown cancellation, actual repetitions, duplicate/stale commands, two repository connections, mixed-workout gating and completion, backward-clock cancellation, expired-rest skip, active JSON round trips, paused rest/countdown restoration, nested unknown fields, malformed content rejection, and CSV preservation with original-workout provenance. Existing migration assertions now target schema17/archive6; legacy fixtures omit fields unavailable in their historical formats.

Physical checklist: discover all four roadmaps and their extensions; create/duplicate/reorder steps; configure the same skill differently in two workouts; test placement before/after force with Stretching on/off; practise freely without touching the phone between attempts; pause/background/relaunch; record holds and repetitions; skip/cancel without losing recorded attempts; inspect mixed/standalone history and separated metrics; export/restore a resumable archive; use links while offline; verify largest Dynamic Type, VoiceOver, safe areas and controls. Do not treat host tests or compilation as device validation.

## Skills interface refinement — build 79

315 host tests pass, including old preset US spelling presentation, untouched custom text/URLs and immutable original content. Six metadata tests and strict Swift lint pass. The first UI compilation exposed an unsupported NavigationLink overload; explicit native destination/label builders fix it, and xtool builds successfully. On iPhone check Progress ordering; roadmap/current marker; all four preset step details and extensions; Practice/Add to Workout; manual success/current-step adoption; More menu editing/archiving and red glyphs; large Dynamic Type and VoiceOver. Rendering and interaction acceptance remain physical checks.

## Skills follow-up — build 80

328 host tests pass, including progression forward/backward reconciliation, completion waiting for secondary goals, reset/future-block volume preservation, distinct archive/delete lifecycle, deletion across mixed and independent history with active guards, both workout-assignment model paths surviving a real SQLite reopen, preset spelling/video display compatibility, and strict generated JSON validation/single draft save. Nine Python metadata/style checks guard centralized controls and root-owned block presentation. Final xtool and unsigned bundle inspector pass.

YouTube selections: GMB's current author pages link handstand `d6_lcWtQDxw`, planche fundamentals `8mnNpNZ88Oo`, straddle `6snDOgFBBFA`, advanced/full `wYWlie_g_js`, press `SfLaCKaljU4`, HSPU `nk-bjYYZVaE`, L-sit `BbAkWxDZKIM` (chapters135/202/235/268/306 seconds). FitnessFAQs demonstrates planche push-ups `TZ63httkob4`, front lever progression `AGhb8V8M758`, and rows/pulls `dze1Dpi3CKk`; Stretch To Strength demonstrates L-sit/V-sit progression `0pkTDnbRe8Q`. Author descriptions and progression contents were checked through web sources. Direct web fetching failed for some videos; all selected URLs subsequently opened a YouTube player in the in-app browser, with loaded durations. Some players showed advertisements; this is not proof of complete uninterrupted playback or a frame-by-frame technique audit. No video is embedded/downloaded into Sport.

Physical checks still required on iPhone: independently perform Skills→Add to Workout→Save→reopen; Settings→Workouts→Edit→Add Skill→configure→Save block→Save workout→reopen (the intermediate block must stay presented). Check all Skills forms and menus in light/dark and large text/VoiceOver. Complete the main goal while secondary goals remain incomplete, finish the last secondary goal, regress, reset, archive and permanently delete. Generate via an installed provider, paste its real response, retry invalid JSON, inspect preview, save once and reopen. UIKit/SwiftUI modal lifecycles and external-provider app behavior cannot be automated by the host-domain tests on Linux. Independent reviewer stopped at its account usage limit after identifying the swipe-contrast issue; that finding was fixed, but no full independent review of the expanded scope was completed.

## Kavi creation and Skills controls — build 81

331 host tests pass with zero failures (7.69s); three new cases cover fenced/prose-wrapped AI responses and rejection of ambiguous multiple roadmaps. Two cases were observed failing before the parser change. Nine metadata/style checks, strict Swift lint, diff whitespace checks and the real xtool build pass. Final app/widget inspection confirms 1.2.0(81); provider assets are bundled. Logs are in /tmp/sport-skills-kavi-followup/.

Physical checks: centered title, white plus/cancel symbols, archive below Completed, icon-only archive swipe and whole-row long press. For AI creation test name→provider, installed app opening, return/paste→editable review, edit→back→Continue Reviewing, save once and reopen; invalid or empty clipboard must show an alert. Also check accessibility text sizes and cancel in manual creation. The actual response associated with the user's “nothing happens” report was not provided: wrapped-response rejection is reproduced, but its causal link to that particular response remains unconfirmed. Linux tests/build do not establish native navigation or handoff acceptance.

## Physical corrections — build83

332 host tests pass, including independent achievement updates and a video-research prompt regression first observed red. Nine metadata/style checks and strict lint pass. Physical checks: AI/manual cancel has a single native glass boundary; all three provider logos visible; Archived Skills permanent-delete glyph red in detail menu and long-press menu; marking a later step Consistent retains current and leaves other achievements unchanged; provider response contains actual verified video links when web search is available. Exact rejected ChatGPT response requested, not yet received: no claim of fixing that specific parser failure. Evidence: /tmp/sport-skills-123/.

ChatGPT follow-up: supplied response shows Markdown backslash hard breaks and encoded indentation. Regression reproduces that formatting rejection, then passes with string-aware normalization. Valid escapes and literal entities inside instruction strings are preserved; malformed escapes and ambiguous roadmaps remain rejected.334 host tests/zero failures(7.548s), nine metadata/style checks and strict lint pass. Physical re-paste of the original response remains required because the chat transport itself may contribute formatting.

## Accent symbols — build85

Visual-only shared LabelStyle, no domain changes. Check Settings navigation rows, Progress Skills/private-photo rows, Skills history/actions and secondary workout controls: normal text retains its style, accompanying symbol uses accent. Verify destructive context menus remain red, filled swipe action contrast and archive icon-only deletion, black symbols on accent-filled primary buttons, white standalone cross/plus symbols, and unchanged native tab icons in both appearances and large text. Run existing metadata/style checks, strict lint, real build and package inspection; physical rendering remains pending.

## Native Skills menus — build86

Physical checks: open Skills plus menu (AI/manual icons blue, titles primary); open preset More (duplicate blue, archive/reset red); open custom More (edit blue); long-press roadmap (current/first-success/consistent blue); check AI Other Options and workout Add Skill menus. Plus/ellipsis trigger glyphs stay white and archived deletion stays red. Linux lint/build/metadata checks cannot validate native menu image coloring. Original UIImage rendering mirrors the red technique the user confirmed working. No domain changes.

## Consistency photo activity — 1.2.5 (87)

345 host tests pass, including eleven new photo-activity/attendance cases: legacy migration and byte preservation, public counting after lock/reopen without payload reads, edits/deletion/reset, invalid dates/expired leases, stale/incomplete/duplicate/foreign backfill, forced metadata-update rollback, forced second-row backfill rollback and deletion staleness; photo-only range, completed/missed/today states, invalid/future/nonpositive counts and explicit ranges across Paris DST. The migration assertion failed against baseline schema1 before correction (one behavioral failure); the initial sandbox blockage/fixture compiler error are not counted as RED. Attendance tests produced seven failing assertions before implementation. Additional review cases were not separately observed RED.

Strict Swift lint and nine metadata/style checks pass; real xtool compilation and final app/widget inspection pass with regenerated App Intents metadata. Independent security/code review reports no actionable finding and recommended the added multirow rollback case. Host tests do not execute CryptoKit, Face ID or SwiftUI. Physical checklist and USB evidence: [ExecPlan](exec-plans/2026-10-24-attendance-photo-activity.md). No real private media or user database is inspected by the agent.

## Current workout streak — 1.2.7(89)

355host tests pass7.604s, including10new tests exercising inclusive calendar days rather than completion totals; rest/today treatment; third-miss deadline; miss reset and restart at1; dynamic2/4weekly thresholds; empty history/no planning/photo-only days; active/canceled/photo exclusions; duplicate and off-schedule completions; Paris DST; singular/plural day formatting; largest full unit boundaries including15→2weeks372→1year. Initial stubs failed26assertions before implementation. The sandbox CFSocket blockage was interrupted and is not a RED result. Independent review reports no actionable finding and reran all10targeted tests successfully.

Existing nine metadata/style checks, strict lint, real xtool compilation and bundle inspection pass. On iPhone check Streak/right-aligned unit value, white photo-day camera, Settings→Progress→Streak Units (both choices, immediate update and relaunch), current schedule edits, midnight, large text and VoiceOver. No host test pretends to exercise @AppStorage/SwiftUI rendering or user-device data.

## Direct streak-unit choice —1.2.8(90)

Visual-only relocation: no new source-mirroring tests or repeated domain suite. Strict lint, nine existing metadata/style checks, actual iOS compilation and final bundle inspection pass. On iPhone tap the streak value itself, inspect Days/Largest Unit selection, switch both ways, relaunch and confirm persistence of the existing choice; verify the option/footer are absent from Settings. Check large Dynamic Type and VoiceOver label/value/hint. Calculation, underlying preference key and vault behavior unchanged.
