# Sport — Product Specification

> Native implementation decision, 11 October 2026: Swift/SwiftUI + Swift Package Manager + xtool on Linux, no Expo/React Native/JavaScript/macOS build service. This document describes the target product, not shipped features. See README.md and docs/ROADMAP.md for current implementation and physical-device validation. The interface must feel as familiar, restrained and coherent as a first-party Apple app; verify that experience on iPhone at every milestone.

## 1. Product

Sport is a private personal iOS workout tracker designed around a simple home bodyweight/weighted training routine.

The application replaces a collection of Apple Reminders, Notes, Numbers and Shortcuts workflows with one coherent application.

The application is personal, local-first and offline-first.

## 2. Goals

The application must allow the user to:

* see the planned workout for today
* start and complete a workout
* record sets, repetitions and timed exercises
* use a rest timer
* record added weight
* record perceived effort from 0 to 10
* review historical performances
* manage the user's available weighted objects
* follow a weekly workout schedule
* securely store private monthly progress photos
* receive workout and photo reminders
* optionally expose useful actions to Apple Shortcuts

## 3. Initial workout schedule

Tuesday:

* Legs

Saturday:

* Push

Sunday:

* Pull + Abs

Monthly:

* Progress photos on the first day of the month

The schedule must be editable. Each session can be moved to another free weekday, disabled, renamed, and composed from the active exercise list in a chosen order. A weekday can contain at most one session in the current model. Sessions can be added with the native top-right + button on a free day, and deleted through a trailing swipe or context menu after confirmation. Deleting a schedule entry preserves its exercise catalogue and any historical workout snapshots.

## 4. Initial exercises

* Bulgarians
* Push-ups
* Pike Push-ups
* Chin-ups
* L-sit

Exercises must be editable in Settings.

Exercises can be added and deleted in Settings. A trailing swipe or long-press context menu offers confirmed deletion. The confirmation names affected sessions; deletion removes their assignment and disables any session left without an active exercise. Other exercise order and configuration remain intact. Historical workout snapshots must remain independent of catalogue deletion when workout history is implemented.

## 5. Exercise tracking

An exercise may use one of two primary tracking modes:

### Repetition based

Example:
4 × 8–12

### Time based

Example:
L-sit — duration per set

The UI should adapt to the tracking type.

## 6. Performance record

A completed set may contain:

* repetitions
* duration
* added weight
* perceived effort

A completed exercise contains its ordered sets.

A completed workout contains its ordered exercises.

The application must preserve workout history after restart.

History supports a native top-right + for manual recording of an already performed session (name, past or current date, catalogue exercises, actual sets, repetitions or seconds, added weight and an explicitly entered exercise-level Feeling). Manual entries are independent of the current weekly schedule and never start a timer or replace the active workout. A trailing swipe or long-press context menu offers confirmed deletion of completed/cancelled sessions only. Deletion preserves configuration and other workouts. Editing an existing historical performance and filtering remain later milestones.

## 7. Rest timer

Default rest duration:

3 minutes.

The timer must support:

* start
* pause
* resume
* skip

`Passer le repos` ends the current rest and immediately presents the next set. Cancelling the whole workout is a separate confirmed action and does not remove already recorded sets.

When the timer ends:

* play completion feedback
* provide haptic feedback where available
* move the workout flow forward when appropriate

The user must be able to modify the default rest duration.

The running timer is derived from a persisted absolute deadline; pause stores the remaining duration and resume establishes a new deadline. On iOS 26 or later, a rest appears as coordinated Live Activities on the Lock Screen and Dynamic Island: one shows the live countdown, and a second is scheduled locally to announce completion at the saved deadline. Both read the workout's persisted state; neither owns a second timer. This is local-only and uses no Live Activity push notifications or server.

## 8. Added weight

The fixed base backpack weighs 3.0 kg. It is added exactly once to each weighted load. Bodyweight is a separate 0 kg option. Initial one-unit items:

* La rivière à l'envers — 0.9 kg
* 1200 voitures — 2.1 kg
* 2 livres programmation — 1.5 kg

The application must allow the user to create, rename, change the weight of, enable, disable and delete weight items.

The application must calculate unique combinations of active items using integer grams, and sort available loads in ascending order. When progression recommends an increase, the next goal is the smallest available load strictly above the greatest load recorded in the previous performance. If none exists, do not invent a value and explain that no heavier combination is available.

Store each selected load and a snapshot of its component names and weights with the workout set. Inventory changes affect future combinations only; historical loads and snapshots must not be recalculated.

## 9. History

History must be filterable by exercise.

Each performance should display:

* date
* sets
* repetitions or time
* added weight
* perceived effort

The exercise history should make progression easy to understand without requiring a spreadsheet.

## 10. Progress photos

Progress photos are private.

The app must provide a dedicated Progress section protected by Face ID.

The photo vault must:

* require biometric authentication to unlock
* encrypt stored photo data
* keep encryption keys outside normal application storage
* clear decrypted photo state when the vault locks
* avoid exposing images through notifications or logs

The vault stores an encrypted original and encrypted thumbnail in Sport's private container. Its random AES-256 key is held in biometric-protected Keychain storage for the current biometric set and this device only. The private-photo destination within Progress remains locked until an explicit Face ID unlock. User decision, 13 October: lock immediately when leaving the vault or entering background; mask the vault preview as the app becomes inactive. No 1- or 5-minute unlocked background session. The public training screens have no privacy overlay. Sport creates thumbnails and previews in memory and stores encrypted BLOBs in an independent SQLite database. PhotosPicker provider copies remain system-managed; any received camera temporary owned by Sport is removed without deleting an external original.

The user can import from Photos or camera, select a progression date, view and delete a private copy, and explicitly create an unprotected copy in Photos. Export always requires a confirmation and add-only Photos permission. Settings provides Face ID availability, confirmed delete-all, and an explicit destructive vault reset for cases where biometric changes make the existing key inaccessible. Sport never replaces a lost vault key automatically.

Photos imported into the vault are separate from the normal Photos library.

Exporting a vault photo back to the Photos library is an explicit user action.

## 11. Security model

The application uses:

* AES-GCM encryption for vault image data
* a random per-installation or vault encryption key
* Keychain protected by biometric authentication using native Apple APIs
* local app sandbox storage
* iOS file protection where appropriate

The app must fail closed when the vault key cannot be authenticated.

Changing enrolled biometrics may invalidate the protected key. The application must handle this case without silently weakening security.

## 12. Notifications

The app schedules opt-in local notifications on this device for:

* workout sessions
* monthly progress photos

Notification content must never contain private progress-photo information.

Workout reminders are derived from active weekly schedule entries. Each session stores its own optional reminder time to the minute; an unset time creates no reminder, and no time is invented. The app schedules concrete occurrences 28 days ahead and omits any schedule date with an existing workout row, including an active workout, so starting a session suppresses that day's reminder. Changes to notification preferences, schedule, app foreground state, or workout lifecycle trigger a full resynchronization of requests managed by Sport.

Photo reminders occur on the first day of each month at 06:00 by default, with an editable hour. Notification permission is requested only when the user enables a reminder. A denied iOS permission is not repeatedly requested; Settings explains how to open iOS Settings instead. Notification taps open Today or Progress, never a private photo. While Sport is foregrounded, local reminders may appear as a banner and in Notification Center without sound or badge.

## 13. Apple integrations

### Reminders

Optional synchronization/export only.

The internal workout schedule remains independent from Apple Reminders.

### Shortcuts

Expose useful actions through App Intents where practical.

### Live Activities

The rest timer uses a countdown Live Activity and a locally scheduled completion Live Activity on iOS 26 or later. The countdown shows the exercise, next set, and system-rendered timer; Pause and Resume update the persisted timer and reschedule its completion. Skip, pause, and other early endings cancel the pending completion. At the saved deadline, ActivityKit starts the completion activity with an alert configuration so iOS can present the expanded “Repos terminé” state while Sport is suspended. Sport still reconciles the countdown against SQLite on launch and foregrounding. No remote push token, backend, or Live Activity push notification is enabled.

## 14. Navigation

Primary navigation:

* Today
* History
* Progress
* Settings

Navigation should use native iOS patterns wherever possible.

## 15. Offline behavior

Core application features must work without internet access.

No online account is required.

No remote server is required.

## 16. Data export

The planned native milestone 10 provides a versioned, restorable Sport backup through Files, covering training data, snapshots, configuration, adopted objectives and the future vault media. Private media require a portable encrypted archive format validated after the vault exists; never export the biometric Keychain key or silently replace inaccessible keys. Import previews and validates data before a confirmed restoration, preserving a backup of the previous state. Merge policy, active-workout recovery and external legacy-app formats must be specified before implementation.

CSV is a separate readable export for Numbers, not a complete backup. Numbers is not a dependency. These are planned features, not available in the installed build.

## 17. Non-goals

The application is not intended to be:

* a social network
* a coaching service
* an AI personal trainer
* a calorie tracker
* a nutrition tracker
* a subscription product
* a cloud-dependent service
* a multi-user application

Do not add these features unless explicitly requested.

## 18. Product quality

The final product should feel like a first-party Apple iOS application, with native SwiftUI navigation, controls, system typography, SF Symbols, adaptive colors and platform interactions.

Visual quality, animation quality, responsiveness, spacing and interaction feedback are first-class requirements.

Correctness and privacy are more important than feature count.

## 19. Decisions for the native implementation

The historical focus-cover removal plan contradicts section 10's immediate background-preview masking requirement. Decide the vault-only preview protection before implementing the photo vault; do not silently restore an app-wide blocking cover or claim screenshot privacy without device testing. Native milestone 1 does not contain a vault.

Detailed workout/progression plans use one decimal Feeling per exercise, while section 6 permits per-set effort. The accepted native plan selects exercise-level Feeling. Initial repetition targets are provisionally four sets of 8–12; L-sit has four sets without an invented duration target, with editing in milestone 2.

## 20. Native refinement accepted on 11 October 2026

Apple Human Interface Guidelines are the ongoing design reference. Each newly started timed set has a three-second preparation countdown; elapsed performance starts after it, with cancellation available before the scheduled start. Persist the scheduled start so closing, backgrounding or relaunching does not restart or add preparation to the performance. Repetition sets and manual historical entries have no countdown. Existing already-running sets retain their recorded start. Feedback and rendering require physical iPhone validation.

Timed-set weight is entered before starting, captured with the scheduled start, and displayed read-only during the effort. Finish saves the captured weight and measured duration. Already-running sets from older builds without captured weight stop first and request weight afterward; the persisted stop excludes entry time from performance and starts rest at the end of the effort. Both pending weight and stopped state survive relaunch.


## 21. Roadmap additions agreed on 12 October 2026

The user requests two distinct future milestones: Progression after current milestone 6, then Animations/haptics after Progression and the vault. The remaining order is7 Progression,8 Vault(previous 7),9 Animations/haptics,10 Backup/final polish(previous 8). Planning approval does not start implementation or validate the pending milestone 6 iPhone tests.

Milestone7 includes a precise, editable next-workout objective; adopting a suggested load explicitly persists it for future workouts. For repetition goals, all required sets must reach the current maximum and Feeling must be strictly below 8 before suggesting the smallest available load above the heaviest actually used. Four sets reaching 12 satisfies the initial 4×8–12 goal; missing/cancelled performances do not manufacture a suggestion. Milestone7 replaces the earlier ≤ 7 rule with <8. New numerical Feeling input uses 0.5 increments; preserve older decimal ratings exactly, with no retroactive rounding or descriptive qualifiers. User decision for timed exercises: preserve the configured duration and manually chosen load, with no automatic increase. Actual recorded durations remain available in charts.

Other confirmed scope: minimal input with chosen load and previous performance visible, backpack preparation from actual component snapshots, correcting a recorded set during the workout without restarting rest or changing original timestamps, factual completion summary, exercise charts with comparable metrics, and a GitHub-style attendance grid with completed/partial/neutral days. Do not infer missed historical workouts from the current mutable schedule. Total elapsed workout duration is measured from launch to final completion including rests, entry, pauses and background time; manual entries without real chronology do not get invented durations.

Progression becomes a public training overview with a distinct protected photo-vault destination in milestone 8. This changes the formerly gallery-only tab organization; all vault privacy requirements remain, with locking when leaving the vault and background behavior settled before its prototype. Statistics never authenticate or reveal photos. Maintain four native tabs.

Rejected: technical notes, shortened workout variants, and Feeling descriptors. Maintaining/resuming objectives remains a possible future option, not mandatory milestone 7 scope. No automatic coaching, fatigue diagnosis, stagnation intervention or invented performance metric is approved.

Milestone9 harmonizes system navigation, discrete content-state transitions and haptics after the screens stabilize. Prefer brief, purposeful, interruptible feedback, no per-second timer animation, gratuitous cascades or fabricated counting-up results. Haptics follow real events, existing countdown/rest feedback is preserved without duplication, added feedback can be disabled, and Reduce Motion/VoiceOver/system preferences remain effective. Animation never delays persistence or vault locking. Native APIs and physical iPhone validation are required; no background haptic delivery is promised without verification.

## 22. Training transfer advanced at the user request

12 October: implement import/export now to test Progression, with a large fictional CSV. CSV must exclude private photos and state that exclusion during export. This adds a testing/data-transfer extension to milestone7, without validating its iPhone recipe or starting the vault/animations. CSV append preserves existing training/configuration; versioned JSON restores training only after explicit confirmation and preserves an exportable previous dataset transactionally. Private vault media and biometric keys remain excluded from these formats, pending a distinct encrypted archive design after the vault exists. Active workouts block transfer; old rest timers and iOS permissions are never restored. See docs/CSV-FORMAT.md and the transfer ExecPlan for limits and the actual verification state.

## 23. Session charts correction after device feedback

User finds the per-set scatter plots confusing and requests connected curves and useful interpretation. Replace the main charts with one actual value per completed session: total repetitions or duration at one uniform load, maximum added load separately. Filter comparison contexts by actual/configured set counts, archived target range/duration and recorded rest; manual rest is unknown. No mixing of loads into a strength score. Latest result, neutral arithmetic change and session count visible, details available without scrubbing. Use chronological session sequence with evenly spaced index axis, explicit labels and real dates; two sessions on one date remain distinct. No smoothing that invents results, no change to coaching/goals/data/transfer/privacy. Correct this milestone before vault/animations. iPhone verification remains mandatory.

## 24. Chart selection and session volume, 12 October 2026

User requests date/value beside the selected point during dragging, retaining the detailed selected-session section. Native Charts annotation with overflow fitting, actual saved date/value, no interpolated result. The large summary is explicitly the latest workout; period totals are not confused with per-workout results. It stays still during dragging to avoid moving the plot under the finger.

Repetition exercises default to added-load volume per exercise/workout: sum(repetitions × actual added weight) across all recorded sets, including mixed loads. 48 repetitions at6kg =288kg; gram precision is preserved. Body mass is unknown and excluded, so0kg of added volume is not zero exercise. No claim this is a superior strength indicator; Repetitions at fixed load and maximum load remain available. Static exercises default to total actual work duration per workout across all loads, with an optional uniform-load filter; no rest or invented time×load metric. Archived conditions and separate manual unknown rest remain; no goals, data format or storage changes. This corrects the same milestone7, requiring device feedback before8/9.

## 25. Cumulative volume and CSV replacement, clarified by the user

User explicitly chooses cumulative volume over the selected period only (1/3/12months), not lifetime. Sum all eligible completed sessions of the exercise in that period, across recorded load/rest/set/target changes. Each point is the running cumulative balance since that period starts. Summary is the period's total, selected detail distinguishes cumulative balance from that workout's contribution. No context selector for Volume, so totals are not silently reduced by a comparison context. Repetitions/time/max-load charts stay as before; bodyweight excluded, no strength inference.

User explicitly confirms CSV replaces the entire history and preserves planning/catalogue/inventory/goals/preferences. CSV preview shows incoming and existing counts, centered destructive confirmation, cancel without mutation; no append/merge. Different content under an old ID replaces that record; invalid duplicated IDs inside the file remain rejected. Backup before import, deletion and insertion are one transaction with rollback and stale/active guards. Identical dataset is a no-op preserving previous recovery. Valid empty CSV can clear history only through that same explicit confirmation. JSON full training restoration remains distinct. No agent executes import on personal device, no new capability or schema/format. Correction of milestone7, phone validation still required before8/9.

## 26. Period summaries and individual-session charts

User confirms0.7.4 then corrects the presentation: keep total volume on selected period in the large summary, but display only session volume in the curve and its drag annotation. Repetition summary must be the total while its curve remains repetitions per session. This supersedes the cumulative-curve mapping of section25; CSV replacement remains unchanged. Volume includes all completed sessions in the period. Repetition total follows the same selected load/context and period as the displayed sessions, as announced; no silent graph/filter change. Units/titles and selected detail distinguish totals from session results, with no cumulative-balance line in the selected detail.

Calculate integer sums with checked overflow and cache repetition totals by comparison context; selecting a point does not sum all sessions again. Volume summary uses its period aggregate only, while point/date/annotation/VoiceOver/detail use raw saved session results. No storage, transfer, goal, native capability, animation or haptic change. The known empty-state wording is corrected for Volume. Verify build/installation and wait for physical confirmation before milestones8/9.


## 27. Motion and haptics advanced, 13 October 2026

The user explicitly requests milestone 9 now, before the vault. Apply its previously agreed scope to existing screens. Use discrete native content transitions and optional foreground feedback after persisted state changes; no animation on each live timer tick, no delayed writes, no replay on passive reads. Keep system controls/navigation intact. The local haptics preference applies to Sport-authored feedback, including countdown/rest, and is separate from iOS alerts/sounds and training CSV/JSON. Vault-specific motion/privacy checks remain future work.


## Correction des transitions graphiques — 0.9.1

Retour iPhone du 13 octobre : transitions de période/mesure buggées. Retrait du ressort sur toute la liste ; seul le nouveau graphique apparaît en fondu easeOut de 0,15 s, avec identité propre à la requête. Axes/tracé mis à jour directement, aucune interpolation entre unités ni animation de hauteur des sections. Pickers natifs, valeurs et haptics conservés ; Reduce Motion/VoiceOver désactivent le fondu. [ExecPlan](docs/exec-plans/2026-10-13-chart-filter-motion.md).


### Chargement stable des graphiques — 0.9.2

Correction après retour iPhone : conserver les résultats et leur mesure/période pendant toute actualisation. Le bloc au-dessus de Prochaine séance ne disparaît plus pendant la requête ; les nouveaux résultats/libellés/contexte/sélection sont publiés ensemble. Indicateur en overlay sans ligne supplémentaire ; erreurs gardent le dernier résultat et proposent Réessayer. Réponses périmées/annulées refusées. Le premier chargement et les véritables états vides restent explicites. Calculs, données, haptics et bref fondu conservés ; rendu à confirmer après installation.


### Répétitions compactes — 0.9.3

Tous les tableaux d’objectifs utilisent la même notation : 10·10·10·10 devient4×10, 10·10·9·9 devient2×10 2×9. Seules les valeurs identiques adjacentes sont regroupées pour préserver l’ordre. Objectifs configurés :4×10 ou4×8–12. La vue partagée couvre Aujourd’hui, préparation, séance, propositions/prochaine séance et bilan ; détail et saisie par série restent accessibles, sans fusionner charges/compositions. VoiceOver explicite les groupes d’objectifs. Aucun stockage/format/algorithme de progression modifié. Rendu à confirmer sur iPhone.


## Vault comparison and goal clarity — 13 October

Sport0.10.0 confirmed working by the user. Follow-up presentation explicitly approved: one photo stack per progression day, poses Front relaxed / Front flexed / Back, comparison of two photos of the same pose on different dates. Every photo remains preserved, including duplicates and old unclassified photos; pose is optional for existing encrypted metadata and assigned explicitly through Edit. New imports/camera captures choose a pose, suggesting the next missing pose for the selected date. Comparison renders bounded previews side by side, uses the vault session/lease/cancellation guards, clears decrypted references on lock/dismiss and masks every new private surface. No key, permission, SQLite schema, notification or archive change.

Reset uses a red arrow.counterclockwise SF Symbol with its destructive confirmation. Training rows show one concrete compact goal and disclose details; the program range appears in the goal overview instead of duplicating the target. Goal overview shows current target and a different suggestion if available; manual load/per-set editing is a separate Personalize screen. Existing thresholds, transaction/stale guards and explicit adoption remain unchanged. Version0.10.1; physical review required before the next milestone.


Photo comparison follow-up: touching either image opens it full screen; pinch and pan to inspect details, tap to alternate the same two images with shared zoom/scroll geometry. Accessible alternate/zoom controls remain available. Return preserves selected dates and pose; the new surface remains inside the locked/masked vault and reuses centrally held previews only. Version0.10.2; no change to source photos or automatic body alignment.


Follow-up0.10.3: long-press date stacks and individual photos to delete with a centered destructive confirmation. Batch deletion is atomic, scoped to captured vault IDs and current session, preserving other dates, the key marker, Photos originals and training data. Context-menu previews are neutral and contain no photo/date. Reported top-left zoom in0.10.2 is replaced by native UIScrollView pinch/pan inside the SwiftUI viewer, preserving its common canvas on image swaps; UIImage is cleared when dismantled. Device confirmation remains required.


Follow-up0.10.4: archived exercises also appear in Settings. User explicitly chooses permanent deletion of their past performances via swipe/context menu and centered confirmation. Preserve other exercise snapshots and chronological fields; remove workouts made wholly empty, announced before confirmation. Refuse purge for a live snapshot or exercise restored to the catalogue. Catalogue deletion still archives history. Attendance list omits neutral days, not partial training; Settings label/title becomes Séance and Today Prepare spans the same section width as the rest row.

User reports top-left zoom in both0.10.3 photo screens. Both now use the same fixed GeometryReader/native scroll; no zoom/offset setters during UIKit layoutSubviews. This remains a physical verification item, not claimed fixed from compilation. No vault key/permission/storage-format changes.


Retouche autorisée du13octobre : catégorie Réglages → Séances (pluriel), icône Play blanche sur Préparer. Suppressions catalogue/archive conservent leurs règles distinctes ; le crash de mise à jour des listes est traité sans changer ces données ou règles.


13 octobre — l’utilisateur choisit « Interface en anglais + SF Symbols d’abord » pour le jalon10A. Anglais pour tous textes applicatifs, notifications, Live Activities, explications de permissions et accessibilité. Conserver les noms personnels, identifiants et formats. Coche/crayon/fermeture pour commandes usuelles de toolbar, libellés conservés dans confirmations/menus et actions ambiguës. Sauvegarde portable privée reste un sous-jalon ultérieur à cadrer ; aucun nouveau transfert du coffre.


10A accepté après0.11.0 ;10B vérifie uniquement le transport/chiffrement natif d’un échantillon .sporttest, sans lire ni écrire l’entraînement/coffre. API CommonCrypto/CryptoKit compilées, runtime sur iPhone requis avant10C (backup complet, réchiffrement privé sous clé locale et restauration atomique à cadrer). Ne pas présenter cette preuve comme un export de photos ou une sauvegarde personnelle disponible.


13 octobre, correction explicite après0.11.1 : abandonner l’écran de preuve et limiter Import and Export à deux actions, Import from Files / Export to Files. Formats publics CSV et JSON conservés ; choix et récupération avant import regroupés dans Export. Exclusion des photos annoncée, preview/confirmation avant remplacement conservés. Aucune poursuite implicite de la sauvegarde privée portable après rejet de cette preuve.


## Addition — warm-up and stretching (15 October 2026)

One warm-up movement per workout, derived solely from the first working exercise and its first-set goal frozen at launch. Weighted goal: one bodyweight set at the full repetition/time target. Bodyweight goal: two half-target sets with half rest between them. Always full rest after the warm-up. Odd repetitions round down (minimum one); duration and rest halves preserve milliseconds; a free-duration target stays free. One timed stretch movement after the working sets, using the existing cancellable countdown and elapsed timer. Defaults are 30 seconds per hold, per side for unilateral movements, with movement/duration selectable in preparation. Completion and total workout elapsed time include this final stage. Persist auxiliary targets/results separately from working sets; keep them out of performance charts and progression proposals, but preserve them in history and transfers. Do not retrofit existing active or historical workouts.


## 28. Workout refinements approved 17 October 2026

A full configured rest starts after the last set of a working exercise if another exercise follows. Feeling can be entered while it runs and does not restart it. The next exercise's set 1 is the Live Activity destination. After completing a live workout, future goals match its actual repetitions and uniform available load; configured timed durations are preserved. Suggestions remain explicit: Feeling strictly above 9 proposes the nearest available lighter load, without inventing a negative/bodyweight alternative. Unavailable/mixed previous loads are not silently converted into baseline goals. Stretch holds stop at their persisted target deadline, with foreground completion feedback; late reconciliation records the exact target. Ordinary timed work and free warm-up timing remain manual. Timed charts show all loads without a selector. Pause and confirmation symbols on cyan fills are black; Customize uses the native back arrow alone. User explicitly requires waiting for iPhone feedback before any GitHub push.

### October 18 follow-up — attendance and first load

User replaces partial attendance with missed-day dots: completed days stay filled; scheduled but uncompleted past days get a dot starting at the first completed workout, even outside the displayed range. Today and rest days remain neutral. Explicit request supersedes the former prohibition on inferring missed workouts: use current enabled schedules with active exercises, disclose that schedule history is unavailable. Cancelled/active workouts remain in history without a separate partial state. First weighted suggestion: complete bodyweight repetition work with Feeling strictly below8 can propose the smallest available positive load and configured minimum reps without reaching the maximum; explicit adoption required, timed exercises unchanged. Native confirmation Cancel uses neutral white dark/black light.

October18 direct load-goal consent: after a live completed workout commits its actual-result baseline, automatically show one centered confirmation listing applicable load increases/decreases from that workout. Explicit Update Goals writes the entire reviewed batch atomically for the next workout; Cancel keeps baseline. Existing management views remain available, but are not required for this adoption. No historical-browsing/cancelled popup, no new threshold or automatic timed-duration increase. Reject changed history, catalogue, inventory or original goals.

October18 correction61 supersedes end-summary placement: show load-goal confirmation immediately on tapping Next Exercise/Continue to Stretching, before committing the transition. Update Goal or Keep Current Goal resolves the exact reviewed choice and Feeling atomically. Keep retains existing goal including absence; persistent operational decision markers prevent final completion or stretching from overriding either explicit choice, also after restart. No end popup. Active workout snapshot goals stay fixed, explicit goal updates affect future workouts only.
