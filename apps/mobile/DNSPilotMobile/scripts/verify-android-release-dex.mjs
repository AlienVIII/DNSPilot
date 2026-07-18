import { stdin } from "node:process";

import { assertAndroidStoreDex } from "../src/view-models/release-config-gate.js";

let source = "";
stdin.setEncoding("utf8");
stdin.on("data", (chunk) => {
  source += chunk;
});
stdin.on("end", () => {
  assertAndroidStoreDex(source);
  console.log("Android Store dex development-module gate verified");
});
