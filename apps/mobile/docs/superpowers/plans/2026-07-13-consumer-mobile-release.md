# DNSPilot Mobile Consumer Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing native DNS runtime into a store-safe, three-area consumer mobile app.

**Architecture:** Preserve the Expo/Rust adapter and its stable JSON actions. Add small pure JavaScript view-models for consumer quick-check, result presentation, setup actions, and history rows. Replace the visible tab shell while retaining capability-specific native adapters behind one result CTA.

**Tech Stack:** Expo SDK 57, Expo Router, React Native 0.86, local Expo Modules, Rust `dnspilot-mobile-runtime`, Node built-in tests.

## Global Constraints

- Change only `apps/mobile/**`, `apps/ios/**`, `apps/android/**`, `packages/mobile/**`, and mobile docs.
- Keep the default iOS Store build benchmark-first; `dns-settings` is opt-in only.
- No iOS plain DNS switch, Android silent Private DNS mutation, `VpnService`, DNS cache flush claim, background scheduler, or speed-improvement claim.
- Use RED -> GREEN -> REFACTOR for every behavior/view-model change, then run targeted tests.
- Add English and Vietnamese copy in the same user-facing change.
- Commit every verified milestone with only mobile-owned files staged.

---

### Task 1: Model Quick Check Inputs

**Files:**
- Create: `apps/mobile/DNSPilotMobile/src/view-models/consumer-check.js`
- Create: `apps/mobile/DNSPilotMobile/src/view-models/consumer-check.d.ts`
- Test: `apps/mobile/DNSPilotMobile/src/view-models/consumer-check.test.mjs`

**Interfaces:**
- Consumes: catalog profiles and suites.
- Produces: `buildQuickCheck({ profiles, suites, platform, presetID })` returning a valid `buildBenchmarkPlan` input and visible preset IDs.

- [ ] **Step 1: Write the failing test**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { buildQuickCheck } from './consumer-check.js';

test('defaults to DNS-only General check with three plain profiles', () => {
  const model = buildQuickCheck({ profiles: fixtures.profiles, suites: fixtures.suites, platform: 'ios' });
  assert.equal(model.mode, 'compare');
  assert.equal(model.suiteId, 'general');
  assert.deepEqual(model.profileIds, ['cloudflare', 'google-public-dns', 'quad9']);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test src/view-models/consumer-check.test.mjs`

Expected: FAIL because `consumer-check.js` does not exist.

- [ ] **Step 3: Write minimal implementation**

```js
export function buildQuickCheck({ profiles = [], suites = [], platform = 'ios', presetID = 'general' } = {}) {
  const plain = profiles.filter((profile) => profile?.protocol === 'plain');
  const preferred = ['cloudflare', 'google-public-dns', 'quad9']
    .filter((id) => plain.some((profile) => profile.id === id));
  return {
    mode: 'compare',
    platform,
    presetID,
    suiteId: suites.some((suite) => suite.id === presetID) ? presetID : undefined,
    profileIds: preferred.length ? preferred : plain.slice(0, 3).map((profile) => profile.id),
  };
}
```

- [ ] **Step 4: Run targeted test and existing plan tests**

Run: `node --test src/view-models/consumer-check.test.mjs src/view-models/benchmark-plan.test.mjs`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/DNSPilotMobile/src/view-models/consumer-check.* apps/mobile/docs
git commit -m "[mobile] model consumer quick checks"
```

### Task 2: Model Consumer Result and Primary Setup Action

**Files:**
- Create: `apps/mobile/DNSPilotMobile/src/view-models/consumer-result.js`
- Create: `apps/mobile/DNSPilotMobile/src/view-models/consumer-result.d.ts`
- Test: `apps/mobile/DNSPilotMobile/src/view-models/consumer-result.test.mjs`

**Interfaces:**
- Consumes: benchmark result, profiles, runtime capabilities, and platform.
- Produces: `buildConsumerResult(input)` with `fastestObserved`, `recommendation`, `keepCurrentDNS`, `notes`, and one nullable `primaryAction`.

- [ ] **Step 1: Write the failing test**

```js
test('keeps current DNS when all candidates are unreliable', () => {
  const presentation = buildConsumerResult({ result: failedResult, profiles, platform: 'android-play' });
  assert.equal(presentation.keepCurrentDNS, true);
  assert.equal(presentation.primaryAction, null);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test src/view-models/consumer-result.test.mjs`

Expected: FAIL because `consumer-result.js` does not exist.

- [ ] **Step 3: Write minimal implementation**

```js
export function buildConsumerResult({ result, profiles = [], platform = 'ios', iosDnsSettingsAvailable = false } = {}) {
  const data = result?.data ?? {};
  const summary = data.summary ?? {};
  const recommendedID = data.recommendation?.profile_id ?? summary.recommended_profile_id;
  const keepCurrentDNS = summary.primary_issue === 'all-resolvers-low-reliability';
  const profile = profiles.find((item) => item.id === recommendedID);
  return { keepCurrentDNS, profile, primaryAction: keepCurrentDNS ? null : actionFor({ platform, profile, iosDnsSettingsAvailable }) };
}
```

- [ ] **Step 4: Run targeted test and diagnostics tests**

Run: `node --test src/view-models/consumer-result.test.mjs src/view-models/benchmark-diagnostics.test.mjs src/view-models/settings-guidance.test.mjs`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/DNSPilotMobile/src/view-models/consumer-result.*
git commit -m "[mobile] present safe consumer results"
```

### Task 3: Replace the Visible Tab Shell and Check DNS Screen

**Files:**
- Modify: `apps/mobile/DNSPilotMobile/app/(tabs)/_layout.tsx`
- Modify: `apps/mobile/DNSPilotMobile/app/(tabs)/index.tsx`
- Create: `apps/mobile/DNSPilotMobile/app/(tabs)/profiles.tsx`
- Create: `apps/mobile/DNSPilotMobile/app/(tabs)/history.tsx`
- Modify: `apps/mobile/DNSPilotMobile/src/view-models/localization.js`
- Test: `apps/mobile/DNSPilotMobile/src/view-models/consumer-check.test.mjs`

**Interfaces:**
- Consumes: Task 1 quick-check model and Task 2 result presentation.
- Produces: static `Check DNS`, `Profiles`, and `History` tabs; no visible bridge or app-open access sheet in native builds.

- [ ] **Step 1: Add failing user-visible behavior tests for contextual setup**

```js
test('does not request system settings before a user asks for setup', () => {
  const state = buildCheckEntryState({ nativeRuntime: true });
  assert.equal(state.showsSystemAccessSheet, false);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test src/view-models/consumer-check.test.mjs`

Expected: FAIL because `buildCheckEntryState` does not exist.

- [ ] **Step 3: Implement and wire native UI**

```tsx
<Tabs.Screen name="index" options={{ title: t('tabs.checkDns') }} />
<Tabs.Screen name="profiles" options={{ title: t('tabs.profiles') }} />
<Tabs.Screen name="history" options={{ title: t('tabs.history') }} />
<Tabs.Screen name="benchmark" options={{ href: null }} />
```

The Check screen starts the Task 1 DNS-only plan, reveals Advanced controls on
explicit user action, shows Task 2 result cards, and opens OS guidance only
from `primaryAction`. Keep debug fields behind `__DEV__`.

- [ ] **Step 4: Run tests, typecheck, and web export**

Run: `npm test && npm run typecheck && npx expo export --platform web`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/DNSPilotMobile/app apps/mobile/DNSPilotMobile/src
git commit -m "[mobile] ship consumer check flow"
```

### Task 4: Profiles, History, Retest, and Native Capability Profiles

**Files:**
- Modify: `apps/mobile/DNSPilotMobile/app/(tabs)/profiles.tsx`
- Modify: `apps/mobile/DNSPilotMobile/app/(tabs)/history.tsx`
- Modify: `apps/mobile/DNSPilotMobile/app.config.cjs`
- Modify: `apps/mobile/DNSPilotMobile/eas.json`
- Modify: `apps/mobile/DNSPilotMobile/src/view-models/native-dns-settings.js`
- Test: `apps/mobile/DNSPilotMobile/src/view-models/native-dns-settings.test.mjs`
- Test: `apps/mobile/DNSPilotMobile/src/view-models/consumer-result.test.mjs`

**Interfaces:**
- Consumes: custom profile/suite forms, history records, and Task 2 primary action.
- Produces: editable profiles/suites, readable history, saved system retest, default iOS Store config without `dns-settings`, and opt-in entitled profile.

- [ ] **Step 1: Write failing build-profile and retest tests**

```js
test('does not expose native DNS install without the entitled build capability', () => {
  assert.equal(buildIosDnsSettingsRequest(dohProfile, { entitlementEnabled: false }).available, false);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test src/view-models/native-dns-settings.test.mjs src/view-models/consumer-result.test.mjs`

Expected: FAIL because entitlement capability is not part of the request.

- [ ] **Step 3: Implement capability-gated setup**

Default production config excludes the iOS DNS config plugin. A separate
`production-ios-dns` EAS profile enables it with `DNSPILOT_IOS_DNS_SETTINGS=1`.
The UI offers an encrypted install action only when both the build capability
and the native module report availability. System retest stores history.

- [ ] **Step 4: Run tests and native configuration checks**

Run: `npm test && EAS_BUILD_PROFILE=production npx expo config --type public && EAS_BUILD_PROFILE=production-ios-dns npx expo config --type public`

Expected: PASS; only the opted-in config contains the DNS Settings plugin/entitlement.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/DNSPilotMobile
git commit -m "[mobile] gate DNS settings by build capability"
```

### Task 5: Release Evidence and Manual Gates

**Files:**
- Create: `apps/mobile/DNSPilotMobile/scripts/release-preflight.mjs`
- Modify: `apps/mobile/DNSPilotMobile/package.json`
- Modify: `apps/mobile/mobile-readiness.md`
- Modify: `apps/mobile/mobile-publish-checklist.md`
- Create: `apps/mobile/docs/mobile-store-metadata.md`
- Create: `apps/mobile/docs/mobile-real-device-acceptance.md`

**Interfaces:**
- Consumes: production and entitled EAS profiles.
- Produces: one reproducible preflight command, store metadata, and exact physical-device flows.

- [ ] **Step 1: Write failing release script test fixture**

```sh
test "$(node scripts/release-preflight.mjs --check-config production)" = "ok"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node scripts/release-preflight.mjs --check-config production`

Expected: FAIL because the preflight entry point does not exist.

- [ ] **Step 3: Implement release preflight and documentation**

The script runs unit tests, typecheck, Expo config/export/install checks, Rust
contract tests, and validates the production Android manifest for prohibited
permissions. Documentation distinguishes simulator evidence from required
physical-device and publisher-account steps.

- [ ] **Step 4: Run complete validation**

Run: `npm run release:preflight`

Expected: PASS locally or report the exact unavailable platform tool.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile
git commit -m "[mobile] document consumer release gates"
```

## Self-Review

- Consumer IA, quick check, result truthfulness, profiles, history, iOS/Android capability boundaries, localization, tablet layout, tests, and release gates map to Tasks 1-5.
- The plan contains no unowned core/desktop paths and no silent DNS mutation.
- The only manual gates are signing, Apple entitlement approval, publisher accounts, store submission, and physical-device OS Settings validation.
