// Shared helpers for the Lark Docs Alfred workflow.
// Talks to the Feishu web API on bytedance.larkoffice.com using a saved cookie
// jar. No external dependencies — relies on Node's global fetch (Node >= 18).
import { homedir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { mkdirSync, readFileSync, writeFileSync, statSync, readdirSync } from 'node:fs';

export const ICON_DIR = join(dirname(fileURLToPath(import.meta.url)), 'icons');

export const HOST = process.env.LARK_HOST || 'https://bytedance.larkoffice.com';
export const CONFIG_DIR = join(homedir(), '.config', 'lark-alfred');
export const CACHE_DIR = join(homedir(), '.cache', 'lark-alfred');
export const COOKIE_FILE = join(CONFIG_DIR, 'cookies');
export const PROFILE_DIR = join(CONFIG_DIR, 'chrome');

// Object types the docs home requests (doc, docx, sheet, bitable, mindnote,
// file, slides, wiki, …). Kept identical to what the web app sends.
export const OBJ_TYPES = [2, 22, 44, 3, 30, 8, 11, 12, 84, 123, 124];

export function ensureDirs() {
  mkdirSync(CONFIG_DIR, { recursive: true });
  mkdirSync(CACHE_DIR, { recursive: true });
}

export function readCookies() {
  try {
    const raw = readFileSync(COOKIE_FILE, 'utf8').trim();
    return raw || null;
  } catch {
    return null;
  }
}

function csrfFrom(cookie) {
  const m = /(?:^|;\s*)swp_csrf_token=([^;]+)/.exec(cookie);
  return m ? m[1] : '';
}

// AuthError signals an expired/missing session so callers can prompt re-login.
export class AuthError extends Error {}

async function getJSON(url, cookie) {
  const res = await fetch(url, {
    headers: {
      cookie,
      accept: 'application/json, text/plain, */*',
      'x-csrftoken': csrfFrom(cookie),
      referer: `${HOST}/drive/home/`,
      'user-agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36',
    },
    redirect: 'manual',
  });
  if (res.status === 401 || res.status === 403 || res.status >= 300 && res.status < 400) {
    throw new AuthError(`HTTP ${res.status}`);
  }
  let body;
  try {
    body = await res.json();
  } catch {
    throw new AuthError('non-JSON response (likely a login page)');
  }
  if (body.code !== 0) {
    // Anything that smells like "your session is gone" must become an AuthError,
    // because that is the only thing search.mjs turns into an actionable
    // "sign in with ll" row — a generic Error there is a dead end for the human.
    //
    // The literal message an expired Feishu session returns is "Something went
    // wrong, please log in again.", which the original /login/ pattern missed:
    // the server writes "log in" with a space. Match both spellings, and the
    // other phrasings seen from this API, rather than relying on the code alone
    // (it is not 1 for this case).
    if (
      body.code === 1 ||
      /log\s?in|logged|sign\s?[- ]?in|token|auth|permission|session|expired|credential/i.test(
        body.msg || '',
      )
    ) {
      throw new AuthError(body.msg || `code ${body.code}`);
    }
    throw new Error(body.msg || `code ${body.code}`);
  }
  return body.data;
}

// Normalise an entities/node_list payload into a flat array of docs.
function flatten(data) {
  if (!data || !data.node_list) return [];
  const nodes = (data.entities && data.entities.nodes) || {};
  const users = (data.entities && data.entities.users) || {};
  const out = [];
  for (const token of data.node_list) {
    const n = nodes[token];
    if (!n || !n.url || !n.name) continue;
    const owner = users[n.owner_id];
    let ii = {};
    try {
      ii = JSON.parse(n.icon_info || '{}');
    } catch {
      /* ignore */
    }
    out.push({
      token,
      name: n.name,
      url: n.url,
      owner: owner ? owner.name : '',
      activity_time: n.activity_time || n.open_time || n.edit_time || 0,
      objType: ii.obj_type ?? n.type,
      fileType: (ii.file_type || '').toLowerCase(),
    });
  }
  return out;
}

export async function fetchRecent(cookie, length = 50) {
  const params = new URLSearchParams({ length: String(length), type_opt: '1', rank: '6' });
  for (const t of OBJ_TYPES) params.append('obj_type', String(t));
  return flatten(await getJSON(`${HOST}/space/api/explorer/recent/list/?${params}`, cookie));
}

export async function fetchSearch(cookie, query, length = 20) {
  const sid = cryptoRandom();
  const params = new URLSearchParams({
    asc: '0',
    rank: '3',
    query,
    obj_type: OBJ_TYPES.join(','),
    length: String(length),
    search_session: sid,
    session_seq_id: '0',
    impression_id: `${sid}_0`,
  });
  return flatten(await getJSON(`${HOST}/space/api/bff/workspace/storage/list/?${params}`, cookie));
}

function cryptoRandom() {
  // A UUID-ish session id; the API only needs a stable-ish opaque value.
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

// Disk cache keyed by name, with a TTL in seconds.
export function cached(key, ttl, producer) {
  const file = join(CACHE_DIR, key);
  try {
    const age = (Date.now() - statSync(file).mtimeMs) / 1000;
    if (age < ttl) return Promise.resolve(JSON.parse(readFileSync(file, 'utf8')));
  } catch {
    /* miss */
  }
  return Promise.resolve(producer()).then((data) => {
    try {
      writeFileSync(file, JSON.stringify(data));
    } catch {
      /* best effort */
    }
    return data;
  });
}

// Lark obj_type -> icon basename + display label.
const OBJ_TYPE = {
  2: ['doc', 'Doc'],
  22: ['doc', 'Doc'],
  3: ['sheet', 'Sheet'],
  30: ['slide', 'Slide'],
  8: ['base', 'Base'],
  11: ['mindnote', 'Mindnote'],
  // 12 (file) is handled specially via fileType below.
};
// URL path segment -> icon basename, used as a fallback when obj_type is unknown.
const SEG = {
  docx: 'doc',
  docs: 'doc',
  sheets: 'sheet',
  slides: 'slide',
  base: 'base',
  mindnotes: 'mindnote',
  wiki: 'wiki',
  file: 'file',
  drive: 'file',
};

let extIconSet = null;
function hasExtIcon(ext) {
  if (!extIconSet) {
    try {
      extIconSet = new Set(
        readdirSync(ICON_DIR)
          .filter((f) => f.startsWith('ext-') && f.endsWith('.png'))
          .map((f) => f.slice(4, -4))
      );
    } catch {
      extIconSet = new Set();
    }
  }
  return extIconSet.has(ext);
}

// Resolve a doc to an absolute icon path + a short type label. Matches Lark's
// own behaviour: wiki-wrapped items show their underlying object's icon, and
// generic files show the native macOS icon for their extension.
export function typeInfo(doc) {
  if (doc.objType === 12) {
    const ext = doc.fileType;
    const name = ext && hasExtIcon(ext) ? `ext-${ext}` : 'file';
    return { icon: join(ICON_DIR, `${name}.png`), label: ext ? ext.toUpperCase() : 'File' };
  }
  const byType = OBJ_TYPE[doc.objType];
  if (byType) return { icon: join(ICON_DIR, `${byType[0]}.png`), label: byType[1] };
  const seg = (doc.url.split('/')[3] || '').toLowerCase();
  const name = SEG[seg] || 'file';
  return { icon: join(ICON_DIR, `${name}.png`), label: name.charAt(0).toUpperCase() + name.slice(1) };
}

export function relativeTime(epochSeconds) {
  if (!epochSeconds) return '';
  const diff = Date.now() / 1000 - epochSeconds;
  if (diff < 60) return 'just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  if (diff < 86400 * 30) return `${Math.floor(diff / 86400)}d ago`;
  const d = new Date(epochSeconds * 1000);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

// Case-insensitive AND-of-substrings match used for incremental filtering.
export function matches(name, terms) {
  const hay = name.toLowerCase();
  return terms.every((t) => hay.includes(t));
}
