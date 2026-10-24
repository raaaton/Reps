<img src="https://github.com/user-attachments/assets/592e7645-aa5b-4b73-a24c-8ea2925e3516" />


<p align="center">
  <img alt="release" src="https://img.shields.io/github/v/release/raaaton/Sport" />
  <img alt="stars" src="https://img.shields.io/github/stars/raaaton/Sport" />
  <img alt="forks" src="https://img.shields.io/github/forks/raaaton/Sport" />
  <img alt="issues" src="https://img.shields.io/github/issues/raaaton/Sport" />
</p>

# Sport

**Sport** is a native, local-first iPhone workout app built for focused training, clear progression, and full ownership of your data.

It is written with **SwiftUI**, **SQLite**, and Apple system APIs. There is no account, backend, analytics, advertising, or in-app runtime network dependency.

Plan your workouts, prepare your added weight, follow each set, rest with Dynamic Island, and review your progress — all offline.

---

## Download

The latest published IPA is available from [Releases](https://github.com/raaaton/Sport/releases/latest). The current 1.2.5 update is awaiting iPhone feedback; its IPA has not been released.

Public IPAs are built locally on Linux in **Release** configuration and distributed **unsigned**. Sign the IPA with your own Apple account and a compatible sideloading tool before installing it. Downloading the file alone does not install the app. No personal development certificate or provisioning profile is included.

Requires **iOS 26.0 or later** on iPhone. Dynamic Island appears on supported devices; rest activities also work on the Lock Screen.

Each release provides the IPA directly. See [building and distribution](docs/BUILD.md) for the exact workflow.

---

## Features

### Plan and prepare

- Create and edit workouts, choose their day, and order exercises.
- Set the number of sets per exercise in each workout, such as two push-up sets on Tuesday and four on Saturday, using a compact menu or custom input.
- Track repetitions or timed holds, including free-duration exercises.
- Set precise repetition and added-weight goals.
- Exercise edits update future goals automatically; unavailable weight compositions still require review.
- Progress shows each exercise’s main workout goal, selected by its total target volume.
- Edit timed goals directly, including switching between a duration and untimed holds.
- Manage a weighted backpack and its available load combinations.
- Review your goals and the actual items needed before starting.

### Train with a clear flow

- One warm-up movement derived from the first working exercise.
- A full-target bodyweight warm-up for weighted goals, or two half-target sets for bodyweight goals.
- Half rest between warm-up sets, followed by full rest before working sets.
- A cancellable 3–2–1 countdown for timed holds.
- Record completed repetitions, duration to the nearest tenth of a second, added weight, and exercise effort (Feeling).
- Correct a recorded set without restarting the rest timer.
- Resume a workout after leaving the app.
- Finish with one timed stretch movement, selected in preparation; each hold stops automatically at its target duration.
- Turn **Stretching** off in **Settings → Training** to skip stretches in every new workout while keeping warm-ups.
- See the real total workout time, including rest and stretching.

### Rest without watching the app

- Persistent rest deadlines between sets and between exercises, with pause, resume, and skip.
- Live Activities on the Lock Screen and Dynamic Island.
- Pause and resume directly from the activity.
- Native minutes/seconds rest picker with 30-second increments.
- Optional 🏋️‍♂️ workout and 📸 monthly photo reminders, with a test notification in Settings.
- A weekly body-weight reminder with a chosen day and time; recording that day’s weight removes its reminder.

### Understand your progress

- Workout and exercise history, with manual entry and corrections.
- Body-weight tracking in kg: one measurement per day, editable history, and a date-based chart.
- Renaming a recorded workout preserves its explicit load decision.
- Shared 3-month, 6-month, and 1-year chart periods.
- Connected charts for average volume, repetitions and work time per set, plus maximum added weight.
- Drag on charts to inspect individual session totals and set counts.
- Period totals, including total isometric work time, and a GitHub-style activity grid from the first completed workout or progress-photo date.
- Neutral filler cells, crosses for missed scheduled workouts and camera icons on progress-photo days, without a legend. Missed days use the current enabled schedule and exclude today; photos do not count as completed workouts.
- Explicit next-session suggestions based on completed sets, your goals, effort, and available weight.
- Review added-weight increases or decreases directly when moving to the next exercise or stretching.
- Choose **Update Goal** or **Keep Current Goal** for load changes; an explicitly chosen different load keeps its associated targets.
- At completion, future goals follow the latest session containing that exercise across all workouts, including actual per-set hold durations. Each workout keeps its set count. Targets use the ceiling-average repetitions or seconds at the highest load actually used in that session. At the same load, recorded performance refreshes the target even when a load increase is declined.
- Warm-up and stretch results remain separate from working-set progression.

### Learn calisthenics skills

- Follow Handstand, L-sit, Planche and Front Lever roadmaps, including optional advanced goals.
- Read offline instructions and open optional demonstration sources in your browser.
- Create your own skills and steps, or duplicate a built-in roadmap.
- Add independent skill blocks to each workout, before strength by default or afterward.
- Practice independently with free practice, timed holds or repetitions; pause and resume saved activity.
- Record attempts, optional notes and declared best holds separately from strength statistics.
- Choose your current step and mark first success or consistent performance yourself.
- Preserve skill configuration, results and active state in JSON backups; CSV replacement keeps skill practices.

### Keep photos private

- A Face ID-protected progress-photo vault.
- Encrypted originals and thumbnails using CryptoKit AES-GCM.
- Immediate locking when leaving the vault or backgrounding the app, with its preview covered.
- Photo dates and counts remain visible in Progress while images stay locked. Older photo days appear after the next normal vault unlock.
- Date-based photo stacks: Front Relaxed, Front Flexed, Back, and Other.
- Compare matching poses, zoom, and switch between comparison photos.
- Explicit photo export and confirmed deletion.

The vault uses a device-bound key protected by the current biometric enrollment. It is not a portable photo backup. Training exports contain **no private photos or vault key**. See [security](docs/SECURITY.md).

### Own your training data

- **Import from Files** and **Export to Files**. Export directly saves one JSON file containing current training data and settings, without format choices.
- The JSON archive includes calisthenics skills, personal roadmaps, practice results and resumable active state, alongside workouts, working sets, historical goals, warm-up/stretch results, catalogue, schedule, inventory, goals, body-weight measurements and training settings. Legacy CSV import remains supported.
- CSV import replaces training history after preview and confirmation, preserving your configuration.
- JSON restore replaces training data and settings after preview and confirmation.

---

## Privacy by design

- No account or server.
- No analytics, advertising, tracking, or cloud database.
- No application network requests.
- No third-party runtime SDKs.
- Local SQLite storage with transactional migrations.
- Explicit camera, Face ID, and photo-export permissions.
- Private photos excluded from training transfers and system backups.

Sport itself does not upload your data or contact a server. Training data may be included in iOS device backups according to your system settings; the private vault is explicitly excluded. Exports and saving a photo to Photos are user-controlled. The source repository and release IPAs contain no on-device history, private photos, signing keys, or personal provisioning profiles.

---

## Design

Sport favors native iOS components, familiar navigation, system typography, SF Symbols, restrained haptics, and useful animations.

Its visual identity uses **Icy Cyan `#4DD9E8`** with neutral system surfaces. The layered `.icon` app icon gives iOS the foreground shapes and material settings needed for native depth and glass rendering.

The interface is currently **English**. Exercise names and other personal content are preserved as entered.

---

## Technology

| | |
| --- | --- |
| UI | SwiftUI |
| Persistence | SQLite |
| Language | Swift 6.4 |
| Build system | Swift Package Manager + xtool on Linux |
| Minimum OS | iOS 26.0 |
| Rest activities | ActivityKit, WidgetKit, App Intents |
| Photo protection | CryptoKit, Keychain, LocalAuthentication |
| App icon | Layered `.icon`, compiled locally |
| Runtime package dependencies | None |
| Backend / application network access | None |

## Build from source

The development workflow uses Linux and an already-configured Swift Apple SDK and xtool installation. No macOS build runner or Xcode project is required.

```sh
git clone https://github.com/raaaton/Sport.git
cd Sport
bash scripts/release-local.sh
```

The script produces a verified, unsigned IPA in `dist/`, named with the version from the app plist. It does not sign, install, or upload anything.

The icon and App Intents metadata steps use the configured Linux tools described in [BUILD.md](docs/BUILD.md). An Apple SDK is required but is not redistributed here.

---

## Testing and validation

The current suite contains **334 host tests** for the real Swift domain and SQLite code, plus **9 metadata and Skills style checks**. Builds and package inspections also check the real app and widget.

The tests exercise scenarios such as reopening saved data, migrations, rollback, duplicate actions, stale commands, paused rest timers, malformed imports, and workout transitions. Assertions compare the results of those scenarios with the required behavior.

These checks do **not** run SwiftUI or prove Face ID, notifications, haptics, or Live Activity rendering on an iPhone. Physical-device testing is still required. See [TESTING.md](docs/TESTING.md) for examples and current limits.

## Project structure

```text
Sources/
├── Sport/                 # App, native views and platform services
├── SportCore/             # Domain, SQLite and transitions
├── SportLiveSupport/      # Shared activity state and adapters
├── SportRestWidget/       # WidgetKit extension
└── CSQLite/               # System SQLite module
Resources/SportIcon.icon/  # Editable vector icon layers
Tests/Host/                # Linux domain and persistence tests
Tests/Metadata/            # App Intents metadata regression tests
scripts/                   # Local build, metadata and release verification
```

## Contributing

Issues are welcome. This remains a personal app; there is no commitment to a public support schedule.

## License

See [LICENSE](LICENSE). The app icon adapts a [Phosphor](https://github.com/phosphor-icons/core) silhouette; its MIT notice is retained in [Resources/IconSources](Resources/IconSources) and included in the app.

---

<p align="center"><strong>Sport</strong><br />Native. Offline. Focused.</p>
