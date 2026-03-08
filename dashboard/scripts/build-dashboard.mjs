import { execFileSync } from 'node:child_process';
import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const dashboardDir = path.resolve(scriptDir, '..');
const outDir = path.join(dashboardDir, 'out');
const distDir = path.join(dashboardDir, 'dist');
const nextBin = path.join(dashboardDir, 'node_modules', 'next', 'dist', 'bin', 'next');

function runCommand(command, args) {
  try {
    return execFileSync(command, args, {
      cwd: dashboardDir,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return '';
  }
}

function readPackageVersion() {
  const packageJson = JSON.parse(readFileSync(path.join(dashboardDir, 'package.json'), 'utf8'));
  return typeof packageJson.version === 'string' ? packageJson.version : '0.0.0';
}

const gitVersion = process.env.NEXT_PUBLIC_LIFE_TOOLS_DASHBOARD_GIT_VERSION?.trim() || runCommand('git', ['rev-parse', '--short=12', 'HEAD']) || 'unknown';
const buildTime = process.env.NEXT_PUBLIC_LIFE_TOOLS_DASHBOARD_BUILD_TIME?.trim() || new Date().toISOString();
const packageVersion = readPackageVersion();

execFileSync(process.execPath, [nextBin, 'build'], {
  cwd: dashboardDir,
  stdio: 'inherit',
  env: {
    ...process.env,
    NEXT_PUBLIC_LIFE_TOOLS_DASHBOARD_GIT_VERSION: gitVersion,
    NEXT_PUBLIC_LIFE_TOOLS_DASHBOARD_BUILD_TIME: buildTime,
  },
});

mkdirSync(outDir, { recursive: true });
writeFileSync(
  path.join(outDir, 'dashboard-version.json'),
  `${JSON.stringify({ gitVersion, buildTime, packageVersion }, null, 2)}\n`,
  'utf8',
);

rmSync(distDir, { recursive: true, force: true });
cpSync(outDir, distDir, { recursive: true });
