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

- **208 host tests:** business rules, real SQLite persistence, migrations, transactions, timer state, progression and transfers.
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
