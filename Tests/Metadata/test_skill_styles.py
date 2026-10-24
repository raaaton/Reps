"""Guard Skills' semantic control boundaries, rather than snapshotting view layouts."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SKILLS = ROOT / 'Sources/Sport/Features/Skills'

class SkillStyleTests(unittest.TestCase):
    def test_form_toolbar_actions_use_shared_semantic_controls(self):
        for name in ['SkillEditor.swift', 'SkillAddToWorkoutView.swift', 'SkillBlockEditor.swift', 'SkillGenerationView.swift', 'SkillPracticeView.swift']:
            text = (SKILLS / name).read_text()
            self.assertNotRegex(text, r'Button\("(?:Save|Done|Close|Cancel|Back)"\)\s*\{', name)
            self.assertIn('SkillToolbarButton', text, name)

    def test_custom_filled_and_icon_menu_styles_live_in_one_component(self):
        for path in SKILLS.glob('*.swift'):
            if path.name == 'SkillButtons.swift':
                continue
            self.assertNotRegex(path.read_text(), r'\.buttonStyle\(\.(?:glassProminent|borderedProminent)\)', path.name)
        controls = (SKILLS / 'SkillButtons.swift').read_text()
        self.assertIn('role: .destructive', controls)
        self.assertIn('Text(title).foregroundStyle(.black)', controls)
        self.assertIn('Image(systemName: systemImage).foregroundStyle(.black)', controls)

    def test_block_sheet_is_owned_by_workout_editor(self):
        section = (SKILLS / 'SkillBlockEditor.swift').read_text().split('struct ScheduleSkillSection: View')[1]
        self.assertNotIn('.sheet(', section)
        self.assertNotIn('schedule.skills.append', section)
        editor = (ROOT / 'Sources/Sport/Features/Settings/PlanningView.swift').read_text()
        self.assertIn('.sheet(item: $skillDraft)', editor)

if __name__ == '__main__':
    unittest.main()
