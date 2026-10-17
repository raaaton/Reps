# Repair Apple device registration — Sport 1.0.2

User explicitly requested correction of the prior Apple409 provisioning block. Existing local build contains the pending Lock Screen transparency and direct full-training JSON export. Preserve certificates, app identity/data, profiles and existing SDK/toolchain; no GitHub publication.

## Evidence and diagnosis

xtool auth status was logged in, token valid, and active free team unchanged. `xtool ds devices list` returned no devices, while the installed1.0.1 app and valid on-device profiles used the expected existing certificate. Apple error at profile creation was409 ENTITY_ERROR: "There are no current IOS devices on this team matching the provided device IDs."

Read the installed xtool revision's upstream sources: DeveloperServicesAddDeviceOperation treats all409 device-registration responses as already registered; the profile operation then collects the team's current iOS devices. This can obscure an earlier registration failure. It is not proof of the exact original409 registration response, which the failed run did not expose. No claim that expired credentials or a certificate caused the issue.

Two isolated GET-equivalent requests to Apple's devices endpoint using existing xtool authentication, including explicit IOS filtering, returned HTTP200 with zero devices. A single POST to register only the physically connected iPhone, using its actual Lockdown identity, returned201 Created, IOS/ENABLED/IPHONE/iPhone14Pro. No certificate/profile mutation endpoint was used by this repair. The original reason for the team's empty inventory is not established.

The diagnostic helper was temporary, reusing the existing local ADI state in an isolated private temp directory. No password prompt, new login, new Anisette provisioning, certificate generation/revocation or toolchain replacement. Tokens/OTP/private keys not printed or committed. `xtool ds anisette` was investigated but its dummy-provider output was not used as real auth headers. Public upstream source references: https://github.com/xtool-org/xtool/blob/f0a1f90efdbb0dc023e276ff529da92618da7a87/Sources/XKit/DeveloperServices/Devices/DeveloperServicesAddDeviceOperation.swift and Profiles/DeveloperServicesFetchProfileOperation.swift.

## Verification / delivery

After registration, xtool device inventory returns an enabled iPhone and the original cached certificate serial remains in Apple's certificate inventory. Read-only preflight confirms installed1.0.1(50), expected effective identity, valid app/widget profiles and same existing certificate. Unsigned1.0.2(51) bundle inspection passed. Retrying the authorized standard device-run.sh workflow; stop again on any signing/provisioning error rather than revoke a certificate or reset state. Installation and postflight pending.

Delivery verified: standard device-run.sh exited0; provisioning reached100%, signing and installation/verification100%. Postflight confirms installedSport1.0.2(51), same effective app identity and exact cached certificate hash, valid app/widget CMS profiles with unchanged capabilities (no App Group/push). Normal xtool profile renewal succeeded after device registration; no certificate replaced/revoked. The first read-only postflight permission review timed out before execution; the single permitted retry succeeded. No code/toolchain/authentication reset was needed, and no GitHub push/tag/release occurred. Physical review of transparent Lock Screen rest/paused/completed views, unchanged Dynamic Island and direct JSON export remains with the user.
