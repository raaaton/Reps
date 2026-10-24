# Build and distribute Sport on Linux

Sport uses Swift Package Manager and xtool. The main product is `Sport`, its embedded extension is `SportRestWidget`, and `xtool.yml` describes both bundles. There is no primary Xcode project.

## Requirements

- Linux x86-64 with Swift 6.4.
- An Apple SDK registered with xtool (the release environment uses iPhoneOS SDK 27.1).
- xtool, with the existing environment pinned to commit `f0a1f90efdbb0dc023e276ff529da92618da7a87`.
- Python 3, system SQLite, and `swift format`.
- The configured Linux `actool` and `appintentsmeta.py` tools from the local `omarchy-apple-dev` environment. The helper scripts currently resolve them beneath `~/omarchy-apple-dev/tools/`.

Apple SDKs, toolchains, credentials, and development profiles are not included in this repository. The release scripts never install or replace them.

## Verify and build an unsigned Release IPA

```sh
bash scripts/release-local.sh
```

This runs:

1. Host tests, Swift lint, and metadata regression tests.
2. Layered app-icon compilation with the installed Linux `actool`.
3. An optimized `xtool dev build --configuration release`.
4. App Intents metadata extraction from that Release compilation.
5. A second Release build to embed those metadata resources.
6. Inspection of the real unsigned app and widget.
7. IPA packaging with `xtool dev build --configuration release --ipa`.
8. IPA inspection.

Outputs:

```text
dist/Sport-<version>.ipa
```

The IPA has the standard `Payload/Sport.app` layout with its embedded WidgetKit extension. It contains no private developer certificate, provisioning profile, or user database. It must be signed by the recipient before installation; it is not an App Store or universally installable enterprise package.

The build script does not authenticate with Apple, sign, install, publish, or modify developer certificates.

## Fast local development

After the SDK and tools are already configured:

```sh
swift test --package-path Tests/Host
swift format lint --strict --recursive Package.swift Sources Tests/Host/Package.swift Tests/Host/Tests
python3 scripts/build-app-icon.py
mkdir -p .build/live-metadata/{app,widget}/Metadata.appintents
xtool dev build
python3 scripts/build-live-metadata.py
xtool dev build
python3 scripts/verify-foundation.py
python3 -m unittest discover -s Tests/Metadata -v
```

Keep `.build`, xtool, and toolchain caches for incremental builds. On a fresh checkout, create the two empty metadata directories before the first build. These bootstrap directories are replaced with real compiler-derived metadata before the second build and mandatory bundle inspection. The release script handles this automatically. Use `--configuration release` for metadata after a Release build.

## USB installation for the app owner

Signing and USB installation are separate from public IPA production:

```sh
~/omarchy-apple-dev/device-run.sh
```

This uses the existing Apple authentication, checks the connected iPhone, and runs xtool's development deployment. The configured bundle ID remains `com.raaaton.sport`; xtool may apply its existing team prefix during free provisioning. Confirm the installed identity and certificate before replacing the app.

Stop on unexpected signing/provisioning errors. Do not revoke or replace a certificate to repair a build. A successful build is not a successful device test.

## GitHub Releases

The public distribution is built locally rather than on a macOS Actions runner. After verifying the source commit and IPA, publish a versioned tag with release notes and attach only the public IPA. Do not generate or publish a separate checksum file for future releases. Never upload a development-signed IPA containing personal profiles or credentials.

After upload, download the release asset and compare its SHA-256 with the local artifact. GitHub Actions is not required to generate the current release.

## Reproducibility limits

The source and packaging steps are versioned. The SDK and configured Linux Apple tooling are external prerequisites. This is a documented local build, not a claim that a clean generic Linux host can compile iOS apps without those tools, nor a claim of byte-for-byte reproducible builds.

## Device registration conflict

If profile creation fails with Apple409 ENTITY_ERROR, “There are no current IOS devices on this team matching the provided device IDs,” first inspect authentication/team selection and `xtool ds devices list`. The installed xtool revision ignores any409 during its preliminary device registration, so a later provisioning error can mask that earlier failure. Do not infer a certificate problem or reset authentication. In the18October incident, two read-only device queries returned no devices; an isolated registration of the physically connected iPhone returned201 Created, after which normal device-run.sh provisioning/install succeeded with the existing certificate. The original reason for Apple's empty device inventory was not established. Preserve certificates and stop if the isolated request returns a new error requiring a different account operation.

October18 local1.0.3(60): full196host tests,6metadata tests, strict lint and unsigned app/widget inspection pass. xtool21.94s plus metadata packaging2.09s. Standard USB delivery, same configured/effective identities and certificate; publication pending device review.

Correction61: training schema9 additive goal-decision markers; full199host tests,6metadata tests, strict lint and unsigned61inspection succeed. xtool21.05s then metadata packaging2.05s. Same-identity USB delivery underway; no publication.

Release1.0.3(61) prepared locally: scripts/release-local.sh exits0 with199host tests,6metadata, strictlint, optimized build61.96s and unsigned IPA inspection passed. No personal profiles/signatures/data and no checksum attachment. Publication authorized by user after installed61.

Publication1.0.3 verified: public Release has onlySport-1.0.3.ipa. Downloaded asset matches local Release build byte-for-byte and passes unsigned app/widget inspection again. Tagv1.0.3 points to sourcea685dbb; later verification documentation does not change the executable.

Local1.0.4(62) :203tests métier,6metadata, strictlint, compilation xtool et inspection unsigned réussis. Time Sensitive Notifications nécessite la capacité Apple réservée ADP/ADEP (colonne gratuite vide dans https://developer.apple.com/help/account/reference/supported-capabilities-ios/ vérifiée18octobre). Aucun changement entitlement/provisioning pour cette demande ; ne pas simplement ajouter le flag en prétendant que cela fonctionne.

Release1.0.4(63) : scripts/release-local.sh code0 avec204tests métier/6metadata/strictlint, build Release local optimisé, métadonnées compilateur intégrées et IPA unsigned inspectée. Publication autorisée après réception réelle de la notification de test sur iPhone. Aucune signature/installation ni modification de certificat pour produire cet asset.

Publication1.0.4vérifiée : asset uniqueSport-1.0.4.ipa retéléchargé, identique octet pour octet et inspection unsigned réussie ; tag pointec58b94a. Le commit de compte rendu ne change pas le binaire.

Local1.0.5(64) : migration SQLite10 normalise workout_sets.duration_ms au100ms le plus proche ; triggers insert/update couvrent tous les chemins. Minimum positif100ms, aucun changement de timestamp, repos, capacités ou signature.

Release1.0.5(65) : scripts/release-local.sh code0 avec208tests métier/6metadata/strictlint, compilation xtool optimisée et métadonnées intégrées, IPA unsigned inspectée sans profil/signature/donnée utilisateur. Publication autorisée par ok push après65.

Publication1.0.5vérifiée : tagv1.0.5sur2061397, uniqueassetIPA retéléchargé identique et inspecté unsigned. Le compte rendu documentaire ne change pas le binaire.


Local1.0.6(66) : séries et objectifs par affectation de workout, schéma11 ; JSONv2 avec lecture v1.219tests métier passent, strictlint propre,6metadata et inspection unsigned réussis ; xtool initial28.77s, intégration finale15.22s. Préflight : version65 présente sous la même identité, profils CMS app/widget valides et même certificat existant valable plus de24h. Installation USB en cours ; aucune publication GitHub.

Livraison1.0.6(66) confirmée : device-run.sh code0, installation/vérification100%, postflight direct version66/identité unique inchangée/certificat exact inchangé/profils CMS app-widget valides et capacités conservées.219tests métier/6metadata/lint/build/inspection réussis. Attente du retour iPhone ; aucun push/release.

Build67 livrée : device-run.sh code0, installation/vérification100%. Postflight direct confirme un seul Sport1.0.6(67), même identité effective, certificat exact inchangé, profils CMS app/widget valides et mêmes capacités.219tests métier/6metadata/lint strict/xtool15.89s puis2.90s/inspection réussis, revue ciblée sans défaut concret. Rendu menu/Custom/grands textes/VoiceOver à confirmer sur iPhone. Aucun commit/push/release.


19 octobre — 1.1.0 (68) : Body Weight dans Progress, mesures journalières en grammes entiers, graphique Swift Charts et historique modifiable ; rappel hebdomadaire opt-in dans Notifications. Périodes partagées 3 Months / 6 Months / 1 Year sur tous les graphiques. Migration SQLite 12, archives JSON v3 ; anciens JSON/CSV conservent les pesées et leur rappel. 242 tests hôte, 6 metadata, lint strict et inspection unsigned réussis ; xtool final 51,39 s puis intégration metadata 3,95 s. Revue indépendante incluant les HIG, deux défauts corrigés et recontrôlés. Installation USB réussie (device-run.sh code 0, installation et vérification à 100 %). Postflight direct : un seul Sport 1.1.0 (68), même identité effective, certificat exact inchangé, profils CMS app/widget valides et capacités conservées. Recette visuelle et notifications sur iPhone attendue. Aucun push/release. [ExecPlan](exec-plans/2026-10-19-body-weight.md).


Build 69 — Progress affiche l'objectif exact de la séance principale pour chaque exercice, choisi selon le volume cible total. Priorité explicite aux objectifs de répétitions lestés ; à vide, somme des répétitions ; isométrique, séries × durée. Six tests de sélection observés rouges puis verts ; suite complète 248/0 échec, lint strict, 6 metadata, revue indépendante ciblée sans défaut concret, xtool 63,67 s puis intégration metadata 5,49 s et inspection unsigned réussis. Préflight : un seul Sport 1.1.0 (68), même identité effective et certificat existant encore valide. Installation USB réussie (code 0, installation/vérification à 100 %). Postflight : un seul Sport 1.1.0 (69), même identité effective et certificat exact inchangé, profils CMS app/widget valides et capacités conservées ; aucun commit/push/release. Rendu/grands textes/VoiceOver à vérifier sur iPhone.


Build70 — Une modification d'exercice acceptée adapte automatiquement les objectifs futurs de tous ses workouts ; migration13 transactionnelle des anciens objectifs désynchronisés et normalisation de l'aperçu JSON. Composition de lest conservée exactement : indisponibilité toujours à valider. Progress affiche Review needed si un objectif assigné nécessite une vérification. Séances actives/historique inchangés. 257 tests hôte/0 échec, 6 metadata, lint strict et inspection unsigned réussis ; xtool61,12 s puis intégration metadata4,90 s. Revue indépendante ciblée sans défaut concret. Préflight : version69, identité unique et certificat existant inchangés. Installation USB70 réussie (code 0, installation/vérification 100 %). Postflight : un seul Sport1.1.0(70), identité effective et certificat exact inchangés, profils CMS app/widget valides et capacités conservées. Recette physique en attente ; aucune publication GitHub. [ExecPlan](exec-plans/2026-10-19-goal-review.md).


20 October — build71: per-set chart projection and global latest-exercise goals, schema14 with once-only baseline refresh and captured load decisions; JSONv4 preserves actual per-set duration targets.270host tests/zero failures,6metadata, strictlint, xtool14.89s plus metadata embedding2.61s and unsigned inspection pass. Independent review corrections verified. Preflight: one installedSport1.1.0(70), same effective identity, exact existing certificate valid>24h and app/widget CMS profiles verified; capabilities unchanged. Authorized USB update in progress; no GitHub publication.

Build71 USB delivery confirmed: device-run.sh code0, installation/verification100%, direct postflight oneSport1.1.0(71), same effective identity/exact certificate, app/widget CMS profiles valid and capabilities identical. Physical chart/goal feedback pending; no commit/push/release.


20October build72: ceiling-average learned targets and mixed-load baseline correction, schema15one-time refresh; JSONv4 unchanged.275host tests/6metadata/strictlint, xtool28.68s + embedding2.37s, unsigned inspection and independent review pass. Preflight confirms oneSport71, same effective identity/exact cached certificate valid>24h, valid app/widget CMS profiles and normal unchanged capabilities. Authorized USB installation in progress; no GitHub publication.

Delivery blocked before installation: usbmuxd crashed withSIGABRT (`free(): invalid pointer`) while the phone remains visible inlsusb. xtool finished compilation2.39s, then waited for the device; the waiting attempt was stopped gracefully. No provisioning/signature error was reported, no certificate changed. Direct diagnostic confirms usbmuxd.service failed(core-dump); `sudo -n systemctl restart usbmuxd` returned `sudo: a password is required`. User must run `sudo systemctl restart usbmuxd`, then resume the standard USB delivery/postflight. Device last confirmedSport71; do not claim72installed.

Build72 delivery confirmed after user restartedusbmuxd: standard device-run.sh code0, installation/verification100%, oneSport1.1.0(72) under same effective identity. Exact existing certificate and app/widget CMS profiles validated, capabilities unchanged.275host tests/6metadata/lint/build/inspection/review remain the local verification evidence; physical goals/screens await user feedback. No push/release.


21 October — local1.1.0(73): global stretching preference, schema16/JSONv5. 281 host tests/zero failures, strict lint and6metadata pass; xtool16.90s then metadata embedding2.52s and unsigned app/widget inspection pass. Initial iOS compiler assertion was triggered by an unqualified error-state assignment inside catch; self.error resolves it, no toolchain change. Existing signing certificate checked locally (>24h validity) and present in Apple read-only certificate list. Installed72 identity confirmed before delivery. USB result and physical-review status recorded below.


USB delivery confirmed: device-run.sh exited0 (final rebuild7.43s), install/verification100%. Direct device postflight confirms one Sport1.1.0(73), same effective identity, exact cached signing certificate unchanged, app/widget CMS profiles valid and ordinary entitlements retained (no App Group/push). Physical toggle/flow review awaits the user; no GitHub push or release.


Build74: removed only the description beneath Stretching at the user’s request. Strict lint/6metadata, xtool10.99s+2.47s, unsigned inspection and USB install (code0, verification100%) pass. Device postflight confirms74, same identity/certificate and valid app/widget CMS profiles with retained capabilities. Physical rendering awaits user review.
## Audit corrections — build 75, 22 October 2026

290 host tests/zero failures (6.573 s), strict Swift lint, six App Intents metadata tests and actual unsigned app/widget inspection pass. Final reviewed xtool compilation 11.20 s, followed by regenerated compiler metadata and embedding. No SDK/dependency/cache reset. Preflight confirms one installed Sport 1.1.0 (74), its signer matches the existing cached certificate, valid over 24 hours. USB deployment/postflight results are recorded in `exec-plans/2026-10-22-audit-corrections.md`; compilation alone does not validate iPhone behavior.

## Selective revert — build 76

Only the three user-selected audit changes are reverted to fetched GitHub1.1.0 source behavior. Schema16/JSONv5 stay compatible; no database downgrade and no personal-data rewrite. 284 host tests/zero failures, strict lint, six metadata, real xtool22.93s and unsigned app/widget inspection pass. Delivery evidence is tracked in exec-plans/2026-10-22-selective-audit-revert.md. USB delivery now confirmed after transient lock/disconnection: device-run.sh code0, final rebuild2.40s, installation/verification100%. Direct postflight confirms one Sport1.1.0(76), unchanged identity/signer/exact certificate/entitlements and valid installed app/widget CMS profiles. Physical feedback pending; no GitHub publication.

## Skills 1.2.0 — build 78

The Skills milestone remains SwiftPM/xtool with no added dependency, entitlement or bundle identifier change. Training schema advances from16 to17 and JSON archive from5 to6. Preserve existing state and caches. Use the normal metadata regeneration, bundle inspection and device-run.sh workflow. No rollback to schema16 is part of this delivery. Device verification remains required; no public release is implied.

Delivery 23 October: Sport **1.2.0 (78)** installed successfully using `device-run.sh` after an iPhone reboot resolved two stalled transfers. Direct installed-app postflight confirms one Sport app, unchanged effective identity, signer and entitlements, and validated profile. Physical Skills interaction review is pending. Evidence: `/tmp/sport-skills-120-install-reboot.log`, `/tmp/sport-skills-120-postflight.json`. No push or public release.

## Skills follow-up — 1.2.0 (80)

328 host tests pass; nine metadata/style checks and strict Swift lint pass. Real xtool build and final bundle inspection confirm 1.2.0(80) for both app and widget. No identity/capability/dependency change. Metadata regenerated and embedded. The automatic installation reviewer initially mistook the currently installed79 preflight for the new artifact; explicit source/app/widget plist80 checks resolved the rejection, and the normal helper was then approved and completed installation/verification100%, code0. Final installed-app postflight is tracked in exec-plans/2026-10-23-skills-interface-polish.md.

## Skills Kavi flow — 1.2.0 (81)

331 host tests, nine metadata/style checks and strict lint pass. Final real xtool build completes in9.72s; bundle inspection verifies app/widget1.2.0(81). Provider PNGs are processed by the existing SwiftPM resources configuration. No dependency, schema, entitlement or identity change. The iPhone preflight reports1.2.0(80), which is intentionally updated to81. USB postflight and physical-review status are recorded in the active Skills interface ExecPlan.

USB delivery succeeds; direct postflight verifies one installed Sport1.2.0(81), unchanged identity/signer/entitlements and ProfileValidatedtrue. Physical interaction feedback is pending. Evidence: /tmp/sport-skills-kavi-followup/postflight.json.

## Version correction — 1.2.1 (82)

Latest corrective delivery receives patch1.2.1 and independent build82. App/widget source and packaged plists agree. Fresh strict lint, nine metadata/style checks, real xtool compilation and bundle inspection pass; App Intents metadata regenerated and embedded. Functional Swift sources are unchanged since the331-test build81 verification, so host domain tests were not repeated for metadata-only changes. Version policy is now recorded in AGENTS.md; major increments require explicit user approval. USB evidence: /tmp/sport-version-121/.

Installed-app postflight confirms exactly one Sport1.2.1(82), unchanged identity/signer/entitlements and validated profile. USB helper exits0. No GitHub publication.

## Skills physical corrections — 1.2.2 (83)

332 host tests/zero failures, nine metadata/style checks, strict lint, real xtool compilation (11.31s) and final app/widget inspection pass. Metadata regenerated and embedded. Neutral toolbar styling, direct UIImage provider-logo loading, original destructive-symbol ink and independent achievement statuses are corrected. Prompt now requests actual video research. App/widget/plist inspector all target1.2.2(83); installed preflight is1.2.1(82). Device delivery logs and pending ChatGPT-response reproduction are in the active Skills interface ExecPlan. Evidence folder: /tmp/sport-skills-123/.

Build83 USB delivery is pending: usbmuxd failed while the phone remained present. Restart requires the user's sudo password; user asked to restart the service. Stalled installer interrupted with SIGINT. No claim of installed83; last confirmed is1.2.1(82).

Build83 delivery resumed after the user restarted usbmuxd. Includes the ChatGPT formatting correction,334 passing host tests, nine metadata/style checks, strict lint, real build12.41s and final inspection. Direct postflight confirms one installedSport1.2.2(83), unchanged identity/signer/entitlements and validated profile. Evidence: /tmp/sport-skills-123/install-resume.log and postflight.json. Physical acceptance pending; no GitHub publication.

## Accent content labels — 1.2.3 (85)

Shared native LabelStyle scopes accent symbols to tab navigation content, preserving native tabs, standalone icons and semantic destructive/prominent contrast. Nine metadata/style checks, strict lint, actual xtool build without warnings and final app/widget inspection pass; App Intents metadata regenerated/embedded. After intermediate84, final85 places the style on enclosing NavigationStacks for pushed/modal inheritance. USB helper exits0, install/verification100%; direct inventory verifies one installed1.2.3(85), same identity/signer/entitlements and validated profile. Domain suite not repeated for a visual-only change. Physical appearance acceptance pending; no push/release. Evidence: /tmp/sport-accent-labels-84/.

## Skills native menu symbols — 1.2.4 (86)

Visual-only correction based on iPhone feedback: ordinary native Skills menu entries use original UIKit SF Symbol images precolored with adaptive accent. Existing white menu triggers and confirmed red destructive entries unchanged. Nine metadata/style checks, strict lint and real xtool build without warnings pass; metadata regenerated/embedded and app/widget1.2.4(86) bundle inspection passes. Preflight confirms1.2.3(85); USB delivery and postflight tracked in the accent-labels ExecPlan. No domain suite rerun for visual-only changes. Evidence: /tmp/sport-menu-icons-86/.

USB delivery complete: exactly one installedSport1.2.4(86), unchanged identity/signer/entitlements and validated profile. Native menu rendering awaits physical feedback. No push/release.

## Consistency photo activity — 1.2.5 (87)

345 host tests/zero failures (7.291s), strict Swift lint, nine metadata/style checks and unsigned app/widget inspection pass. Actual xtool build25.46s followed by metadata regeneration and embedding2.17s, no build warnings/errors. The restricted sandbox blocks SwiftPM's wakeup socket and xtool cache writes; necessary builds/tests run through automatic escalation with existing caches retained. Preflight confirms one installed1.2.4(86), expected effective identity and capabilities, the existing certificate valid >24h, and valid CMS-verified app/widget profiles using that certificate. Standard USB delivery/postflight tracked in the [ExecPlan](exec-plans/2026-10-24-attendance-photo-activity.md). No dependency, SDK, identity or capability change. No public IPA Release requested.

USB delivery confirmed: device-run.sh exits0; installation/verification100%. Direct postflight verifies one Sport1.2.5(87), unchanged identity/signer/entitlements/exact existing certificate and valid CMS-verified app/widget profiles. Physical calendar, Face ID and media-viewing acceptance remains pending. No public IPA Release.

## White photo-day camera — 1.2.6 (88)

User-requested white camera.fill in Consistency, including completed dates. Visual-only retouch, separate versioned commit before the streak feature. Strict lint, nine metadata/style checks, real xtool build, regenerated/embedded App Intents metadata and unsigned app/widget inspection pass. Standard USB delivery tracked in the photo-activity ExecPlan; no new domain tests or private-data access. Physical rendering remains user validation.

## Current workout streak — 1.2.7(89)

355host tests/zero failures7.604s, strict Swift lint, nine metadata/style checks, independent code review and unsigned app/widget inspection pass. Actual xtool23.94s plus metadata regeneration/embedding2.33s; no compilation warnings/errors. Source plists and inspection agree on1.2.7(89). Preflight is the directly verified installed1.2.6(88), same effective identity/signer/exact cached certificate/capabilities and valid CMS-verified app/widget profiles. Normal USB delivery is in progress. No schema/archive, dependency, SDK, permission or capability change. Physical summary/picker rendering is not established by these checks.

Streak89delivery confirmed: device-run.sh exits0, installation/verification100%; direct postflight verifies one Sport1.2.7(89), unchanged identity/signer/entitlements/exact certificate and valid CMS-verified app/widget profiles. Physical summary, native picker, relaunch preference and camera appearance await user review. Two dedicated local commits requested; no new push/public Release.
