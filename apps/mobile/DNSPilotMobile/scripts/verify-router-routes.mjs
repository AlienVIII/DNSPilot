import { spawnSync } from 'node:child_process';

import { assertNoUnresolvedExpoRoutes } from '../src/view-models/router-route-gate.js';

const result = spawnSync('npx', ['expo', 'export', '--platform', 'web'], {
  cwd: process.cwd(),
  encoding: 'utf8',
  shell: process.platform === 'win32',
});
const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
process.stdout.write(output);

try {
  assertNoUnresolvedExpoRoutes(output);
} catch (error) {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
}

if (result.error) {
  process.stderr.write(`${result.error.message}\n`);
  process.exitCode = 1;
} else if (result.status !== 0) {
  process.exitCode = result.status ?? 1;
}
