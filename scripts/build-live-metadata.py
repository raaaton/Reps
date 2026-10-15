#!/usr/bin/env python3
"""Generate real App Intent metadata from the current xtool Swift compiler outputs.

Run after xtool dev build, then xtool dev build again packages the generated resources.
Uses the installed Linux generator plus an adapter verified against real Xcode output.
Never signs or alters the installed toolchain.
"""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from live_intent_metadata import apply_live_activity_protocol


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--configuration", choices=["debug", "release"], default="debug")
    arguments = parser.parse_args()
    configuration = arguments.configuration.title()
    root = Path(__file__).resolve().parents[1]
    tool = Path.home() / "omarchy-apple-dev/tools/appintentsmeta.py"
    if not tool.is_file():
        raise ValueError("Installed App Intents metadata generator is unavailable.")
    output = root / ".build/live-metadata"
    output.mkdir(parents=True, exist_ok=True)
    products = [
        ("Sport", "app", root / "xtool/Sport.app", "com.raaaton.sport"),
        ("SportRestWidget", "widget", root / "xtool/Sport.app/PlugIns/SportRestWidget.appex",
         "com.raaaton.sport.rest-widget"),
    ]
    with tempfile.TemporaryDirectory(dir=output) as temporary:
        staged = []
        for module, destination, bundle, identity in products:
            const_name = f"{module}-primary" if arguments.configuration == "release" else "RestPauseIntent"
            const = root / f".build/out/Intermediates.noindex/Sport.build/{configuration}-iphoneos/{module}-t.build/Objects-normal/arm64/{const_name}.swiftconstvalues"
            # SwiftBuild keeps an unchanged const-values file's timestamp on incremental builds.
            # Run after a successful build; validate its actual declarations below.
            if not const.is_file():
                raise ValueError(f"{module}: compile current intent sources with xtool dev build first.")
            metadata_output = Path(temporary) / destination
            subprocess.run([
                "python3", str(tool), "--module-name", module,
                "--bundle-identifier", identity, "--output", str(metadata_output),
                "--const-values", str(const), "--info-plist", str(bundle / "Info.plist"),
                "--binary-file", str(bundle / module),
            ], check=True, capture_output=True, text=True)
            metadata = metadata_output / "Metadata.appintents"
            data = json.loads((metadata / "extract.actionsdata").read_text())
            action = data["actions"].get("RestPauseIntent")
            if set(data["actions"]) != {"RestPauseIntent"} or not action:
                raise ValueError(f"{module}: missing or unexpected compiled App Intent.")
            if action["fullyQualifiedTypeName"] != module + ".RestPauseIntent":
                raise ValueError(f"{module}: App Intent type mismatch.")
            if [p["name"] for p in action["parameters"]] != ["restID", "resume", "expectedTime"]:
                raise ValueError(f"{module}: App Intent parameters mismatch.")
            if action["openAppWhenRun"] or action["supportedModes"] != 1:
                raise ValueError(f"{module}: expected a background action.")
            apply_live_activity_protocol(action, json.loads(const.read_text()), module)
            (metadata / "extract.actionsdata").write_text(json.dumps(data, separators=(",", ":"), ensure_ascii=False))
            staged.append((metadata_output, output / destination))
        for source_dir, destination in staged:
            if destination.exists():
                shutil.rmtree(destination)  # Only this script's derived output, never build caches.
            shutil.copytree(source_dir, destination)
    print("PASS: app and widget App Intent metadata generated from current Swift const values.")
    print("Run xtool dev build to embed it, then scripts/verify-foundation.py before deployment.")
    print("PASS: LiveActivityIntent SessionStarting fields match real Xcode output; iPhone routing still needs verification.")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        raise SystemExit("Metadata generator failed: " + (error.stderr or error.stdout or ""))
    except (OSError, ValueError, KeyError) as error:
        raise SystemExit(f"FAIL: {error}")
