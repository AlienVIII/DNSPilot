import { spawnSync } from "node:child_process";

import { assertAuditResponseUsable, assertNoUnapprovedHighAuditFindings } from "../src/view-models/npm-audit-policy.js";

const result = spawnSync("npm", ["audit", "--omit=dev", "--json"], {
  cwd: process.cwd(),
  encoding: "utf8",
  shell: process.platform === "win32",
});

if (result.error) throw result.error;

let audit;
try {
  audit = JSON.parse(result.stdout);
} catch {
  throw new Error(`npm audit did not return JSON:\n${result.stderr || result.stdout}`);
}

assertAuditResponseUsable(audit);
assertNoUnapprovedHighAuditFindings(audit);
console.log("Production npm audit policy verified");
