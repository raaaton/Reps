# Sport 1.0.1 — workout refinements

## Objective and authorization

User approved the in-chat design on 17 October, explicitly requiring no GitHub push before their device feedback. Work locally; do not publish a new release or tag. Preserve identity, certificates, data, existing native build and caches. Install the ready build through the authorized USB workflow before requesting device review.

## Decisions

- Start a full configured rest on the final set when another working exercise follows. Feeling remains editable during this rest and does not reset its deadline. Once Feeling is saved, the next exercise waits for that same rest. Lock Screen/Dynamic Island use the next exercise and set 1. Pause/resume/skip and cold reload must remain valid. No new rest after the final working exercise.
- On completing a live workout, update future goals to match its actual repetitions and uniform available added load, preserving the configured duration of timed exercises. Do not adopt the separate progression suggestion automatically. Do not modify active snapshots, historic performances, incompatible definitions or unavailable/mixed loads. Cancelled workouts do not update goals.
- Feeling strictly greater than 9 proposes the nearest available lower load, with explicit adoption, preserving repetitions/configured duration. No automatic increase for timed exercises; no invented lower load at bodyweight. Existing <8 rules remain.
- Stretch holds end automatically at their persisted start plus target duration, excluding the preparation countdown. Save the exact target even if resumed late. Separate sides still start individually. Foreground deadline wake and reconciliation on resume; use the existing completion sound/haptic service. Linux cannot prove physical sound delivery or background execution.
- Pause and checkmark symbols on filled cyan actions use black ink, not the global white toolbar tint. Customize retains its native back arrow without a second Close/Cancel control. Timed exercise charts include all loads without a load picker; retain chart projection stability.

## Implementation / verification

Reproduce with real SQLite tests for inter-exercise rest, goal carry-forward, >9 boundary/lower-load selection and exact stretch completion/reload/CSV. Extend boundary tests for missing loads, timed/free duration and no automatic goal adoption. Run applicable tests and then the complete host suite, Swift lint, metadata tests, real xtool builds and unsigned bundle verification. Review changes before deployment; read-only preflight and postflight check same identity/certificate/capabilities. Update documentation with actual results and pending device checks. No push until user confirms.

## Progress

Read existing domain/store/UI, current project and affected ExecPlans. Causes confirmed: rest creation guarded by `number < setCount`, static persisted goals, no high-effort decrease branch, stretch reuses open-ended effort timer and manual stop; explicit white Pause override, duplicated customization cancellation toolbar, duration-only load picker remains. Behavioral regression tests added before fixes; RED run pending. No application code changed yet.


RED→GREEN: initial five scenarios reproduced missing rest, stale goal, missing decrease and stretch overrun. Above-program repetitions and delayed stop additionally failed before preserving actual reps and clamping the stop. Updated four existing test fixtures/expectations to explicitly skip the new transition rest, preserving their original persistence/timing assertions. Complete suite: 182 tests passed, including threshold 9/9.5, bodyweight lower-bound, timed lower load with unchanged configured duration, cancellation, expiry while rating and one-time stretch feedback.

Independent read-only review found two P2 issues: lower-load proposal incorrectly depended on availability of old load (4000g→3900g); test reproduced then fixed by validating the proposed lower load independently. Foreground reload after stretch expiry failed to invalidate existing history projections; revision now advances on that path. Snapshot publication also guards both state generations. Declined physical UI/audio/suspension tests remain device recipes; app controls while rating are not newly introduced, but the system rest Activity supports pause/resume during rating. Native toolbar confirmation labels now explicitly use black SF symbols.

Checks so far: 182 host tests, 6 metadata, strict Swift lint and real xtool build succeed. Preflight confirms installed 1.0.0 (49), same effective identity, current cached certificate and valid app/widget profiles, no App Group or push. Version configured 1.0.1 (50), no new permissions/capabilities. Final metadata embedding/bundle inspection and USB installation pending. No commit, push, tag or Release performed.

Known limits: mixed/unavailable actual loads do not automatically overwrite baseline goals; decrease suggestions can still choose an available lighter load when the old uniform load is absent. Background stretch state is reconciled to the exact deadline on resume, but no new notification/Live Activity schedules a stretch sound during suspension. Foreground uses the existing rest completion WAV/haptic service. Multi-side holds each require an explicit start.


Delivery complete locally: final SwiftUI build succeeded (22.94 s), App Intents metadata generated for app/widget, embedding build succeeded (2.32 s), and unsigned bundle inspection passed for 1.0.1 (50), same configured IDs, arm64/iOS26, required resources and no unexpected profile/capability. USB device-run.sh exited 0 after installation/verification. Postflight confirms Sport1.0.1(50), same effective app identity and exact cached certificate, valid signed app/widget profiles and no App Group/push entitlement. Git HEAD remains c9080d3; no commit/push/tag/Release performed. Stop for physical user feedback before GitHub publication.

Device review: transition rest while rating and after submitting Feeling, pause/resume/skip from app and Live Activity; future goal after a complete workout and explicit lower-load proposal for 9.5/10; automatic stretch remaining-time/sound, resume after its deadline and chart refresh; black Pause and filled confirmation glyphs; Customize native back only; timed charts all loads and stable switching. Background stretch sound is not guaranteed by this implementation.


Publication autorisée par le retour utilisateur « cb push » après installation. Acceptation globale de la build, sans prétendre que chaque scénario individuel a été rapporté. Préparation de la Release locale 1.0.1 ; pas de fichier SHA256SUMS conformément au choix utilisateur. Préserver commits/releases antérieurs, push normal uniquement.

Vérification de publication : script release-local exécuté avec succès, 182 tests hôte/6 metadata/lint, build Release optimisé (58,53 s), extraction et intégration des métadonnées, inspection app/widget et IPA non signée réussies. Fichier dist/Sport-1.0.1.ipa prêt ; aucun fichier checksum généré. Publication du tag v1.0.1 et téléchargement de contrôle à terminer.
