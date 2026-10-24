# Accent symbols beside primary text — 1.2.3 (85)

## Objective

Apply the user's permanent rule: SF Symbols next to primary/white content or action text use Sport's blue accent, while the title stays unchanged. User explicitly excludes Today/History/Progress/Settings tab icons. Preserve red destructive semantics, contrasting ink on filled buttons and icon-only toolbar controls.

## Decisions and implementation

Use one shared SportLabelStyle that returns a native title-and-icon Label with the existing adaptive SportAccentColors tint only on its icon. Scope it inside the four tab content roots, not the TabView, so native tab appearance is preserved. Modal/navigation descendants inherit it. Reset prominent and native destructive labels to native styles to retain contrast. Skills destructive symbols already carry original UIKit color; keep archive iconOnly styling able to propagate. Accent the two hand-built Skills roadmap symbols separately; keep numeric markers and navigation affordances unchanged. Record policy in AGENTS.md.

No data, functional logic, dependency, capability or privacy behavior changes. Existing dirty work retained. Baseline: /tmp/sport-accent-labels-84/baseline.tar.gz. Current project Markdown inventoried/read in /tmp/sport-accent-labels-84/markdown.txt; HIG color/SF Symbols guide adaptive color and semantic contrast, while blue content symbols are the user's product choice.

## Verification

Run strict Swift lint, existing metadata/style checks, real xtool build, App Intent metadata regeneration/reembedding and app/widget inspection. No new tests or repeated domain suite for a reversible visual-only change. Build85 must be installed and actual version/identity/signer/entitlements checked before requesting iPhone review. Physical review: Settings rows and Skills/history/menu labels are accent beside normal text; title unchanged, archive swipe stays icon-only, red destructive symbols and black prominent symbols retained, tabs retain native selection styling. No host check can establish rendered UIKit appearance.

## Progress

Implementation complete; verification and USB delivery in progress. Evidence: /tmp/sport-accent-labels-84/. No commit, push or release.

Initial84 delivery completed, then final scope moved from root screen views to each enclosing NavigationStack so pushed destinations inherit the rule reliably. Native Tab definitions remain outside the style. Incremented independent build to85 while retaining patch1.2.3 for the same corrective milestone. No functional changes. Nine existing metadata/style checks and strict lint pass; no domain test rerun for visual-only work. USB temporarily unavailable at preflight, then service/device recovered; read-only inventory confirms1.2.3(84) before final delivery.

Final verification/delivery complete: nine metadata/style checks, strict lint without output, real xtool build without warnings, regenerated embedded App Intents metadata and app/widget1.2.3(85) inspection pass. Device helper exits0 with installation/verification100%. Direct postflight confirms exactly one Sport1.2.3(85), unchanged identity/signer/entitlements versus83 and ProfileValidatedtrue. Native rendering/menus/contrast still require user iPhone acceptance. No domain tests repeated for visual-only changes; no push/release. Logs: /tmp/sport-accent-labels-84/metadata-final.log, lint-final.log, build-85.log, build-delivery.log, inspect-final.log, install-final.log and postflight.json.

## Physical menu feedback — 1.2.4 (86)

User confirms menu triggers stay correctly white and destructive menu symbols/text correctly red, but ordinary menu item icons remain white. The SwiftUI content LabelStyle is therefore insufficient at the native menu adaptation boundary; do not assert that prior compilation established native coloring. Reuse the already-confirmed destructive approach: a scoped SkillMenuButton gives native Label images original UIKit symbol ink in the adaptive Sport accent, with primary title text. Replace only ordinary menu/context-menu entries across Skills creation, management, roadmap statuses, AI Other Options and Add Skill. Keep existing red destructive components and white toolbar triggers untouched. No functional/data changes. Baseline/logs: /tmp/sport-menu-icons-86/.

Run existing lint/metadata checks, real xtool build, metadata generation/reembedding and bundle inspection; install1.2.4(86) with same identity and verify actual installed version. User physical review remains necessary for Menu rendering. No new domain tests for this visual-only change.

Build86 verification/delivery complete: strict lint empty, nine metadata/style checks pass, real xtool compilation without warnings, regenerated embedded App Intents metadata and app/widget inspection pass. Device helper exits0, install/verification100%. Direct inventory confirms one Sport1.2.4(86), same identity/signer/entitlements and ProfileValidatedtrue. Evidence: /tmp/sport-menu-icons-86/install.log and postflight.json. User must verify actual blue native menu glyphs on iPhone; no rendered-UI success claimed from host/build. No data changes, push, release or certificate mutation.
