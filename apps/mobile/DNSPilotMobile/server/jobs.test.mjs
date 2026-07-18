import assert from "node:assert/strict";
import { test } from "node:test";

import { createJobStore } from "./dev-server.mjs";

test("job store exposes running progress before final result", async () => {
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  const store = createJobStore({
    runCommand: async (_action, _payload, _dbPath, { onProgress }) => {
      onProgress({ type: "resolver_started", profile_id: "cloudflare", index: 1, total: 2 });
      await gate;
      onProgress({ type: "resolver_finished", profile_id: "cloudflare", status: "success", index: 1, total: 2 });
      return {
        ok: true,
        action: "compare",
        args: ["compare", "--profile-id", "cloudflare"],
        data: { summary: { health: "healthy", recommended_profile_id: "cloudflare" } },
        progress: [],
      };
    },
  });

  const started = store.start("compare", { profileIds: ["cloudflare"] }, "/tmp/dnspilot-job.sqlite");
  assert.equal(started.status, "running");
  assert.equal(store.get(started.id).progress.length, 1);

  release();
  await started.done;

  const done = store.get(started.id);
  assert.equal(done.status, "success");
  assert.equal(done.progress.length, 2);
  assert.equal(done.result.data.summary.recommended_profile_id, "cloudflare");
});

test("job store records failed command details", async () => {
  const store = createJobStore({
    runCommand: async () => {
      const error = new Error("invalid --domain 'bad domain'");
      error.details = { stderr: "invalid --domain 'bad domain'" };
      throw error;
    },
  });

  const started = store.start("compare", { domains: ["bad domain"] }, "/tmp/dnspilot-job.sqlite");
  await assert.rejects(started.done, /invalid --domain/);

  const failed = store.get(started.id);
  assert.equal(failed.status, "failed");
  assert.equal(failed.error.message, "invalid --domain 'bad domain'");
  assert.match(failed.error.details.stderr, /bad domain/);
});

test("job store bounds concurrent work and preserves cancellation", async () => {
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  const store = createJobStore({
    maxRunning: 1,
    runCommand: async (_action, _payload, _dbPath, { signal }) => {
      await Promise.race([
        gate,
        new Promise((_, reject) => signal.addEventListener("abort", () => reject(new Error("aborted")), { once: true })),
      ]);
      return { ok: true, action: "compare", args: [], data: {} };
    },
  });

  const started = store.start("compare", {}, "/tmp/dnspilot-job.sqlite");
  assert.throws(() => store.start("compare", {}, "/tmp/dnspilot-job.sqlite"), /Too many bridge jobs/);
  assert.equal(store.cancel(started.id), true);
  await assert.rejects(started.done, /aborted/);
  assert.equal(store.get(started.id).status, "cancelled");
  release();
});
