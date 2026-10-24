# Workout streak — 1.2.7 (89)

## Objective and approved rules

Replace the cumulative completed-workout-day count with native LabeledContent: Streak on the left and e.g.15 days on the right. The user explicitly approved inclusive calendar days (rest days included), breaking after N consecutive missed scheduled workouts where N is the current enabled nonempty weekly workout count. Completing a workout resets consecutive misses; after a break, the next completion restarts at1. The user additionally confirms that adding/removing workouts dynamically adjusts the threshold to2/4etc. Today's planned workout is not missed until its day has ended. Photos, canceled/active sessions and multiple completions on one date do not inflate or preserve the streak.

The separately requested white camera glyph is already committed as3c393ca, version1.2.6(88), installed after a slow final transfer. This second commit includes only streak-related functionality, delivery metadata and documentation.

## Decisions

WorkoutStreak derives its result from the same chronologically ordered AttendanceDay history as the grid, using the current valid weekly schedule count. There are no historical planning snapshots: changing the current schedule recalculates historical missed days and the derived streak, consistent with the existing grid; this does not rewrite training history. No schedule/no completed workout =>0days.

Settings→Progress→Streak Units uses a native menu picker: Days (default) or Largest Unit. Floor conversion chooses365days/year,30days/month,7days/week;15→2weeks and372→1year. The stored presentation-only choice uses the existing @AppStorage UI-preference convention (like haptics), updates Progress immediately and survives relaunch. It is not part of training JSON; no training schema/archive/version change, private-photo access, cryptography, permission, capability or dependency change.

## Implementation and verification

- [x] Add focused real attendance/streak and formatting tests. Initial implementation stubs fail26assertions; blocked sandbox SwiftPM run is not counted as RED.
- [x] Implement current-run start/miss reset/break logic using calendar date differences; preserve existing attendance eligibility.
- [x] Replace the summary row; add the native Settings picker and concise rule/unit explanation.
- [x] Full355host tests/zero failures7.604s, including10new streak/formatting tests.
- [x] Independent review, strict Swift lint, nine metadata/style checks, real xtool compilation, metadata regeneration/embedding and unsigned app/widget inspection.
- [x] Same identity/certificate/capability preflight, normal device-run.sh and direct installed-app/profile postflight.
- [x] Update README and project docs and prepare the second requested dedicated versioned commit; Git history establishes its result. No new GitHub push or public IPA Release requested by this turn.

## Review focus and physical checklist

Check today vs a genuinely ended scheduled day; breaks followed by completion; missed days separated by rest days vs completed workouts; dynamic2/4weekly counts and disabled/empty workouts; photo-only days; DST and date corrections. The schedule is current, not reconstructed historical configuration. Check Days/Largest Unit immediately and after relaunch, singular/plural, Dynamic Type and VoiceOver. The physical device is authoritative for the white camera glyph and native picker/row rendering. Never inspect actual private media or reset personal data for tests.

## Progress

Implementation and full host suite pass. Review and real iOS compilation in progress. First camera-only delivery is independently confirmed1.2.6(88); exact same effective identity/signer/certificate/capabilities and valid CMS-verified app/widget profiles. No signing repair or certificate replacement.

Independent reviewer found no actionable issue; targeted10tests pass. Strict lint/nine metadata checks and real xtool23.94s plus metadata2.33s/unsigned inspection pass, without warnings. Standard USB89delivery in progress after88postflight; no concurrent installer, certificate repair or cache clearing. Evidence:/tmp/sport-real-streak-*.

## Delivery result

Standard device-run.sh exits0, installation/verification100%. Direct postflight confirms exactly one Sport1.2.7(89), identical effective identity/signer/entitlements/exact cached certificate, certificate valid>24h and both installed app/widget CMS profiles valid and matching. This confirms installation, not physical UI behavior. Final strict lint and diff whitespace checks pass. No push or public Release performed. The completed camera-only commit is3c393ca; the next dedicated commit contains this streak feature and delivery records.

## Direct unit selection —1.2.8(90)

User requests moving the Days/Largest Unit choice from Settings directly to a tap on the streak value. Scope: a small StreakSummaryRow with native LabeledContent/Menu/Picker, same preference key and current saved selection, accessible control label/value/hint. Remove the Settings section/footer; no calculation, domain, security or data-model change. Version app/widget/inspector1.2.8(90), own corrective commit after verification. No new tests mirroring SwiftUI source and no redundant domain suite; last full355tests on89remain calculation evidence. Run strict lint, nine metadata/style checks, real xtool build, regenerate/submit compiler metadata, unsigned bundle inspection and normal same-identity USB delivery/postflight. Physical recipe: tap33days or the current value, inspect selected mode, switch, relaunch, confirm saved selection and no duplicate option in Settings; large text/VoiceOver. Implementation complete, verification in progress.

Direct-menu90delivery confirmed: device-run.sh exits0; installation/verification100%. Direct postflight verifies exactly one Sport1.2.8(90), identical effective identity/signer/entitlements/exact cached certificate and valid CMS-verified app/widget profiles. Existing selection preserved by the same preference key. Physical interaction remains user review. Final lint/metadata/build/inspection pass. Dedicated local corrective commit follows; no push/public Release. Evidence:/tmp/sport-streak-menu-*.
