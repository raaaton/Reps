"""Narrow adapter for the installed Linux generator's missing LiveActivityIntent marker.

The three fields come from real Xcode output; see Tests/Metadata/Fixtures/README.md.
No intent types, parameters, bundle identities or capabilities are synthesized.
"""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def apply_live_activity_protocol(action, const_values, module):
    type_name = module + ".RestPauseIntent"
    entries = [entry for entry in const_values if entry.get("typeName") == type_name]
    if len(entries) != 1 or action.get("fullyQualifiedTypeName") != type_name:
        raise ValueError("Intent action and compiler declaration differ")
    entry = entries[0]
    if "AppIntents.LiveActivityIntent" not in entry.get("conformances", []):
        raise ValueError("Compiler output does not declare LiveActivityIntent")
    mangled = entry.get("mangledTypeName")
    if not isinstance(mangled, str) or not mangled or action.get("mangledTypeName") != mangled:
        raise ValueError("Intent mangled type differs from compiler output")
    reference = json.loads((ROOT / "Tests/Metadata/Fixtures/live-activity-protocol.json").read_text())
    current = {key: action.get(key) for key in reference}
    if current != {key: [] for key in reference} and current != reference:
        raise ValueError("Unknown existing system protocol metadata; refusing to overwrite it")
    action.update(copy.deepcopy(reference))
