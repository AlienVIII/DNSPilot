const stepLabels = {
  prepare: "Prepare",
  dns: "DNS lookup",
  connect: "TCP connect",
  tls: "TLS handshake",
  save: "Save history",
};

export function buildBenchmarkDiagnostics({ mode, result, error, startedAtMs, endedAtMs }) {
  const elapsedMs = elapsed(startedAtMs, endedAtMs);
  if (error) {
    const reason = error instanceof Error ? error.message : String(error);
    return {
      status: "failed",
      elapsedMs,
      failedStepId: "prepare",
      reason,
      debugLog: reason,
      steps: makeSteps("prepare", scopeFromMode(mode), false),
      resolvers: [],
      report: makeReport({
        mode,
        status: "failed",
        elapsedMs,
        failedStepLabel: stepLabels.prepare,
        reason,
        resolvers: [],
        summary: undefined,
        warning: undefined,
        args: [],
      }),
    };
  }

  if (!result) {
    const scope = scopeFromMode(mode);
    return {
      status: "running",
      elapsedMs,
      failedStepId: undefined,
      reason: "Benchmark is running.",
      debugLog: "",
      steps: makeRunningSteps(scope),
      resolvers: [],
      report: makeReport({
        mode,
        status: "running",
        elapsedMs,
        failedStepLabel: "none",
        reason: "Benchmark is running.",
        resolvers: [],
        summary: { measurement_scope: scope, health: "running", recommended_profile_id: null },
        warning: undefined,
        args: [],
      }),
    };
  }

  const data = result?.data ?? {};
  const summary = data.summary ?? metricSummary(data);
  const progress = progressEvents(result);
  const scope = summary?.measurement_scope ?? data.scope ?? progressScope(progress) ?? scopeFromMode(mode);
  const resolvers = resolverRows(result);
  const args = result?.args ?? [];

  if (!summary && progress.length > 0) {
    const debugLog = args.length > 0 ? `dnspilot-cli ${args.join(" ")}` : "";
    return {
      status: "running",
      elapsedMs,
      failedStepId: undefined,
      reason: "Benchmark is running.",
      debugLog,
      steps: makeProgressSteps(scope, progress),
      resolvers,
      report: makeReport({
        mode,
        status: "running",
        elapsedMs,
        failedStepLabel: "none",
        reason: "Benchmark is running.",
        resolvers,
        summary: { measurement_scope: scope, health: "running", recommended_profile_id: null },
        warning: data.warning,
        args,
        progressCount: progress.length,
      }),
    };
  }

  const failedStepId = failedStepFor(summary);
  const status = failedStepId ? "failed" : result ? "success" : "running";
  const reason = reasonFor(summary, failedStepId);
  const debugLog = args.length > 0 ? `dnspilot-cli ${args.join(" ")}` : "";

  return {
    status,
    elapsedMs,
    failedStepId,
    reason,
    debugLog,
    steps: makeSteps(failedStepId, scope, Boolean(data.saved_history_id)),
    resolvers,
    report: makeReport({
      mode,
      status,
      elapsedMs,
      failedStepLabel: failedStepId ? stepLabels[failedStepId] : "none",
      reason,
      resolvers,
      summary,
      warning: data.warning,
      args,
      progressCount: progress.length,
    }),
  };
}

function elapsed(startedAtMs, endedAtMs) {
  if (!Number.isFinite(startedAtMs) || !Number.isFinite(endedAtMs)) {
    return undefined;
  }
  return Math.max(0, endedAtMs - startedAtMs);
}

function metricSummary(data) {
  if (!data?.metrics) {
    return undefined;
  }
  const metrics = data.metrics;
  return {
    measurement_scope: data.scope ?? "dns-only",
    health: metrics.failure_rate >= 1 ? "failed" : "healthy",
    primary_issue: metrics.failure_rate >= 1 ? "all-resolvers-failed" : "none",
    recommended_profile_id: metrics.profile_id,
  };
}

function scopeFromMode(mode) {
  if (mode === "pathCompare" || mode === "pathEstimate") {
    return "dns-tcp";
  }
  return "dns-only";
}

function failedStepFor(summary) {
  if (!summary || summary.health !== "failed") {
    return undefined;
  }
  if (summary.primary_issue === "no-connect-targets") {
    return "connect";
  }
  if (summary.measurement_scope === "dns-tcp-tls" && summary.primary_issue === "all-resolvers-failed") {
    return "dns";
  }
  return "dns";
}

function reasonFor(summary, failedStepId) {
  if (!failedStepId) {
    return summary?.recommended_profile_id
      ? `Recommended profile: ${summary.recommended_profile_id}.`
      : "Completed without a recommendation.";
  }
  if (failedStepId === "dns" && summary?.primary_issue === "all-resolvers-failed") {
    return "Every resolver failed during DNS lookup.";
  }
  if (failedStepId === "connect") {
    return "No usable TCP connect targets were produced.";
  }
  return summary?.safety_notes?.[0] ?? "Benchmark failed.";
}

function makeSteps(failedStepId, scope, savedHistory) {
  const usesConnect = scope === "dns-tcp" || scope === "dns-tcp-tls";
  const usesTls = scope === "dns-tcp-tls";
  const stepIds = ["prepare", "dns", "connect", "tls", "save"];
  return stepIds.map((id) => {
    let status = "idle";
    if (id === "prepare") {
      status = failedStepId === "prepare" ? "failed" : "success";
    } else if (id === "dns") {
      status = failedStepId === "dns" ? "failed" : failedStepId === "prepare" ? "idle" : "success";
    } else if (id === "connect") {
      status = usesConnect ? (failedStepId === "connect" ? "failed" : failedStepId ? "idle" : "success") : "idle";
    } else if (id === "tls") {
      status = usesTls ? (failedStepId === "tls" ? "failed" : failedStepId ? "idle" : "success") : "idle";
    } else if (id === "save") {
      status = savedHistory ? "success" : "idle";
    }
    return { id, label: stepLabels[id], status };
  });
}

function makeRunningSteps(_scope) {
  return [
    { id: "prepare", label: stepLabels.prepare, status: "success" },
    { id: "dns", label: stepLabels.dns, status: "running" },
    { id: "connect", label: stepLabels.connect, status: "idle" },
    { id: "tls", label: stepLabels.tls, status: "idle" },
    { id: "save", label: stepLabels.save, status: "idle" },
  ];
}

function makeProgressSteps(scope, progress) {
  const hasFinished = progress.some((event) => event?.type === "resolver_finished");
  const hasRunningResolver = progress.some((event, index) => {
    if (event?.type !== "resolver_started") {
      return false;
    }
    return !progress.slice(index + 1).some((later) => later?.type === "resolver_finished" && later.profile_id === event.profile_id);
  });
  const usesConnect = scope === "dns-tcp" || scope === "dns-tcp-tls";
  const usesTls = scope === "dns-tcp-tls";
  return [
    { id: "prepare", label: stepLabels.prepare, status: "success" },
    { id: "dns", label: stepLabels.dns, status: usesConnect && hasFinished ? "success" : "running" },
    {
      id: "connect",
      label: stepLabels.connect,
      status: usesConnect ? (hasRunningResolver || hasFinished ? "running" : "idle") : "idle",
    },
    { id: "tls", label: stepLabels.tls, status: usesTls ? "running" : "idle" },
    { id: "save", label: stepLabels.save, status: "idle" },
  ];
}

function resolverRows(result) {
  const progress = progressEvents(result);
  const latest = latestProgressByProfile(progress);

  const runs = Array.isArray(result?.data?.runs)
    ? result.data.runs
    : result?.data?.metrics
      ? [{ profile_id: result.data.metrics.profile_id, resolver: result.data.resolver, metrics: result.data.metrics }]
      : [];

  if (runs.length === 0 && latest.size > 0) {
    return [...latest.values()].map((event) => {
      const failureRate = number(event.failure_rate);
      const timeoutRate = number(event.timeout_rate);
      const status = event.type === "resolver_started" ? "running" : resolverStatus(failureRate, timeoutRate, event.status);
      return {
        profileId: event.profile_id,
        resolver: event.resolver,
        status,
        elapsedMs: number(event.elapsed_ms),
        failureRate,
        timeoutRate,
        diagnosis: diagnosis(status, failureRate, timeoutRate),
      };
    });
  }

  return runs.map((run) => {
    const metrics = run.metrics ?? {};
    const event = latest.get(run.profile_id) ?? {};
    const failureRate = number(metrics.failure_rate ?? event.failure_rate);
    const timeoutRate = number(metrics.timeout_rate ?? event.timeout_rate);
    const status = resolverStatus(failureRate, timeoutRate, event.status);
    return {
      profileId: run.profile_id,
      resolver: run.resolver,
      status,
      elapsedMs: number(event.elapsed_ms),
      failureRate,
      timeoutRate,
      diagnosis: diagnosis(status, failureRate, timeoutRate),
    };
  });
}

function progressEvents(result) {
  return Array.isArray(result?.progress) ? result.progress.filter(Boolean) : [];
}

function progressScope(progress) {
  for (let index = progress.length - 1; index >= 0; index -= 1) {
    if (progress[index]?.measurement_scope) {
      return progress[index].measurement_scope;
    }
  }
  return undefined;
}

function latestProgressByProfile(progress) {
  const latest = new Map();
  for (const event of progress) {
    if (event?.profile_id) {
      latest.set(event.profile_id, event);
    }
  }
  return latest;
}

function resolverStatus(failureRate, timeoutRate, eventStatus) {
  if (eventStatus === "running") {
    return "running";
  }
  if (eventStatus === "failed" || failureRate >= 1 || timeoutRate >= 1) {
    return "failed";
  }
  if (failureRate > 0 || timeoutRate > 0) {
    return "degraded";
  }
  return "success";
}

function diagnosis(status, failureRate, timeoutRate) {
  if (status === "running") {
    return "Measurement is running.";
  }
  if (status === "success") {
    return "Measured successfully.";
  }
  if (timeoutRate >= 1) {
    return "All samples timed out.";
  }
  if (failureRate >= 1) {
    return "All samples failed.";
  }
  return "Some samples failed or timed out.";
}

function number(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function makeReport({ mode, status, elapsedMs, failedStepLabel, reason, resolvers, summary, warning, args, progressCount = 0 }) {
  const lines = [
    "DNSPilot Mobile Benchmark Report",
    `Mode: ${mode}`,
    `Status: ${status}`,
    `Elapsed: ${elapsedMs === undefined ? "unknown" : `${elapsedMs} ms`}`,
    `Scope: ${summary?.measurement_scope ?? "unknown"}`,
    `Health: ${summary?.health ?? "unknown"}`,
    `Recommended profile: ${summary?.recommended_profile_id ?? "none"}`,
    `Failed step: ${failedStepLabel}`,
    `Reason: ${reason}`,
    `Progress events: ${progressCount}`,
    "Resolvers:",
    ...resolvers.map(
      (resolver) =>
        `- ${resolver.profileId} ${resolver.resolver ?? ""} ${resolver.status} failure=${resolver.failureRate ?? "unknown"} timeout=${resolver.timeoutRate ?? "unknown"}`
    ),
    `Warning: ${warning ?? "none"}`,
    `Debug: ${args.length > 0 ? `dnspilot-cli ${args.join(" ")}` : "none"}`,
  ];
  return lines.join("\n");
}
