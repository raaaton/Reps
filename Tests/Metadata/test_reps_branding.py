import json
from pathlib import Path
import plistlib
import unittest

ROOT = Path(__file__).resolve().parents[2]

class RepsBrandingTests(unittest.TestCase):
    def test_visible_identity_and_installed_identity_are_distinct(self):
        app = plistlib.loads((ROOT / 'Reps-Info.plist').read_bytes())
        widget = plistlib.loads((ROOT / 'RepsRestWidget-Info.plist').read_bytes())
        self.assertEqual(app['CFBundleDisplayName'], 'Reps')
        self.assertEqual(widget['CFBundleDisplayName'], 'Reps')
        self.assertIn('bundleID: com.raaaton.sport\n', (ROOT / 'xtool.yml').read_text())
        for key in ['NSFaceIDUsageDescription','NSCameraUsageDescription','NSPhotoLibraryAddUsageDescription']:
            self.assertTrue(app[key].startswith('Reps '))
        self.assertEqual(app['CFBundleURLTypes'][0]['CFBundleURLSchemes'], ['reps', 'sport'])

    def test_vault_and_persistence_compatibility(self):
        expected = {
            'Sources/Reps/Features/Vault/VaultCryptography.swift': ['Sport/vault/v1/', 'Sport vault v1'],
            'Sources/Reps/Features/Vault/VaultKeychain.swift': ['com.raaaton.sport.photo-vault.v1'],
            'Sources/RepsLiveSupport/RepsRuntime.swift': ['sport.sqlite'],
            'Sources/Reps/Shared/RepsFeedback.swift': ['sport.hapticsEnabled'],
            'Sources/RepsCore/WorkoutStreak.swift': ['sport.streak.displayUnit'],
            'Sources/RepsCore/TrainingTransferModels.swift': ['sport.training'],
            'Sources/RepsCore/TrainingCSV.swift': ['sport_csv_version'],
        }
        for name, values in expected.items():
            text = (ROOT / name).read_text()
            for value in values:
                self.assertIn(value, text, name)

    def test_native_modules_and_public_copy(self):
        package = (ROOT / 'Package.swift').read_text()
        for module in ['Reps', 'RepsCore', 'RepsRestWidget']:
            self.assertIn(f'name: "{module}"', package)
        self.assertIn('Text("Reps")', (ROOT / 'Sources/Reps/Features/Settings/AboutView.swift').read_text())
        for name in ['Sources/Reps/App/RepsTabView.swift', 'Sources/Reps/Shared/TrainingStore.swift']:
            self.assertIn('["reps", "sport"].contains(url.scheme', (ROOT / name).read_text())

    def test_serialized_live_activity_and_intent_modules_stay_stable(self):
        package = (ROOT / 'Package.swift').read_text()
        for module in ['Sport', 'SportRestWidget', 'SportLiveSupport']:
            self.assertIn(f'name: "{module}"', package)
        for folder in ['Sources/Reps', 'Sources/RepsRestWidget', 'Sources/RepsLiveSupport']:
            self.assertIn(f'path: "{folder}"', package)
        self.assertIn('import SportLiveSupport', (ROOT / 'Sources/RepsRestWidget/RepsRestWidget.swift').read_text())
