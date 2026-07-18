import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

import {
  assertEasBuildProfiles,
  assertIosDnsExperimentConfig,
  assertStoreReleaseConfig,
} from "../src/view-models/release-config-gate.js";

function publicConfigFor(profile) {
  const result = spawnSync("npx", ["expo", "config", "--type", "public", "--json"], {
    cwd: process.cwd(),
    encoding: "utf8",
    env: { ...process.env, EAS_BUILD_PROFILE: profile },
    shell: process.platform === "win32",
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`${profile} Expo config failed:\n${result.stderr || result.stdout}`);
  }
  return JSON.parse(result.stdout);
}

const easConfig = JSON.parse(readFileSync(new URL("../eas.json", import.meta.url), "utf8"));
assertEasBuildProfiles(easConfig);
assertStoreReleaseConfig(publicConfigFor("production"));
assertIosDnsExperimentConfig(publicConfigFor("production-ios-dns"));
console.log("Store and optional iOS DNS config isolation verified");
