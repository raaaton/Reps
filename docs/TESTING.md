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

- **257 host tests:** business rules, real SQLite persistence, migrations, transactions, timer state, progression and transfers.
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
