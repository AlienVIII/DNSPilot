const nativeActions = new Set([
  "catalog",
  "capabilities",
  "capability",
  "preflight",
  "applyPolicy",
  "applyPlan",
  "recommendSample",
  "storageSmoke",
  "profileList",
  "profileAdd",
  "profileUpdate",
  "profileDelete",
  "suiteList",
  "suiteAdd",
  "suiteUpdate",
  "suiteDelete",
  "historyList",
  "historyDelete",
  "historyClear",
  "benchmark",
  "compare",
  "systemBenchmark",
  "pathEstimate",
  "pathCompare",
]);

export function actionTransport({ action, nativeAvailable = false } = {}) {
  return nativeAvailable && nativeActions.has(action) ? "native" : "bridge";
}
