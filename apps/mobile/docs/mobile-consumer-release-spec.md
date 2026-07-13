# DNSPilot Mobile Consumer Release Spec

## Decision

DNSPilot Mobile is a foreground DNS benchmark and recommendation app. The
consumer Store build is benchmark-first. It never silently changes consumer
system DNS, runs a VPN, claims internet-speed improvement, or claims to flush
the OS DNS cache.

## Product Surface

The consumer navigation has three stable areas:

- **Check DNS**: a DNS-only Quick Check is the default. Users can choose
  General, Vietnam, Steam/Valve, Dota 2 SEA, CS2, Riot/League, or a saved
  domain suite. Advanced controls expose DNS + TCP, system resolver validation,
  A/AAAA and IPv4/IPv6 without blocking the first check.
- **Profiles**: built-in resolver catalog, custom DNS profile CRUD, custom
  suite CRUD, language, and capability-specific DNS setup.
- **History**: saved foreground checks with health and recommendation labels.
  A saved recommendation always requires a fresh retest before setup guidance.

Internal transport, bridge, catalog counts, raw JSON, synthetic samples, and
policy-debug toggles are not consumer tabs. Debug data remains available only
through a development-only diagnostics disclosure.

## Result Contract

Every completed check presents:

- measurement scope and elapsed time;
- fastest observed resolver, separately from the balanced recommendation;
- health, confidence, caveats, and an explicit `Keep current DNS` outcome when
  evidence is weak;
- per-step and per-resolver status, failure step/reason, and copyable report in
  Details;
- exactly one primary next action derived from platform capability.

## OS Capability Contract

| Platform | Consumer action | Explicitly excluded |
| --- | --- | --- |
| iOS/iPadOS Store | Benchmark, guide plain DNS, and retest. | Plain DNS mutation and flush. |
| iOS/iPadOS entitled build | DoH/DoT DNS Settings install/remove/status; user enables it in Settings. | Silent enable and plain DNS mutation. |
| Android consumer | Copy DoT hostname, open Private DNS/Network Settings, return and retest. | Silent Private DNS mutation and `VpnService`. |

The `dns-settings` NetworkExtension entitlement is opt-in through an explicit
build profile. It must not be present in the default iOS Store profile until
Apple approves the entitlement and a signed physical-device test passes.

## UX Rules

- Do not show an app-open permission modal. Foreground network diagnostics do
  not require a dangerous runtime permission.
- Present OS settings guidance only after the user requests setup from a valid
  result, or from a contextual help entry point.
- A cancelled foreground check must not overwrite a newer result. The UI may
  suppress a pending result but must not claim that the underlying native work
  was terminated unless native cancellation exists.
- Use the existing adaptive layout primitives. iPad and Android tablets use
  bounded, multi-column content; phone controls remain touch-sized.
- English and Vietnamese copy ship together. New user-facing copy must be
  translated in the same change.

## Release Gates

- Unit tests, typecheck, Expo config/export, Expo dependency check, Rust
  contract tests, iOS Simulator build, and Android release build pass.
- Production manifests contain no dev launcher/menu, VPN service, or privileged
  DNS permissions.
- Store metadata, privacy answers, screenshots, support/privacy URL, and
  physical-device acceptance scripts are maintained in `apps/mobile/docs`.
- Apple signing/entitlement approval and both-platform physical-device settings
  validation are manual gates, not reasons to block unrelated implementation.
