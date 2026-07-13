#!/usr/bin/env node
// Lark Docs login / cookie refresh.
//
//   node auth.mjs
//
// Launches a dedicated-profile Chrome on a CDP port, opens the Feishu docs
// home, and waits until an authenticated session is available (scan the QR
// code the first time — the profile persists, so later refreshes are silent).
// Then it extracts the cookie jar via CDP and writes it to ~/.config/lark-alfred/cookies.
import { spawn, execSync } from 'node:child_process';
import { writeFileSync, chmodSync, existsSync } from 'node:fs';
import { setTimeout as sleep } from 'node:timers/promises';
import { ensureDirs, COOKIE_FILE, PROFILE_DIR, HOST, fetchRecent, AuthError } from './lib.mjs';

const PORT = Number(process.env.LARK_CDP_PORT || 9333);
const TIMEOUT_MS = 180_000;

const CHROME_CANDIDATES = [
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
];

function findChrome() {
  for (const p of CHROME_CANDIDATES) if (existsSync(p)) return p;
  throw new Error('Google Chrome not found in /Applications');
}

async function cdp(method, params = {}) {
  const ver = await (await fetch(`http://127.0.0.1:${PORT}/json/version`)).json();
  const ws = new WebSocket(ver.webSocketDebuggerUrl);
  await new Promise((res, rej) => {
    ws.onopen = res;
    ws.onerror = rej;
  });
  const result = await new Promise((res) => {
    ws.onmessage = (e) => {
      const m = JSON.parse(e.data);
      if (m.id === 1) res(m.result);
    };
    ws.send(JSON.stringify({ id: 1, method, params }));
  });
  ws.close();
  return result;
}

async function getCookieJar() {
  const { cookies } = await cdp('Storage.getCookies');
  const jar = cookies.filter((c) => c.domain.endsWith('larkoffice.com'));
  // De-dupe by name, preferring host-specific over wildcard domains.
  const byName = new Map();
  for (const c of jar) {
    const prev = byName.get(c.name);
    if (!prev || (!c.domain.startsWith('.') && prev.domain.startsWith('.'))) byName.set(c.name, c);
  }
  return [...byName.values()].map((c) => `${c.name}=${c.value}`).join('; ');
}

async function waitForCdp() {
  for (let i = 0; i < 50; i++) {
    try {
      await fetch(`http://127.0.0.1:${PORT}/json/version`);
      return;
    } catch {
      await sleep(200);
    }
  }
  throw new Error('Chrome CDP endpoint did not come up');
}

async function main() {
  ensureDirs();
  const chrome = findChrome();
  const child = spawn(
    chrome,
    [
      `--remote-debugging-port=${PORT}`,
      `--user-data-dir=${PROFILE_DIR}`,
      '--no-first-run',
      '--no-default-browser-check',
      `${HOST}/drive/home/`,
    ],
    { detached: true, stdio: 'ignore' }
  );
  child.unref();

  await waitForCdp();
  process.stderr.write('Waiting for Feishu login (scan the QR code if shown)…\n');

  const deadline = Date.now() + TIMEOUT_MS;
  let jar = null;
  while (Date.now() < deadline) {
    try {
      const candidate = await getCookieJar();
      if (candidate.includes('session=')) {
        // Verify the session actually authenticates against the real API.
        await fetchRecent(candidate, 1);
        jar = candidate;
        break;
      }
    } catch (e) {
      if (!(e instanceof AuthError)) process.stderr.write(`  …${e.message}\n`);
    }
    await sleep(1500);
  }

  if (!jar) {
    closeChrome();
    throw new Error('Timed out waiting for login');
  }

  writeFileSync(COOKIE_FILE, jar, { mode: 0o600 });
  chmodSync(COOKIE_FILE, 0o600);
  closeChrome();
  process.stdout.write('Lark Docs: signed in. Cookies saved.');
}

function closeChrome() {
  try {
    // Politely close just this CDP-controlled Chrome via its own endpoint.
    execSync(`curl -s http://127.0.0.1:${PORT}/json/close 2>/dev/null || true`);
  } catch {
    /* ignore */
  }
  // The launched Chrome is detached; closing the window is enough. Leave the
  // process for the user (their profile/session persists either way).
}

main().catch((e) => {
  process.stdout.write(`Lark Docs login failed: ${e.message}`);
  process.exitCode = 1;
});
