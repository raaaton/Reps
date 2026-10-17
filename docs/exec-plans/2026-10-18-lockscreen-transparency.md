# Sport 1.0.2 — Lock Screen Live Activity transparency

## Objective / scope

User supplied a real iPhone screenshot showing Sport's black Lock Screen activity next to the translucent Now Playing system panel, requesting a transparent native appearance. Change only the Lock Screen background treatment; preserve content, layout, actions, rest state, Dynamic Island and all app data. Existing USB delivery authorization applies; no GitHub push or Release before user feedback.

## Findings and implementation

SportRestWidget uses the default ActivityConfiguration Lock Screen background, without a custom background/tint modifier. Apple documents activityBackgroundTint(_:) as the native API for this presentation. Apply .activityBackgroundTint(.clear) to the Lock Screen closure only, allowing the system material/background to show through rather than adding a decorative simulated glass panel. This does not promise pixel-identical Now Playing, which is a separate system presentation. Respect system accessibility/transparency settings. Compile the small API integration with the installed SDK before delivery; visual result requires physical review.

## Verification / progress

Version app/widget 1.0.2 (51). Swift lint, applicable metadata tests, real xtool build, generated app/widget metadata and bundle inspection. No domain change or new dependency/permission/capability; no new test that merely matches source text. Check existing identity/certificate/profiles before and after USB install. Confirm resting, paused and completed appearance on wallpaper, readability, Pause/Resume and unchanged Dynamic Island on the iPhone. Work in progress.

References: https://developer.apple.com/documentation/swiftui/view/activitybackgroundtint(_:) and https://developer.apple.com/design/human-interface-guidelines/live-activities. HIG choosing colors: use custom opacity sparingly and preserve contrast. Physical Music panel resemblance is a user design target, not an Apple guarantee.

Build validation: real xtool compilation succeeded (10.28 s), followed by generated current intent metadata and successful embedding build. Strict Swift lint, unsigned app/widget inspection and 6 metadata tests passed. Initial metadata tests failed because the generated bundle metadata was absent before rebuilding; rerun after generation/embedding succeeded. No new domain tests or full host suite rerun for this one-line presentation-only change. Read-only preflight confirms installed1.0.1(50), same existing effective identity/certificate and valid app/widget profiles, no new capabilities. USB installation in progress.

USB installation blocked before signing/installation at Provisioning66% with Apple HTTP409 ENTITY_ERROR: "There are no current IOS devices on this team matching the provided device IDs." Stopped immediately per project signing policy; no retry, device registration repair, certificate replacement or profile manipulation. Build is ready locally; visual review cannot be requested as an installed build. Read-only post-failure check pending. Full diagnostic is /tmp/sport102-device.log (local only).

Post-failure read-only check passed: installed Sport remains1.0.1(50), same identity and exact preflight certificate hash, app/widget profiles still valid, no new capability. Nothing pushed to GitHub.

Delivery unblocked: user authorized registration repair, same connected iPhone registered with Apple201; standard USB installation then succeeded. Postflight confirmsSport1.0.2(51), same identity/exact certificate, valid app/widget profiles/capabilities. Previous409 is resolved. Await user device review before any GitHub publication. See [registration repair](2026-10-18-device-registration-repair.md).
