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
