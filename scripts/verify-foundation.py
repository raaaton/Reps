#!/usr/bin/env python3
"""Inspect the real unsigned Reps app; never signs or deploys it."""

import json
import plistlib
import struct
import sys
import wave
from pathlib import Path


def require(condition, message):
    if not condition:
        raise ValueError(message)


def inspect_binary(executable):
    binary = executable.read_bytes()
    require(len(binary) >= 32, "Empty or truncated executable")
    magic, cpu, _, kind, count, commands_size, _, _ = struct.unpack_from("<8I", binary)
    require(magic == 0xFEEDFACF and cpu == 0x0100000C, "Not a 64-bit arm64 Mach-O")
    require(kind == 2, "Mach-O is not an executable")
    require(32 + commands_size <= len(binary), "Truncated Mach-O load commands")
    cursor = 32
    ios_target_found = False
    for _ in range(count):
        require(cursor + 8 <= 32 + commands_size, "Truncated load command")
        command, size = struct.unpack_from("<2I", binary, cursor)
        require(size >= 8 and cursor + size <= 32 + commands_size, "Invalid load command size")
        require(command != 0x1D, "Unexpected code signature in unsigned build")
        if command == 0x32:  # LC_BUILD_VERSION
            require(size >= 24, "Truncated build version")
            platform, minimum = struct.unpack_from("<2I", binary, cursor + 8)
            require(platform == 2 and minimum == 26 << 16, "Binary target differs from iOS 26")
            ios_target_found = True
        cursor += size
    require(ios_target_found, "Missing iOS build-version load command")
    require(cursor == 32 + commands_size, "Inconsistent load-command table")


def main():
    root = Path(__file__).resolve().parents[1]
    bundle = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "xtool/Reps.app"
    with (bundle / "Info.plist").open("rb") as stream:
        info = plistlib.load(stream)

    expected = {
        "CFBundleIdentifier": "com.raaaton.sport",
        "CFBundleDisplayName": "Reps",
        "CFBundleExecutable": "Reps",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "1.5.5",
        "CFBundleVersion": "114",
        "MinimumOSVersion": "26.0",
        "UIDeviceFamily": [1],
        "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
        "CFBundleDevelopmentRegion": "en",
    }
    for key, value in expected.items():
        require(info.get(key) == value, f"Unexpected {key}: {info.get(key)!r}")
    require(info.get("CFBundleSupportedPlatforms") == ["iPhoneOS"], "Not an iPhoneOS bundle")
    require("UILaunchScreen" in info, "Missing native launch-screen configuration")
    require({key for key in info if "UsageDescription" in key} == {"NSFaceIDUsageDescription", "NSCameraUsageDescription", "NSPhotoLibraryAddUsageDescription"}, "Unexpected privacy permission")
    require(info["NSFaceIDUsageDescription"] == "Reps uses Face ID to unlock your private photos and videos.", "Unexpected Face ID purpose string")
    require(not info.get("UTExportedTypeDeclarations"), "Unexpected prototype file type")
    require(not info.get("UIBackgroundModes"), "Unexpected background mode")
    require(info.get("NSSupportsLiveActivities") is True, "Missing Live Activities declaration")
    require(info.get("CFBundleURLTypes", [{}])[0].get("CFBundleURLSchemes") == ["reps", "sport"], "Unexpected workout URL scheme")
    extension = bundle / "PlugIns/RepsRestWidget.appex"
    require(list((bundle / "PlugIns").iterdir()) == [extension], "Unexpected embedded extension")
    child = plistlib.loads((extension / "Info.plist").read_bytes())
    for key, value in {"CFBundleIdentifier": "com.raaaton.sport.rest-widget",
                       "CFBundleShortVersionString": "1.5.5", "CFBundleVersion": "114",
                       "MinimumOSVersion": "26.0", "CFBundleExecutable": "RepsRestWidget",
                       "CFBundlePackageType": "XPC!"}.items():
        require(child.get(key) == value, f"Unexpected extension {key}")
    require(child.get("NSExtension", {}).get("NSExtensionPointIdentifier") == "com.apple.widgetkit-extension", "Not a WidgetKit extension")
    for target, module, destination in [(bundle, "Sport", "app"), (extension, "SportRestWidget", "widget")]:
        require(not (target / "embedded.mobileprovision").exists(), "Expected unprovisioned targets")
        require(not (target / "_CodeSignature").exists(), "Expected unsigned targets")
        metadata = target / "Metadata.appintents"
        generated = root / ".build/live-metadata" / destination / "Metadata.appintents"
        require(metadata.is_dir(), f"Missing {module} intent metadata")
        require({p.name for p in metadata.iterdir()} == {p.name for p in generated.iterdir()}, "Metadata files differ")
        for item in generated.iterdir():
            require(item.read_bytes() == (metadata / item.name).read_bytes(), "Metadata differs from generated output")
        actions = json.loads((metadata / "extract.actionsdata").read_text())["actions"]
        require(set(actions) == {"RestPauseIntent"}, "Unexpected intent action")
        action = actions["RestPauseIntent"]
        require(action["fullyQualifiedTypeName"] == module + ".RestPauseIntent", "Intent module differs")
        require([p["name"] for p in action["parameters"]] == ["restID", "resume", "expectedTime"], "Intent parameters differ")
        reference = json.loads((root / "Tests/Metadata/Fixtures/live-activity-protocol.json").read_text())
        require({key: action.get(key) for key in reference} == reference, "Missing native LiveActivityIntent routing protocol")
        require(not action["openAppWhenRun"] and action["supportedModes"] == 1, "Intent should run in background")

    require(not (bundle / "embedded.mobileprovision").exists(), "Expected an unprovisioned build")
    require(not (bundle / "_CodeSignature").exists(), "Expected an unsigned build")

    resource = bundle / "Reps_Sport.bundle" / "RestComplete.wav"
    require(resource.read_bytes() == (root / "Sources/Reps/Resources/RestComplete.wav").read_bytes(), "Bundled rest sound differs or is missing")
    with wave.open(str(resource), "rb") as sound:
        require(sound.getnchannels() == 1 and sound.getsampwidth() == 2, "Unsupported sound format")
        require(sound.getframerate() == 22050 and sound.getnframes() == 6600, "Unexpected sound duration")

    icon = info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {})
    require(icon.get("CFBundleIconName") == "RepsIcon", "Missing Reps app icon")
    require(icon.get("CFBundleIconFiles") == ["RepsIcon60x60"], "Unexpected icon file declaration")
    for name in ["Assets.car", "RepsIcon60x60@2x.png"]:
        require((bundle / name).read_bytes() == (root / ".build/app-icon" / name).read_bytes(), "Compiled icon differs or is missing from app root")

    require((bundle / "PHOSPHOR-LICENSE.txt").read_bytes() == (root / "Resources/IconSources/PHOSPHOR-LICENSE.txt").read_bytes(), "Missing Phosphor license")

    inspect_binary(bundle / "Reps")
    inspect_binary(extension / "RepsRestWidget")
    print(f"PASS: Reps {info['CFBundleShortVersionString']} ({info['CFBundleVersion']}), com.raaaton.sport, arm64 iPhoneOS 26.0, English, portrait only, unsigned.")
    print("PASS: one WidgetKit extension, app and extension intent metadata; no profile; declared Face ID/camera/Photos add-only purposes, no broad Photos access.")
    print("PASS: SwiftPM bundled rest sound present, mono PCM WAV, 0.30 seconds.")
    print("PASS: Reps layered icon present at app root and declared in Info.plist.")
    print("This local bundle inspection does not validate iPhone rendering or behavior.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, struct.error, plistlib.InvalidFileException) as error:
        sys.exit(f"FAIL: {error}")
