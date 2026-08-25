const { spawn } = require('node:child_process');

const port = process.env.PORT || process.env.EXPO_PORT || '8081';
const host = process.env.EXPO_HOST || 'localhost';
const publicDomain =
  process.env.EXPO_PUBLIC_DOMAIN ||
  process.env.REPLIT_DEV_DOMAIN ||
  `localhost:${port}`;

const environment = {
  ...process.env,
  EXPO_PUBLIC_DOMAIN: publicDomain,
};

if (!environment.EXPO_PUBLIC_REPL_ID && process.env.REPL_ID) {
  environment.EXPO_PUBLIC_REPL_ID = process.env.REPL_ID;
}

if (
  !environment.EXPO_PACKAGER_PROXY_URL &&
  process.env.REPLIT_EXPO_DEV_DOMAIN
) {
  environment.EXPO_PACKAGER_PROXY_URL = `https://${process.env.REPLIT_EXPO_DEV_DOMAIN}`;
}

if (!environment.REACT_NATIVE_PACKAGER_HOSTNAME && host === 'localhost') {
  environment.REACT_NATIVE_PACKAGER_HOSTNAME = 'localhost';
}

const command = process.platform === 'win32' ? 'pnpm.cmd' : 'pnpm';
const child = spawn(
  command,
  ['exec', 'expo', 'start', '--host', host, '--port', port],
  {
    cwd: process.cwd(),
    env: environment,
    stdio: 'inherit',
  },
);

child.on('error', (error) => {
  console.error(`Unable to start Expo: ${error.message}`);
  process.exitCode = 1;
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    if (!child.killed) {
      child.kill(signal);
    }
  });
}

child.on('exit', (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
  } else {
    process.exitCode = code ?? 1;
  }
});