import copy
import json
import sys
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from live_intent_metadata import apply_live_activity_protocol

FIELDS = json.loads((ROOT / "Tests/Metadata/Fixtures/live-activity-protocol.json").read_text())


class LiveMetadataTests(unittest.TestCase):
    def inputs(self):
        path = ROOT / "xtool/Sport.app/Metadata.appintents/extract.actionsdata"
        action = json.loads(path.read_text())["actions"]["RestPauseIntent"]
        const = ROOT / ".build/out/Intermediates.noindex/Sport.build/Debug-iphoneos/Sport-t.build/Objects-normal/arm64/RestPauseIntent.swiftconstvalues"
        return action, json.loads(const.read_text())

    def test_adapter_preserves_every_other_compiled_field_and_is_idempotent(self):
        action, declarations = self.inputs()
        for key in FIELDS:
            action[key] = []
        before = copy.deepcopy(action)
        apply_live_activity_protocol(action, declarations, "Sport")
        self.assertEqual({key: value for key, value in action.items() if key not in FIELDS},
                         {key: value for key, value in before.items() if key not in FIELDS})
        self.assertEqual({key: action[key] for key in FIELDS}, FIELDS)
        once = copy.deepcopy(action)
        apply_live_activity_protocol(action, declarations, "Sport")
        self.assertEqual(action, once)

    def test_rejects_non_live_intent_without_mutation(self):
        action, declarations = self.inputs()
        declarations[0]["conformances"].remove("AppIntents.LiveActivityIntent")
        before = copy.deepcopy(action)
        with self.assertRaises(ValueError):
            apply_live_activity_protocol(action, declarations, "Sport")
        self.assertEqual(action, before)

    def test_rejects_wrong_compiled_type_without_mutation(self):
        action, declarations = self.inputs()
        action["mangledTypeName"] = "wrong-type"
        before = copy.deepcopy(action)
        with self.assertRaises(ValueError):
            apply_live_activity_protocol(action, declarations, "Sport")
        self.assertEqual(action, before)

    def test_rejects_missing_compiled_mangled_type_without_mutation(self):
        action, declarations = self.inputs()
        action.pop("mangledTypeName")
        declarations[0].pop("mangledTypeName")
        before = copy.deepcopy(action)
        with self.assertRaises(ValueError):
            apply_live_activity_protocol(action, declarations, "Sport")
        self.assertEqual(action, before)

    def test_rejects_unknown_existing_protocol_without_mutation(self):
        action, declarations = self.inputs()
        action["systemProtocols"] = ["another-protocol"]
        before = copy.deepcopy(action)
        with self.assertRaises(ValueError):
            apply_live_activity_protocol(action, declarations, "Sport")
        self.assertEqual(action, before)

    def test_both_bundles_keep_native_live_activity_routing(self):
        for module, path in [("Sport", "xtool/Sport.app"),
                             ("SportRestWidget", "xtool/Sport.app/PlugIns/SportRestWidget.appex")]:
            with self.subTest(module=module):
                data = json.loads((ROOT / path / "Metadata.appintents/extract.actionsdata").read_text())
                action = data["actions"]["RestPauseIntent"]
                self.assertEqual({key: action[key] for key in FIELDS}, FIELDS)
                self.assertFalse(action["openAppWhenRun"])
                self.assertEqual(action["supportedModes"], 1)
                self.assertEqual(action["fullyQualifiedTypeName"], module + ".RestPauseIntent")
                self.assertEqual([p["name"] for p in action["parameters"]], ["restID", "resume", "expectedTime"])


if __name__ == "__main__":
    unittest.main()
