# Minimal weight objects and ten-object cap —1.4.1(101)

## Objective and user-approved rule
For every exact total choose the fewest physical weight objects (sum of quantities, not grouped lines), with at most10weight objects per combination, excluding the fixed backpack. Preserve ascending total-weight order and500g offered spacing. An inventory quantity may exceed10; use at most10in a proposed combination. Stable deterministic ties. Keep portrait lock.

## Implementation
Bounded-count dynamic programming retains the lowest object count for each intermediate total; discard candidates above10. Since subsequent item types are independent, a higher-count state at the same total is always dominated. Avoid a greedy heaviest-first rule.

Stored active/history data and old backup payloads are unchanged. Feasible saved compositions with≤10objects must remain usable even when they are no longer the preferred representation; validate their exact identity/name/unit grams/enabled quantity against inventory instead of equality with one canonical generated composition. New choices prefer the minimum. Old snapshots exceeding10remain readable/exportable; future selection requires review. No migration/archive-version change or GitHub publication.

## Verification
Tests before code: physical-copy minimization, single-object win, exact rather than greedy solution, deterministic ties/order, ten across one and multiple types, and saved-goal availability. Add validation/picker cases for feasible nonpreferred selections versus disabled/renamed/overquantity/over10loads. Full host suite, strict lint,13metadata checks, actual xtool build/metadata embedding/portrait-only inspection, independent review, same-identity USB preflight/install/postflight. Physical list/composition checks remain user review.

## Progress
Baseline932e691clean. Existing generator retains first composition and has no physical-count cap; tests added before implementation. Canonical project path Reps; stale Sport writable roots require normal automatic escalation, without changing permissions.

## Results
- Six initial behavior cases fail18assertions against the prior algorithm. Additional validator cases fail on the missing API. After implementation all9new tests pass; complete394-test suite passes10.555s.
- Minimum-count DP uses an immutable prior for each item and rejects states above10physical copies. The prior200equal-item rejection regression now verifies only10copies are selectable; complexity guards remain.
- Goal availability/review, repository selection validation and UI use exact inventory feasibility, preserving valid nonpreferred saved compositions. Picker retains feasible filtered-out selections but keeps the preferred one when the same total is offered. Old over10backup snapshots remain readable. No stored data is rewritten.
- Strict Swift lint,13metadata/style/branding checks and whitespace checks pass. Actual xtool32.46s plus real compiler metadata regeneration/embedding2.84s; unsigned app/widget inspection passes and confirms portrait-only. No compiler warning/error.
- Independent read-only reviewer approves algorithm/cap/determinism, exact feasibility, relevant callers, picker and goals/persistence without actionable findings.
- Fresh preflight validates installed1.4.0(100), expected identity/capabilities, exact cached certificate valid>24h and CMS-verified valid app/widget profiles. Standard USB delivery started; postflight and physical feedback remain distinct gates.
- Evidence:/tmp/reps-minimum-{red,validation-red,green,host,build,metadata,install}.log and /tmp/reps-minimum-{preflight,postflight}.json. No GitHub push or public release.

USB delivery confirmed: standard device-run.sh exits0, install/verification100%, final incremental build3.25s. Direct postflight validates exactly one Reps1.4.1(101), identical effective bundle identity/signer/exact cached certificate/entitlements and valid CMS-verified app/widget profiles. Physical minimum-object list/cap/previous-selection/portrait review remains user feedback. No GitHub push or public release.
