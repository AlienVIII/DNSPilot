import assert from 'node:assert/strict';
import test from 'node:test';

import { createNativeJobStore } from './native-job-store.js';

test('native jobs expose running then successful snapshots', async () => {
  let finish;
  const store = createNativeJobStore({
    run: () => new Promise((resolve) => {
      finish = resolve;
    }),
    now: () => '2026-07-11T00:00:00.000Z',
  });

  const started = store.start('compare', { profileIds: ['cloudflare'] });
  assert.equal(started.status, 'running');
  assert.equal(store.get(started.id)?.status, 'running');

  finish({ ok: true, action: 'compare', args: ['native', 'compare'], data: {}, progress: [] });
  await Promise.resolve();
  assert.equal(store.get(started.id)?.status, 'success');
});

test('native jobs preserve a structured error when the runtime fails', async () => {
  const store = createNativeJobStore({
    run: async () => {
      throw new Error('Native DNS query failed');
    },
    now: () => '2026-07-11T00:00:00.000Z',
  });

  const started = store.start('compare');
  await Promise.resolve();
  assert.equal(store.get(started.id)?.status, 'failed');
  assert.equal(store.get(started.id)?.error?.message, 'Native DNS query failed');
});
