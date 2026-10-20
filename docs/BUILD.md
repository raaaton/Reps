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
