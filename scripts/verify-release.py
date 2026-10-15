#!/usr/bin/env python3
"""Inspect a locally built, unsigned Sport IPA before public distribution."""
import hashlib
from pathlib import Path, PurePosixPath
import stat
import subprocess
import sys
import tempfile
import zipfile


def main():
    if len(sys.argv) != 2:
        raise ValueError("Usage: python3 scripts/verify-release.py Sport.ipa")
    archive = Path(sys.argv[1]).resolve()
    root = Path(__file__).resolve().parents[1]
    with zipfile.ZipFile(archive) as ipa:
        members = ipa.infolist()
        if len(members) > 2048 or sum(x.file_size for x in members) > 256 * 1024 * 1024:
            raise ValueError("Unexpected archive size")
        for item in members:
            path = PurePosixPath(item.filename)
            root_directory = item.is_dir() and path.parts == ("Payload",)
            if path.is_absolute() or ".." in path.parts or (not root_directory and path.parts[:2] != ("Payload", "Sport.app")):
                raise ValueError("Unexpected archive path")
            if stat.S_ISLNK(item.external_attr >> 16):
                raise ValueError("Unexpected symbolic link")
            if any(part in {"_CodeSignature", "Documents", "Library", "SC_Info"} for part in path.parts):
                raise ValueError("Signature or user-data directory in public IPA")
            if path.name == "embedded.mobileprovision" or path.suffix.lower() in {".p12", ".p8", ".pem", ".key", ".mobileprovision", ".sqlite", ".db"}:
                raise ValueError("Provisioning, credentials or database in public IPA")
        with tempfile.TemporaryDirectory(prefix="sport-ipa-verify-") as temporary:
            ipa.extractall(temporary)
            bundle = Path(temporary) / "Payload/Sport.app"
            subprocess.run([sys.executable, str(root / "scripts/verify-foundation.py"), str(bundle)], check=True)
    print("PASS: unsigned public IPA, one app and WidgetKit extension, no personal provisioning or user database.")
    with archive.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    print(f"SHA256 {digest}  {archive.name}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        raise SystemExit(f"FAIL: {error}")
