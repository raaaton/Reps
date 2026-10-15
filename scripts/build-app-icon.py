#!/usr/bin/env python3
"""Compile the Sport app icon with the installed Linux actool."""
import plistlib
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
compiler = Path.home() / "omarchy-apple-dev/tools/darwin-tools/.build/release/actool"
source = root / "Resources/SportIcon.icon"
output = root / ".build/app-icon"
output.mkdir(parents=True, exist_ok=True)
subprocess.run([
    str(compiler), str(source), "--compile", str(output),
    "--platform", "iphoneos", "--app-icon", "SportIcon",
    "--minimum-deployment-target", "26.0", "--target-device", "iphone",
    "--output-partial-info-plist", str(output / "icon.plist"),
    "--output-format", "human-readable-text",
], check=True)
compiled = plistlib.loads((output / "icon.plist").read_bytes())
configured = plistlib.loads((root / "Sport-Info.plist").read_bytes())
assert compiled["CFBundleIcons"] == configured["CFBundleIcons"], "Icon plist differs from app configuration"
for name in ["Assets.car", "SportIcon60x60@2x.png"]:
    assert (output / name).stat().st_size > 0, f"Missing icon resource: {name}"
print("PASS: Sport layered icon compiled; root resources and icon declaration agree.")
