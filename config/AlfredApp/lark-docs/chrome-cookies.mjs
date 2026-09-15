// Read cookies from Chromium-based browser profiles on macOS.
//
// Cookie values are encrypted with a browser-specific key kept in Keychain.
// This module never prints cookie values; callers receive an in-memory Cookie
// header and decide what to save.
import { execFileSync } from 'node:child_process';
import { createDecipheriv, createHash, pbkdf2Sync } from 'node:crypto';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const SQLITE_CANDIDATES = ['/usr/bin/sqlite3', '/opt/homebrew/bin/sqlite3', '/usr/local/bin/sqlite3'];
// Chromium has used both layouts over time. Edge on this machine keeps the
// database directly under the profile (`Default/Cookies`), while other
// Chromium-based browsers commonly use `Default/Network/Cookies`.
const COOKIE_DB_CANDIDATES = ['Network/Cookies', 'Cookies'];
const COOKIE_DOMAIN = 'larkoffice.com';

const BROWSER_CONFIGS = {
  chrome: {
    label: 'Google Chrome',
    iconPath: '/Applications/Google Chrome.app/Contents/Resources/app.icns',
    dataDir: join(homedir(), 'Library', 'Application Support', 'Google', 'Chrome'),
    keychainServices: ['Chrome Safe Storage'],
    executables: ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'],
  },
  'chrome-canary': {
    label: 'Google Chrome Canary',
    iconPath: '/Applications/Google Chrome Canary.app/Contents/Resources/app.icns',
    dataDir: join(homedir(), 'Library', 'Application Support', 'Google', 'Chrome Canary'),
    keychainServices: ['Chrome Safe Storage', 'Chrome Canary Safe Storage'],
    executables: ['/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary'],
  },
  edge: {
    label: 'Microsoft Edge',
    iconPath: '/Applications/Microsoft Edge.app/Contents/Resources/app.icns',
    dataDir: join(homedir(), 'Library', 'Application Support', 'Microsoft Edge'),
    keychainServices: ['Microsoft Edge Safe Storage'],
    executables: ['/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge'],
  },
  chromium: {
    label: 'Chromium',
    iconPath: '/Applications/Chromium.app/Contents/Resources/app.icns',
    dataDir: join(homedir(), 'Library', 'Application Support', 'Chromium'),
    keychainServices: ['Chromium Safe Storage'],
    executables: ['/Applications/Chromium.app/Contents/MacOS/Chromium'],
  },
  brave: {
    label: 'Brave Browser',
    iconPath: '/Applications/Brave Browser.app/Contents/Resources/app.icns',
    dataDir: join(homedir(), 'Library', 'Application Support', 'BraveSoftware', 'Brave-Browser'),
    keychainServices: ['Brave Safe Storage'],
    executables: ['/Applications/Brave Browser.app/Contents/MacOS/Brave Browser'],
  },
  vivaldi: {
    label: 'Vivaldi',
    iconPath: '/Applications/Vivaldi.app/Contents/Resources/app.icns',
    dataDir: join(homedir(), 'Library', 'Application Support', 'Vivaldi'),
    keychainServices: ['Vivaldi Safe Storage'],
    executables: ['/Applications/Vivaldi.app/Contents/MacOS/Vivaldi'],
  },
  opera: {
    label: 'Opera',
    iconPath: '/Applications/Opera.app/Contents/Resources/app.icns',
    dataDir: join(homedir(), 'Library', 'Application Support', 'com.operasoftware.Opera'),
    keychainServices: ['Opera Safe Storage'],
    executables: ['/Applications/Opera.app/Contents/MacOS/Opera'],
  },
  arc: {
    label: 'Arc',
    iconPath: '/Applications/Arc.app/Contents/Resources/app.icns',
    dataDir: join(homedir(), 'Library', 'Application Support', 'Arc', 'User Data'),
    keychainServices: ['Arc Safe Storage'],
    executables: ['/Applications/Arc.app/Contents/MacOS/Arc'],
  },
};

const BROWSER_ALIASES = {
  'google-chrome': 'chrome',
  'microsoft-edge': 'edge',
  'brave-browser': 'brave',
};

function findExecutable(paths) {
  return paths.find((path) => existsSync(path));
}

function normalizeBrowserName(name) {
  const normalized = String(name || '').trim().toLowerCase();
  return BROWSER_ALIASES[normalized] || normalized;
}

function getBrowser(name) {
  const normalized = normalizeBrowserName(name);
  const config = BROWSER_CONFIGS[normalized];
  if (!config) throw new Error(`Unsupported browser: ${name}`);
  return { name: normalized, ...config };
}

function readSafeStoragePassword(services) {
  for (const service of services) {
    try {
      const password = execFileSync('/usr/bin/security', ['find-generic-password', '-s', service, '-w'], {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
      }).trim();
      if (password) return password;
    } catch {
      // The item may not exist for this browser, or Keychain may deny access.
    }
  }
  return null;
}

function keyForBrowser(browser) {
  const password = readSafeStoragePassword(browser.keychainServices);
  if (!password) return null;
  return pbkdf2Sync(Buffer.from(password), Buffer.from('saltysalt'), 1003, 16, 'sha1');
}

function decryptCookieValue(hex, key, domain) {
  if (!hex || !key) return null;
  const encrypted = Buffer.from(hex, 'hex');
  const version = encrypted.subarray(0, 3).toString('ascii');
  if (version !== 'v10' && version !== 'v11') return null;

  try {
    const decipher = createDecipheriv('aes-128-cbc', key, Buffer.alloc(16, 0x20));
    let plaintext = Buffer.concat([decipher.update(encrypted.subarray(3)), decipher.final()]);
    // Chromium M130+ prefixes macOS cookie plaintext with SHA-256(host_key).
    // Keep compatibility with older profiles where the value starts directly.
    const hostHash = createHash('sha256').update(domain).digest();
    if (plaintext.subarray(0, hostHash.length).equals(hostHash)) {
      plaintext = plaintext.subarray(hostHash.length);
    }
    return new TextDecoder('utf-8', { fatal: true }).decode(plaintext);
  } catch {
    return null;
  }
}

function listProfileDirs(dataDir) {
  if (!existsSync(dataDir)) return [];
  return readdirSync(dataDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && (entry.name === 'Default' || /^Profile \d+$/.test(entry.name)))
    .map((entry) => entry.name)
    .sort((a, b) => (a === 'Default' ? -1 : b === 'Default' ? 1 : a.localeCompare(b, undefined, { numeric: true })));
}

function profileNames(dataDir) {
  try {
    const state = JSON.parse(readFileSync(join(dataDir, 'Local State'), 'utf8'));
    return state.profile?.info_cache || {};
  } catch {
    return {};
  }
}

function listProfiles(browser) {
  const names = profileNames(browser.dataDir);
  return listProfileDirs(browser.dataDir).map((dir) => {
    const info = names[dir] || {};
    return {
      dir,
      name: info.name || info.gaia_name || info.user_name || dir,
    };
  });
}

function cookieDatabase(browser, profileDir) {
  const profilePath = join(browser.dataDir, profileDir);
  return COOKIE_DB_CANDIDATES.map((relativePath) => join(profilePath, relativePath)).find(existsSync);
}

function readProfileCookies(browser, profileDir, key, sqlite) {
  const database = cookieDatabase(browser, profileDir);
  if (!database) return [];

  const query =
    "SELECT host_key, name, value, hex(encrypted_value) FROM cookies " +
    `WHERE host_key LIKE '%${COOKIE_DOMAIN}' ORDER BY host_key, name;`;
  let output;
  try {
    output = execFileSync(sqlite, ['-readonly', '-separator', '\t', database, query], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
      maxBuffer: 4 * 1024 * 1024,
    });
  } catch {
    return [];
  }

  const cookies = [];
  for (const line of output.split('\n')) {
    if (!line) continue;
    const [domain, name, plainValue, encryptedHex] = line.split('\t');
    if (!domain || !name) continue;
    const value = plainValue || decryptCookieValue(encryptedHex, key, domain);
    if (value == null) continue;
    cookies.push({ domain, name, value });
  }
  return cookies;
}

function toCookieJar(cookies) {
  const byName = new Map();
  for (const cookie of cookies) {
    const previous = byName.get(cookie.name);
    if (!previous || (!cookie.domain.startsWith('.') && previous.domain.startsWith('.'))) {
      byName.set(cookie.name, cookie);
    }
  }
  return [...byName.values()].map(({ name, value }) => `${name}=${value}`).join('; ');
}

// Browsers with a local Chromium profile and a known data layout.
export function listInstalledBrowsers() {
  return Object.entries(BROWSER_CONFIGS).flatMap(([name, config]) => {
    const profileCount = listProfiles({ name, ...config }).length;
    const executable = findExecutable(config.executables);
    if (!profileCount || !executable) return [];
    return [{
      name,
      label: config.label,
      icon: existsSync(config.iconPath) ? config.iconPath : '',
      profileCount,
    }];
  });
}

export function listBrowserProfiles(name) {
  return listProfiles(getBrowser(name)).map(({ dir, name: profileName }) => ({ dir, name: profileName }));
}

export function browserLabel(name) {
  return getBrowser(name).label;
}

export function browserIcon(name) {
  const path = getBrowser(name).iconPath;
  return existsSync(path) ? path : null;
}

export function readBrowserCookieJar(name, profileDir) {
  const sqlite = findExecutable(SQLITE_CANDIDATES);
  if (!sqlite) return null;
  const browser = getBrowser(name);
  if (!listProfileDirs(browser.dataDir).includes(profileDir)) return null;
  const key = keyForBrowser(browser);
  if (!key) return null;
  const jar = toCookieJar(readProfileCookies(browser, profileDir, key, sqlite));
  return jar.includes('session=') ? jar : null;
}

// Kept for command-line callers that want automatic import. The Alfred UI uses
// listInstalledBrowsers + listBrowserProfiles + readBrowserCookieJar so the
// human chooses the exact browser/profile pair first.
export function readBrowserCookieJars() {
  const sqlite = findExecutable(SQLITE_CANDIDATES);
  if (!sqlite) return [];
  const candidates = [];
  for (const browser of listInstalledBrowsers()) {
    const config = getBrowser(browser.name);
    const key = keyForBrowser(config);
    if (!key) continue;
    for (const profile of listProfiles(config)) {
      const jar = toCookieJar(readProfileCookies(config, profile.dir, key, sqlite));
      if (jar.includes('session=')) candidates.push({ browser: browser.name, profile: profile.dir, jar });
    }
  }
  return candidates;
}

export function findBrowserExecutable(name) {
  if (name) {
    const browser = getBrowser(name);
    const executable = findExecutable(browser.executables);
    if (!executable) throw new Error(`${browser.label} executable not found in /Applications`);
    return { name: browser.name, label: browser.label, executable };
  }

  for (const [browserName, config] of Object.entries(BROWSER_CONFIGS)) {
    const executable = findExecutable(config.executables);
    if (executable) return { name: browserName, label: config.label, executable };
  }
  throw new Error('No supported Chromium browser executable found in /Applications');
}
