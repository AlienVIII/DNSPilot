import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { mkdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const repoRoot = path.resolve(appRoot, "../../..");
const dataDir = path.join(appRoot, ".dnspilot");
const defaultDbPath = process.env.DNSPILOT_MOBILE_DB ?? path.join(dataDir, "dnspilot.sqlite");
const port = Number(process.env.DNSPILOT_MOBILE_BRIDGE_PORT ?? 8787);

const platforms = new Set([
  "ios",
  "android-play",
  "macos-store",
  "windows-store",
  "linux-flatpak",
  "linux-snap",
  "linux-native-power",
  "macos-power",
  "windows-power",
]);
const preflightScopes = new Set(["direct-resolver-benchmark", "system-dns-validation"]);
const protocols = new Set(["plain", "doh", "dot"]);
const filteringTypes = new Set(["none", "malware", "family", "ads", "security"]);
const ipFamilies = new Set(["both", "ipv4-only", "ipv6-only"]);
const confidenceValues = new Set(["high", "medium", "low", "inconclusive"]);
const gateHealthValues = new Set(["healthy", "degraded", "failed", "inconclusive"]);

function enumValue(value, allowed, fallback) {
  const normalized = String(value ?? fallback).trim();
  if (!allowed.has(normalized)) {
    throw new Error(`Invalid value '${normalized}'`);
  }
  return normalized;
}

function maybeString(value) {
  if (value === undefined || value === null) {
    return undefined;
  }
  const text = String(value).trim();
  return text.length > 0 ? text : undefined;
}

function stringValue(value, fallback) {
  return maybeString(value) ?? fallback;
}

function stringList(value) {
  if (Array.isArray(value)) {
    return value.map((item) => maybeString(item)).filter(Boolean);
  }
  const text = maybeString(value);
  if (!text) {
    return [];
  }
  return text
    .split(/[\n,]/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function positiveInt(value, fallback) {
  const number = Number(value ?? fallback);
  if (!Number.isInteger(number) || number < 1) {
    throw new Error(`Expected positive integer, got '${value}'`);
  }
  return String(number);
}

function add(args, flag, value) {
  const text = maybeString(value);
  if (text) {
    args.push(flag, text);
  }
}

function addRepeated(args, flag, values) {
  for (const value of stringList(values)) {
    args.push(flag, value);
  }
}

function addEnvironmentFlags(args, payload) {
  const environment = payload.environment ?? payload;
  if (environment.vpnActive) args.push("--vpn-active");
  if (environment.mdmProfileActive) args.push("--mdm-profile-active");
  if (environment.corporateDnsDetected) args.push("--corporate-dns-detected");
  if (environment.captivePortalDetected) args.push("--captive-portal-detected");
}

function addDomains(args, payload, dbPath) {
  addRepeated(args, "--domain", payload.domains);
  const suiteId = maybeString(payload.suiteId);
  if (suiteId) {
    args.push("--suite-db", dbPath, "--suite-id", suiteId);
  }
}

function addRunSettings(args, payload) {
  args.push("--attempts", positiveInt(payload.attempts, 1));
  args.push("--ip-family", enumValue(payload.ipFamily, ipFamilies, "both"));
}

function addSaveHistory(args, payload, dbPath) {
  if (payload.saveHistory) {
    args.push("--save-db", dbPath);
    add(args, "--history-id", payload.historyId);
  }
}

function addProfileCommandArgs(args, payload, dbPath) {
  args.push("--db", dbPath);
  args.push("--id", stringValue(payload.id, ""));
  args.push("--name", stringValue(payload.name, ""));
  args.push("--protocol", enumValue(payload.protocol, protocols, "plain"));
  addRepeated(args, "--ipv4", payload.ipv4Servers);
  addRepeated(args, "--ipv6", payload.ipv6Servers);
  add(args, "--doh-url", payload.dohUrl);
  add(args, "--dot-hostname", payload.dotHostname);
  args.push("--filtering", enumValue(payload.filtering, filteringTypes, "none"));
  addRepeated(args, "--tag", payload.tags);
}

function addSuiteCommandArgs(args, payload, dbPath) {
  args.push("--db", dbPath);
  args.push("--id", stringValue(payload.id, ""));
  args.push("--name", stringValue(payload.name, ""));
  addRepeated(args, "--domain", payload.domains);
  addRepeated(args, "--tag", payload.tags);
}

function addResolverInputs(args, payload, dbPath) {
  addRepeated(args, "--resolver", payload.resolverSpecs ?? payload.resolvers);
  const profileIds = stringList(payload.profileIds);
  if (profileIds.length > 0) {
    args.push("--profile-db", dbPath);
    addRepeated(args, "--profile-id", profileIds);
  }
  add(args, "--resolver-port", payload.resolverPort);
}

function addSingleResolverInput(args, payload, dbPath) {
  add(args, "--resolver", payload.resolver);
  args.push("--profile-db", dbPath);
  add(args, "--profile-id", payload.profileId ?? "cloudflare");
  add(args, "--resolver-port", payload.resolverPort);
}

export function buildCliArgs(action, payload = {}, dbPath = defaultDbPath) {
  switch (action) {
    case "catalog":
      return ["catalog"];
    case "capabilities":
      return ["capabilities"];
    case "capability":
      return ["capability", enumValue(payload.platform, platforms, "ios")];
    case "preflight":
      return [
        "preflight",
        enumValue(payload.platform, platforms, "ios"),
        "--scope",
        enumValue(payload.scope, preflightScopes, "direct-resolver-benchmark"),
      ];
    case "applyPolicy": {
      const args = ["apply-policy", enumValue(payload.platform, platforms, "ios")];
      addEnvironmentFlags(args, payload);
      return args;
    }
    case "applyPlan": {
      const args = ["apply-plan", enumValue(payload.platform, platforms, "ios"), "--profile-db", dbPath];
      add(args, "--profile-id", payload.profileId);
      add(args, "--tested-resolver", payload.testedResolver);
      args.push("--confidence", enumValue(payload.confidence, confidenceValues, "high"));
      args.push("--gate-health", enumValue(payload.gateHealth, gateHealthValues, "healthy"));
      addEnvironmentFlags(args, payload);
      return args;
    }
    case "storageSmoke":
      return ["storage-smoke", "--db", dbPath];
    case "profileList":
      return ["profile-list", "--db", dbPath];
    case "profileAdd": {
      const args = ["profile-add"];
      addProfileCommandArgs(args, payload, dbPath);
      return args;
    }
    case "profileUpdate": {
      const args = ["profile-update"];
      addProfileCommandArgs(args, payload, dbPath);
      return args;
    }
    case "profileDelete":
      return ["profile-delete", "--db", dbPath, "--id", stringValue(payload.id, "")];
    case "suiteList":
      return ["suite-list", "--db", dbPath];
    case "suiteAdd": {
      const args = ["suite-add"];
      addSuiteCommandArgs(args, payload, dbPath);
      return args;
    }
    case "suiteUpdate": {
      const args = ["suite-update"];
      addSuiteCommandArgs(args, payload, dbPath);
      return args;
    }
    case "suiteDelete":
      return ["suite-delete", "--db", dbPath, "--id", stringValue(payload.id, "")];
    case "historyList":
      return ["history-list", "--db", dbPath];
    case "historyDelete":
      return ["history-delete", "--db", dbPath, "--id", stringValue(payload.id, "")];
    case "historyClear":
      return ["history-clear", "--db", dbPath];
    case "recommendSample":
      return ["recommend-sample"];
    case "benchmark": {
      const args = ["benchmark"];
      addSingleResolverInput(args, payload, dbPath);
      addDomains(args, payload, dbPath);
      addRunSettings(args, payload);
      args.push("--timeout-ms", positiveInt(payload.timeoutMs, 800));
      addSaveHistory(args, payload, dbPath);
      return args;
    }
    case "systemBenchmark": {
      const args = ["system-benchmark", "--platform", enumValue(payload.platform, platforms, "ios")];
      addDomains(args, payload, dbPath);
      addRunSettings(args, payload);
      args.push("--timeout-ms", positiveInt(payload.timeoutMs, 800));
      return args;
    }
    case "compare": {
      const args = ["compare"];
      addResolverInputs(args, payload, dbPath);
      addDomains(args, payload, dbPath);
      addRunSettings(args, payload);
      args.push("--timeout-ms", positiveInt(payload.timeoutMs, 800));
      addSaveHistory(args, payload, dbPath);
      args.push("--progress-jsonl");
      return args;
    }
    case "pathEstimate": {
      const args = ["path-estimate"];
      addSingleResolverInput(args, payload, dbPath);
      addDomains(args, payload, dbPath);
      addRunSettings(args, payload);
      args.push("--dns-timeout-ms", positiveInt(payload.dnsTimeoutMs, payload.timeoutMs ?? 800));
      args.push("--connect-timeout-ms", positiveInt(payload.connectTimeoutMs, 1000));
      args.push("--connect-port", positiveInt(payload.connectPort, 443));
      args.push("--max-connect-targets-per-domain", positiveInt(payload.maxConnectTargetsPerDomain, 4));
      add(args, "--tls-handshake-timeout-ms", payload.tlsHandshakeTimeoutMs);
      return args;
    }
    case "pathCompare": {
      const args = ["path-compare"];
      addResolverInputs(args, payload, dbPath);
      addDomains(args, payload, dbPath);
      addRunSettings(args, payload);
      args.push("--dns-timeout-ms", positiveInt(payload.dnsTimeoutMs, payload.timeoutMs ?? 800));
      args.push("--connect-timeout-ms", positiveInt(payload.connectTimeoutMs, 1000));
      args.push("--connect-port", positiveInt(payload.connectPort, 443));
      args.push("--max-connect-targets-per-domain", positiveInt(payload.maxConnectTargetsPerDomain, 4));
      add(args, "--tls-handshake-timeout-ms", payload.tlsHandshakeTimeoutMs);
      addSaveHistory(args, payload, dbPath);
      args.push("--progress-jsonl");
      return args;
    }
    default:
      throw new Error(`Unsupported action '${action}'`);
  }
}

function parseProgress(stderr) {
  return stderr
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      try {
        return JSON.parse(line);
      } catch {
        return undefined;
      }
    })
    .filter(Boolean);
}

function parseProgressLine(line) {
  try {
    return JSON.parse(line);
  } catch {
    return undefined;
  }
}

export async function runCliJob(action, payload = {}, dbPath = defaultDbPath, { onProgress } = {}) {
  await mkdir(path.dirname(dbPath), { recursive: true });
  const cliArgs = buildCliArgs(action, payload, dbPath);
  const childArgs = ["run", "--quiet", "--package", "dnspilot-cli", "--", ...cliArgs];
  const progress = [];

  const { stdout, stderr, code } = await new Promise((resolve, reject) => {
    const child = spawn("cargo", childArgs, { cwd: repoRoot });
    let stdout = "";
    let stderr = "";
    let stderrLineBuffer = "";
    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on("data", (chunk) => {
      const text = chunk.toString();
      stderr += text;
      stderrLineBuffer += text;
      const lines = stderrLineBuffer.split(/\r?\n/);
      stderrLineBuffer = lines.pop() ?? "";
      for (const line of lines) {
        const event = parseProgressLine(line.trim());
        if (event) {
          progress.push(event);
          onProgress?.(event);
        }
      }
    });
    child.on("error", reject);
    child.on("close", (code) => {
      const event = parseProgressLine(stderrLineBuffer.trim());
      if (event) {
        progress.push(event);
        onProgress?.(event);
      }
      resolve({ stdout, stderr, code });
    });
  });

  if (code !== 0) {
    const error = new Error(stderr.trim() || stdout.trim() || `dnspilot-cli exited ${code}`);
    error.statusCode = 422;
    error.details = { code, stdout: stdout.slice(0, 4000), stderr: stderr.slice(0, 4000), args: cliArgs };
    throw error;
  }

  let data = null;
  const trimmed = stdout.trim();
  if (trimmed.length > 0) {
    data = JSON.parse(trimmed);
  }

  return {
    ok: true,
    action,
    args: cliArgs,
    data,
    progress: progress.length > 0 ? progress : parseProgress(stderr),
  };
}

export async function runCli(action, payload = {}, dbPath = defaultDbPath) {
  return runCliJob(action, payload, dbPath);
}

export function createJobStore({ runCommand = runCliJob } = {}) {
  let nextId = 1;
  const jobs = new Map();

  function snapshot(job) {
    return {
      id: job.id,
      action: job.action,
      status: job.status,
      started_at: job.started_at,
      ended_at: job.ended_at,
      progress: [...job.progress],
      result: job.result,
      error: job.error,
    };
  }

  return {
    start(action, payload = {}, dbPath = defaultDbPath) {
      const id = `job-${Date.now()}-${nextId++}`;
      const job = {
        id,
        action,
        status: "running",
        started_at: new Date().toISOString(),
        ended_at: null,
        progress: [],
        result: null,
        error: null,
      };
      jobs.set(id, job);
      const done = runCommand(action, payload, dbPath, {
        onProgress(event) {
          job.progress.push(event);
        },
      })
        .then((result) => {
          job.status = "success";
          job.ended_at = new Date().toISOString();
          job.result = {
            ...result,
            progress: result.progress?.length ? result.progress : [...job.progress],
          };
          return job.result;
        })
        .catch((error) => {
          job.status = "failed";
          job.ended_at = new Date().toISOString();
          job.error = {
            message: error.message ?? String(error),
            details: error.details,
          };
          throw error;
        });
      done.catch(() => {});
      return { ...snapshot(job), done };
    },
    get(id) {
      const job = jobs.get(id);
      return job ? snapshot(job) : null;
    },
  };
}

async function readBody(request) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 1024 * 1024) {
      throw new Error("Request body is too large");
    }
    chunks.push(chunk);
  }
  const text = Buffer.concat(chunks).toString("utf8");
  return text ? JSON.parse(text) : {};
}

function send(response, statusCode, body) {
  response.writeHead(statusCode, {
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET,POST,OPTIONS",
    "access-control-allow-headers": "content-type",
    "content-type": "application/json; charset=utf-8",
  });
  response.end(JSON.stringify(body, null, 2));
}

export function createBridgeServer(jobStore = createJobStore()) {
  return createServer(async (request, response) => {
    try {
      if (request.method === "OPTIONS") {
        send(response, 204, {});
        return;
      }

      const url = new URL(request.url ?? "/", "http://localhost");
      if (request.method === "GET" && url.pathname === "/health") {
        send(response, 200, {
          ok: true,
          service: "dnspilot-mobile-bridge",
          repoRoot,
          dbPath: defaultDbPath,
        });
        return;
      }

      if (request.method === "POST" && url.pathname === "/api/cli") {
        const body = await readBody(request);
        const result = await runCli(body.action, body.payload ?? {}, body.dbPath ?? defaultDbPath);
        send(response, 200, result);
        return;
      }

      if (request.method === "POST" && url.pathname === "/api/jobs") {
        const body = await readBody(request);
        const started = jobStore.start(body.action, body.payload ?? {}, body.dbPath ?? defaultDbPath);
        send(response, 202, { ok: true, job: jobStore.get(started.id) });
        return;
      }

      const jobMatch = url.pathname.match(/^\/api\/jobs\/([^/]+)$/);
      if (request.method === "GET" && jobMatch) {
        const job = jobStore.get(jobMatch[1]);
        if (!job) {
          send(response, 404, { ok: false, error: "Job not found" });
          return;
        }
        send(response, 200, { ok: true, job });
        return;
      }

      send(response, 404, { ok: false, error: "Not found" });
    } catch (error) {
      send(response, error.statusCode ?? 400, {
        ok: false,
        error: error.message,
        details: error.details,
      });
    }
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await mkdir(dataDir, { recursive: true });
  createBridgeServer().listen(port, "0.0.0.0", () => {
    console.log(`DNSPilot mobile bridge listening on http://localhost:${port}`);
    console.log(`SQLite DB: ${defaultDbPath}`);
  });
}
