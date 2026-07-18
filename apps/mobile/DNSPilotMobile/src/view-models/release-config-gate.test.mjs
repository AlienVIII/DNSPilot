import assert from "node:assert/strict";
import { test } from "node:test";

import {
  assertAndroidStoreDex,
  assertAndroidStoreManifest,
  assertEasBuildProfiles,
  assertIosDnsExperimentConfig,
  assertStoreReleaseConfig,
} from "./release-config-gate.js";

const storeConfig = {
  android: { package: "com.dnspilot.mobile" },
  ios: { bundleIdentifier: "com.dnspilot.mobile", infoPlist: {} },
  locales: { en: "./languages/en.json", vi: "./languages/vi.json" },
  plugins: ["expo-router", "./plugins/withAndroidProductionAutolinking.cjs"],
  extra: { iosDnsSettingsEnabled: false },
};

const iosDnsConfig = {
  ...storeConfig,
  plugins: [...storeConfig.plugins, "./plugins/withIosDnsSettings.cjs"],
  extra: { iosDnsSettingsEnabled: true },
};

const easConfig = {
  cli: { version: ">= 16.0.0", appVersionSource: "remote", requireCommit: true },
  build: {
    development: { developmentClient: true, distribution: "internal" },
    preview: { distribution: "internal", android: { buildType: "apk" } },
    production: {
      autoIncrement: true,
      ios: { resourceClass: "m-medium", image: "sdk-57" },
      android: { buildType: "app-bundle", image: "sdk-57" },
    },
    "production-ios-dns": {
      autoIncrement: true,
      env: { DNSPILOT_IOS_DNS_SETTINGS: "1" },
      ios: { resourceClass: "m-medium", image: "sdk-57" },
    },
  },
};

test("accepts isolated Store and opt-in iOS DNS configs", () => {
  assert.doesNotThrow(() => assertStoreReleaseConfig(storeConfig));
  assert.doesNotThrow(() => assertIosDnsExperimentConfig(iosDnsConfig));
  assert.doesNotThrow(() => assertEasBuildProfiles(easConfig));
});

test("rejects Store config with restricted or development-only capability", () => {
  assert.throws(
    () => assertStoreReleaseConfig({
      ...storeConfig,
      ios: { ...storeConfig.ios, infoPlist: { NSLocalNetworkUsageDescription: "bridge" } },
      plugins: [...storeConfig.plugins, "expo-dev-client", "./plugins/withIosDnsSettings.cjs"],
      extra: { iosDnsSettingsEnabled: true },
    }),
    /Store release config/
  );
});

test("rejects malformed EAS production profiles", () => {
  assert.throws(
    () => assertEasBuildProfiles({ ...easConfig, cli: { ...easConfig.cli, requireCommit: false } }),
    /requireCommit/
  );
  assert.throws(
    () => assertEasBuildProfiles({
      ...easConfig,
      build: { ...easConfig.build, production: { ...easConfig.build.production, android: { buildType: "apk" } } },
    }),
    /app-bundle/
  );
});

test("accepts a minimal Android Store manifest", () => {
  assert.doesNotThrow(() => assertAndroidStoreManifest(`
    <manifest xmlns:android="http://schemas.android.com/apk/res/android">
      <uses-permission android:name="android.permission.INTERNET" />
      <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
      <application android:label="DNSPilot Mobile" />
    </manifest>
  `));
});

test("rejects forbidden Android Store permissions and runtime capabilities", () => {
  assert.throws(
    () => assertAndroidStoreManifest(`
      <uses-permission android:name="android.permission.INTERNET" />
      <uses-permission android:name="android.permission.BIND_VPN_SERVICE" />
      <service android:name="android.net.VpnService" />
    `),
    /Android Store manifest/
  );
});

test("rejects Android Store dex containing development client classes", () => {
  assert.doesNotThrow(() => assertAndroidStoreDex("Lexpo/modules/dnspilotruntime/DNSPilotRuntimeModule;"));
  assert.throws(
    () => assertAndroidStoreDex("Lexpo/modules/devlauncher/DevLauncherController;"),
    /Android Store dex/
  );
});
