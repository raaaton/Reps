#!/usr/bin/env bash
# Build and inspect a public, unsigned IPA. Never authenticates, signs, installs or uploads.
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(python3 -c 'import plistlib; print(plistlib.load(open("Reps-Info.plist", "rb"))["CFBundleShortVersionString"])')
swift test --package-path Tests/Host
swift format lint --strict --recursive Package.swift Sources Tests/Host/Package.swift Tests/Host/Tests
python3 -m unittest discover -s Tests/Metadata -v
python3 scripts/build-app-icon.py
mkdir -p .build/live-metadata/{app,widget}/Metadata.appintents
xtool dev build --configuration release
python3 scripts/build-live-metadata.py --configuration release
xtool dev build --configuration release
python3 scripts/verify-foundation.py
xtool dev build --configuration release --ipa
mkdir -p dist
cp xtool/Reps.ipa "dist/Reps-$version.ipa"
python3 scripts/verify-release.py "dist/Reps-$version.ipa"
printf 'Ready: dist/Reps-%s.ipa (unsigned; re-sign before installation).\n' "$version"
