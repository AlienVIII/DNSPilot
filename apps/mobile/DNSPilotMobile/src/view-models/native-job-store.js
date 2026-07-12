export function createNativeJobStore({ run, now = () => new Date().toISOString() } = {}) {
  if (typeof run !== 'function') {
    throw new Error('A native job runner is required.');
  }

  let sequence = 0;
  const jobs = new Map();

  function snapshot(job) {
    if (!job) return undefined;
    return {
      ...job,
      progress: [...job.progress],
      error: job.error ? { ...job.error } : null,
    };
  }

  return {
    start(action, payload = {}) {
      const id = `native-job-${Date.now()}-${++sequence}`;
      const job = {
        id,
        action,
        status: 'running',
        started_at: now(),
        ended_at: null,
        progress: [],
        result: null,
        error: null,
      };
      jobs.set(id, job);

      void run(action, payload).then(
        (result) => {
          job.status = 'success';
          job.ended_at = now();
          job.result = result;
          job.progress = Array.isArray(result?.progress) ? result.progress : [];
        },
        (caught) => {
          job.status = 'failed';
          job.ended_at = now();
          job.error = { message: caught instanceof Error ? caught.message : String(caught) };
        }
      );
      return snapshot(job);
    },
    get(id) {
      return snapshot(jobs.get(id));
    },
  };
}
