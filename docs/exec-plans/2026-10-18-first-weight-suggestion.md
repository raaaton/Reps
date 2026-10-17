# First weighted goal after easy bodyweight work — 1.0.3

User requests: Feeling below8 with no added weight proposes the minimum configured reps and the smallest available added load. Apply to complete repetition-based working exercises where every actual set is0g, without waiting for maximum repetitions. Existing <8 threshold is strict, suggestions require explicit adoption, timed exercises retain their configured duration and manual loading rules, weighted/mixed-load progression and >9 decrease rules stay intact. Do not invent a load if none is available.

Scope: change the assessment condition feeding the existing GoalEngine increase branch, which already resets all targets to the configured minimum. Adjust explanation so it no longer falsely says maximum reps were required for bodyweight. Test thresholds, smallest positive load independent of order, completeness, bodyweight-only eligibility, unchanged weighted behavior and no fabricated load. Existing SQLite adoption/stale-context checks remain authoritative.

Preserve pending1.0.2 changes and device registration fix. Deliver local1.0.3(52) via standard xtool/USB workflow, same identity/certificate, no GitHub push before device review. Lint, relevant and full host suite, real xtool build, generated metadata/inspection/tests, read-only pre/postflight. No new permissions or dependencies. Tests added before production changes; RED run pending.

Progress: progression RED reproduced6 failures; targeted fix followed by185 passing host tests. User then added missed attendance and neutral Cancel requirements to this delivery; see companion plan. No publication yet.

Local verification: strict Swift lint clean, full188 host tests/0 failures5.242s, xtool build16.62s then metadata packaging2.01s, generated metadata valid and6 metadata tests pass; unsigned1.0.3(52) inspected. Preflight confirms same installed Sport identity/certificate/current app-widget profiles and unchanged capabilities. Standard USB delivery in progress; no publication.

Delivery: device-run.sh code0, installation and verification100%. Postflight confirms installed1.0.3(52), identical existing certificate, same effective app/widget identities, valid profiles and unchanged capabilities. Await user iPhone review (especially native Cancel tint and presentation/lifecycle); no commit/push/tag/Release.
