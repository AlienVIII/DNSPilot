import { readFileSync } from "node:fs";

import { assertAndroidStoreManifest } from "../src/view-models/release-config-gate.js";

const manifestPath = process.argv[2];
if (!manifestPath) {
  throw new Error("Usage: node scripts/verify-android-release-manifest.mjs <merged-manifest-path>");
}

assertAndroidStoreManifest(readFileSync(manifestPath, "utf8"));
console.log("Android Store manifest capability gate verified");
