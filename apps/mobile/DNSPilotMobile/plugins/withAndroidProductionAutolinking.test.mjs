import assert from "node:assert/strict";
import { test } from "node:test";

import appConfig from "../app.config.cjs";
import pluginModule from "./withAndroidProductionAutolinking.cjs";

const { patchPodfile, patchSettingsGradle } = pluginModule;

test("production autolinking patch excludes Expo dev-client modules before useExpoModules", () => {
  const input = [
    "plugins {",
    "  id(\"expo-autolinking-settings\")",
    "}",
    "expoAutolinking.useExpoModules()",
  ].join("\n");

  const output = patchSettingsGradle(input);

  assert.match(output, /EAS_BUILD_PROFILE/);
  assert.match(output, /expo-dev-client/);
  assert.match(output, /expo-dev-launcher/);
  assert.match(output, /expo-dev-menu-interface/);
  assert.ok(output.indexOf("expoAutolinking.exclude") < output.indexOf("expoAutolinking.useExpoModules()"));
});

test("production autolinking patch is idempotent", () => {
  const input = "expoAutolinking.useExpoModules()";
  assert.equal(patchSettingsGradle(patchSettingsGradle(input)), patchSettingsGradle(input));
});

test("production Podfile patch excludes Expo dev-client modules before use_expo_modules", () => {
  const input = [
    "target 'DNSPilotMobile' do",
    "  use_expo_modules!",
    "end",
  ].join("\n");

  const output = patchPodfile(input);

  assert.match(output, /EAS_BUILD_PROFILE/);
  assert.match(output, /expo-dev-client/);
  assert.match(output, /dns-settings/);
  assert.match(output, /DNSPILOT_IOS_DNS_SETTINGS/);
  assert.match(output, /use_expo_modules!\(dnspilot_expo_autolinking_options\)/);
  assert.ok(output.indexOf("dnspilot_expo_autolinking_options") < output.indexOf("use_expo_modules!"));
});

test("Android config blocks dev-only permissions from store builds", () => {
  const config = appConfig();
  assert.deepEqual(config.android.blockedPermissions, [
    "android.permission.READ_EXTERNAL_STORAGE",
    "android.permission.SYSTEM_ALERT_WINDOW",
    "android.permission.VIBRATE",
    "android.permission.WRITE_EXTERNAL_STORAGE",
  ]);
});

test("dynamic app config preserves Expo-provided app.json values", () => {
  const config = appConfig({
    config: {
      name: "Doctor Probe",
      slug: "doctor-probe",
      plugins: ["expo-router"],
      android: {
        package: "com.dnspilot.probe",
      },
    },
  });

  assert.equal(config.name, "Doctor Probe");
  assert.equal(config.slug, "doctor-probe");
  assert.equal(config.android.package, "com.dnspilot.probe");
  assert.deepEqual(config.plugins, [
    "expo-router",
    "./plugins/withAndroidProductionAutolinking.cjs",
  ]);
});

test("DNS Settings entitlement is enabled only for the explicit iOS capability profile", () => {
  const previous = process.env.EAS_BUILD_PROFILE;
  try {
    process.env.EAS_BUILD_PROFILE = "production";
    const storeConfig = appConfig();
    assert.doesNotMatch(storeConfig.plugins.join("\n"), /withIosDnsSettings/);
    assert.equal(storeConfig.extra.iosDnsSettingsEnabled, false);

    process.env.EAS_BUILD_PROFILE = "production-ios-dns";
    const entitledConfig = appConfig();
    assert.match(entitledConfig.plugins.join("\n"), /withIosDnsSettings/);
    assert.equal(entitledConfig.extra.iosDnsSettingsEnabled, true);
  } finally {
    if (previous === undefined) delete process.env.EAS_BUILD_PROFILE;
    else process.env.EAS_BUILD_PROFILE = previous;
  }
});

test("production config removes the Local Network bridge declaration", () => {
  const previous = process.env.EAS_BUILD_PROFILE;
  process.env.EAS_BUILD_PROFILE = "production";
  try {
    const config = appConfig();
    assert.equal(config.ios.infoPlist.NSLocalNetworkUsageDescription, undefined);
  } finally {
    if (previous === undefined) {
      delete process.env.EAS_BUILD_PROFILE;
    } else {
      process.env.EAS_BUILD_PROFILE = previous;
    }
  }
});
