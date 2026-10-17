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
