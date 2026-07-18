import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { mkdir } from "node:fs/promises";
import { networkInterfaces } from "node:os";
import path from "node:path";
import { randomBytes } from "node:crypto";
import { fileURLToPath, pathToFileURL } from "node:url";

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const repoRoot = path.resolve(appRoot, "../../..");
const dataDir = path.join(appRoot, ".dnspilot");
const defaultDbPath = path.join(dataDir, "dnspilot.sqlite");
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

export function createBridgeConfig(environment = process.env) {
  const lan = environment.DNSPILOT_MOBILE_BRIDGE_LAN === "1";
  const allowedOrigins = String(environment.DNSPILOT_MOBILE_BRIDGE_ORIGINS ?? "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);
  return {
    lan,
    token: lan ? environment.DNSPILOT_MOBILE_BRIDGE_TOKEN || randomBytes(32).toString("base64url") : null,
    allowedOrigins,
  };
}

export function bridgeUrls(portValue = port, interfaces = networkInterfaces(), { lan = false } = {}) {
  const urls = new Set([`http://localhost:${portValue}`]);
  if (!lan) {
    return [...urls];
  }
  for (const entries of Object.values(interfaces)) {
    for (const entry of entries ?? []) {
      if (!entry?.internal && isPrivateIpv4(entry.address, entry.family)) {
        urls.add(`http://${entry.address}:${portValue}`);
      }
    }
  }
  return [...urls];
}

function isPrivateIpv4(address, family) {
  if (family !== "IPv4" && family !== 4) {
    return false;
  }
  const octets = String(address ?? "").split(".").map(Number);
  if (octets.length !== 4 || octets.some((value) => !Number.isInteger(value) || value < 0 || value > 255)) {
    return false;
  }
  return (
    octets[0] === 10 ||
    (octets[0] === 172 && octets[1] >= 16 && octets[1] <= 31) ||
    (octets[0] === 192 && octets[1] === 168)
  );
}

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

export async function runCliJob(action, payload = {}, dbPath = defaultDbPath, { onProgress, signal } = {}) {
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
    const abort = () => child.kill();
    if (signal?.aborted) {
      abort();
    }
    signal?.addEventListener("abort", abort, { once: true });
    child.on("error", (error) => {
      signal?.removeEventListener("abort", abort);
      reject(error);
    });
    child.on("close", (code) => {
      signal?.removeEventListener("abort", abort);
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

export function createJobStore({ runCommand = runCliJob, maxRunning = 2, maxJobs = 32 } = {}) {
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

  function trimCompletedJobs() {
    while (jobs.size >= maxJobs) {
      const completed = [...jobs.values()].find((job) => job.status !== "running");
      if (!completed) {
        break;
      }
      jobs.delete(completed.id);
    }
  }

  return {
    start(action, payload = {}, dbPath = defaultDbPath) {
      const runningCount = [...jobs.values()].filter((job) => job.status === "running").length;
      if (runningCount >= maxRunning) {
        const error = new Error("Too many bridge jobs are already running");
        error.statusCode = 429;
        throw error;
      }
      trimCompletedJobs();
      const id = `job-${Date.now()}-${nextId++}`;
      const controller = new AbortController();
      const job = {
        id,
        action,
        status: "running",
        started_at: new Date().toISOString(),
        ended_at: null,
        progress: [],
        result: null,
        error: null,
        controller,
      };
      jobs.set(id, job);
      const done = runCommand(action, payload, dbPath, {
          signal: controller.signal,
          onProgress(event) {
            if (job.status === "running") {
              job.progress.push(event);
            }
          },
        })
        .then((result) => {
          if (job.status === "cancelled") {
            return null;
          }
          job.status = "success";
          job.ended_at = new Date().toISOString();
          job.result = {
            ...result,
            progress: result.progress?.length ? result.progress : [...job.progress],
          };
          return job.result;
        })
        .catch((error) => {
          if (job.status === "cancelled") {
            throw error;
          }
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
    cancel(id) {
      const job = jobs.get(id);
      if (!job || job.status !== "running") {
        return false;
      }
      job.status = "cancelled";
      job.ended_at = new Date().toISOString();
      job.error = { message: "Cancelled" };
      job.controller.abort();
      return true;
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

function requestOrigin(request, security) {
  const origin = request.headers.origin;
  if (!origin) {
    return null;
  }
  if (!security.lan) {
    try {
      const hostname = new URL(origin).hostname;
      return hostname === "localhost" || hostname === "127.0.0.1" ? origin : false;
    } catch {
      return false;
    }
  }
  return security.allowedOrigins.includes(origin) ? origin : false;
}

function requestAuthorized(request, security) {
  if (!security.lan) {
    return true;
  }
  const authorization = request.headers.authorization ?? "";
  return authorization === `Bearer ${security.token}`;
}

function send(response, statusCode, body, origin) {
  const headers = {
    "access-control-allow-methods": "GET,POST,DELETE,OPTIONS",
    "access-control-allow-headers": "authorization,content-type",
    "content-type": "application/json; charset=utf-8",
  };
  if (origin) {
    headers["access-control-allow-origin"] = origin;
    headers.vary = "Origin";
  }
  response.writeHead(statusCode, headers);
  response.end(JSON.stringify(body, null, 2));
}

function publicResult(result, dbPath) {
  return {
    ...result,
    args: (result.args ?? []).map((arg) => (arg === dbPath ? "<app-data>" : arg)),
  };
}

function publicJob(job, dbPath) {
  return {
    ...job,
    result: job.result ? publicResult(job.result, dbPath) : job.result,
    error: job.error ? { message: job.error.message ?? "Bridge job failed" } : job.error,
  };
}

export function createBridgeServer(jobStore = createJobStore(), { dbPath = defaultDbPath, security = createBridgeConfig() } = {}) {
  return createServer(async (request, response) => {
    const origin = requestOrigin(request, security);
    try {
      if (origin === false) {
        send(response, 403, { ok: false, error: "Origin is not allowed" }, null);
        return;
      }
      if (request.method === "OPTIONS") {
        send(response, 204, {}, origin);
        return;
      }
      if (!requestAuthorized(request, security)) {
        send(response, 401, { ok: false, error: "Bridge authorization required" }, origin);
        return;
      }

      const url = new URL(request.url ?? "/", "http://localhost");
      if (request.method === "GET" && url.pathname === "/health") {
        send(response, 200, {
          ok: true,
          service: "dnspilot-mobile-bridge",
          mode: security.lan ? "lan" : "loopback",
        }, origin);
        return;
      }

      if (request.method === "POST" && url.pathname === "/api/cli") {
        const body = await readBody(request);
        const result = await runCli(body.action, body.payload ?? {}, dbPath);
        send(response, 200, publicResult(result, dbPath), origin);
        return;
      }

      if (request.method === "POST" && url.pathname === "/api/jobs") {
        const body = await readBody(request);
        const started = jobStore.start(body.action, body.payload ?? {}, dbPath);
        send(response, 202, { ok: true, job: publicJob(jobStore.get(started.id), dbPath) }, origin);
        return;
      }

      const jobMatch = url.pathname.match(/^\/api\/jobs\/([^/]+)$/);
      if (request.method === "GET" && jobMatch) {
        const job = jobStore.get(jobMatch[1]);
        if (!job) {
          send(response, 404, { ok: false, error: "Job not found" }, origin);
          return;
        }
        send(response, 200, { ok: true, job: publicJob(job, dbPath) }, origin);
        return;
      }

      if (request.method === "DELETE" && jobMatch) {
        if (!jobStore.cancel(jobMatch[1])) {
          send(response, 404, { ok: false, error: "Job not found or already finished" }, origin);
          return;
        }
        send(response, 202, { ok: true, job: publicJob(jobStore.get(jobMatch[1]), dbPath) }, origin);
        return;
      }

      send(response, 404, { ok: false, error: "Not found" }, origin);
    } catch (error) {
      send(response, error.statusCode ?? 400, {
        ok: false,
        error: "Bridge request failed",
      }, origin === false ? null : origin);
    }
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const security = createBridgeConfig();
  const host = security.lan ? "0.0.0.0" : "127.0.0.1";
  await mkdir(dataDir, { recursive: true });
  createBridgeServer(undefined, { security }).listen(port, host, () => {
    console.log(`DNSPilot mobile bridge listening on ${host}:${port}`);
    for (const url of bridgeUrls(port, networkInterfaces(), security)) {
      console.log(`Bridge URL: ${url}`);
    }
    if (security.lan) {
      console.log(`Bridge bearer token: ${security.token}`);
    }
  });
}
