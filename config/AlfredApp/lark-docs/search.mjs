#!/usr/bin/env node
// Alfred Script Filter backend for Lark Docs.
//
//   node search.mjs "<query>"
//
// Empty query  -> recent docs (server "recent" list).
// With a query -> recent docs filtered by incremental string match, plus
//                 server search results merged in (deduped by token).
// Emits Alfred Script Filter JSON on stdout.
import { join } from 'node:path';
import {
  ensureDirs,
  readCookies,
  fetchRecent,
  fetchSearch,
  cached,
  typeInfo,
  relativeTime,
  matches,
  AuthError,
  ICON_DIR,
} from './lib.mjs';
import { browserIcon, browserLabel, listBrowserProfiles, listInstalledBrowsers } from './chrome-cookies.mjs';

const RECENT_TTL = 300; // 5 min
const SEARCH_TTL = 60; // 1 min

function alfredItem(doc, { showTime } = {}) {
  const t = typeInfo(doc);
  const bits = [t.label];
  if (doc.owner) bits.push(doc.owner);
  if (showTime && doc.activity_time) bits.push(relativeTime(doc.activity_time));
  return {
    uid: doc.token,
    title: doc.name,
    subtitle: bits.join('  ·  '),
    arg: doc.url,
    icon: { path: t.icon },
    match: doc.name,
    quicklookurl: doc.url,
    text: { copy: doc.url, largetype: doc.name },
    mods: {
      cmd: { arg: doc.url, subtitle: 'Copy link to clipboard' },
      alt: { arg: `[${doc.name}](${doc.url})`, subtitle: 'Copy title + link (Markdown)' },
    },
  };
}

function emit(items, rerun) {
  const out = { items };
  if (rerun) out.rerun = rerun;
  process.stdout.write(JSON.stringify(out));
}

// Alfred can fire one of its own workflow's External Triggers over its URL
// scheme. Browser selection goes back into this Script Filter; profile
// selection goes to auth.mjs.
const LOGIN_BASE_URL = 'alfred://runtrigger/com.lukew.larkdocs/';

function loginUrl(trigger, argument) {
  return `${LOGIN_BASE_URL}${trigger}/?argument=${encodeURIComponent(argument)}`;
}

function loginPrompt(detail) {
  const browsers = listInstalledBrowsers();
  if (!browsers.length) {
    return emit([
      {
        uid: 'lark-login-fallback',
        title: 'Sign in to Lark',
        subtitle: `↩ opens the dedicated browser login${detail ? `  ·  ${detail}` : ''}`,
        valid: true,
        arg: loginUrl('login', 'fallback'),
        icon: { path: join(ICON_DIR, 'login.png') },
      },
    ]);
  }

  emit([
    {
      uid: 'lark-login-browser-heading',
      title: 'Choose a browser for Lark sign-in',
      subtitle: detail || 'Select the browser whose existing session should be imported',
      valid: false,
      icon: { path: join(ICON_DIR, 'login.png') },
    },
    ...browsers.map((browser) => ({
      uid: `lark-login-browser:${browser.name}`,
      title: browser.label,
      subtitle: `${browser.profileCount} profile${browser.profileCount === 1 ? '' : 's'} available  ·  ↩ choose browser`,
      valid: true,
      arg: loginUrl('login-profiles', `browser|${browser.name}`),
      icon: { path: browser.icon || join(ICON_DIR, 'login.png') },
    })),
  ]);
}

function loginProfilePrompt(browserName, terms = []) {
  let profiles;
  try {
    profiles = listBrowserProfiles(browserName);
  } catch (e) {
    return emit([{ title: 'Lark login error', subtitle: e.message, valid: false }]);
  }

  const filtered = terms.length
    ? profiles.filter((profile) => terms.every((term) => profile.name.toLowerCase().includes(term)))
    : profiles;
  emit([
    {
      uid: `lark-login-profile-heading:${browserName}`,
      title: `Choose a ${browserLabel(browserName)} profile`,
      subtitle: 'Select the profile containing the active Lark session',
      valid: false,
      icon: { path: join(ICON_DIR, 'login.png') },
    },
    ...filtered.map((profile) => ({
      uid: `lark-login-profile:${browserName}:${profile.dir}`,
      title: profile.name,
      subtitle: `${browserLabel(browserName)}  ·  ↩ import this profile's Lark session`,
      valid: true,
      arg: loginUrl('login-import', `profile|${browserName}|${profile.dir}`),
      icon: { path: browserIcon(browserName) || join(ICON_DIR, 'login.png') },
    })),
  ]);
}

function loginMode(query) {
  if (!query.startsWith('browser|')) return null;
  const rest = query.slice('browser|'.length).trim();
  const [browserName, ...terms] = rest.split(/\s+/).filter(Boolean);
  return browserName ? { browserName, terms: terms.map((term) => term.toLowerCase()) } : null;
}

async function main() {
  ensureDirs();
  let query = (process.argv[2] || '').trim();
  // Safety net: if Alfred's "{query}" placeholder wasn't substituted (argv vs
  // {query} mode mismatch), treat it as an empty query and show recents.
  if (query === '{query}') query = '';
  const mode = loginMode(query);
  if (mode) return loginProfilePrompt(mode.browserName, mode.terms);
  const cookie = readCookies();
  if (!cookie) return loginPrompt('no cookies found');

  let recent;
  try {
    recent = await cached('recent.json', RECENT_TTL, () => fetchRecent(cookie));
  } catch (e) {
    if (e instanceof AuthError) return loginPrompt(e.message);
    throw e;
  }

  // No query: show the recent list as-is.
  if (!query) {
    emit(recent.slice(0, 30).map((d) => alfredItem(d, { showTime: true })));
    return;
  }

  const terms = query.toLowerCase().split(/\s+/).filter(Boolean);
  const recentHits = recent.filter((d) => matches(d.name, terms));

  // Server search for queries of 2+ chars; merge below the recent hits.
  let searchHits = [];
  if (query.length >= 2) {
    try {
      const key = `search-${Buffer.from(query).toString('hex').slice(0, 48)}.json`;
      searchHits = await cached(key, SEARCH_TTL, () => fetchSearch(cookie, query));
    } catch (e) {
      if (e instanceof AuthError) return loginPrompt(e.message);
      // Non-auth search failure: degrade to recent-only matching.
      searchHits = [];
    }
  }

  const seen = new Set(recentHits.map((d) => d.token));
  const merged = [
    ...recentHits.map((d) => alfredItem(d, { showTime: true })),
    ...searchHits.filter((d) => !seen.has(d.token)).map((d) => alfredItem(d)),
  ];

  if (merged.length === 0) {
    emit([
      {
        title: `No matches for “${query}”`,
        subtitle: 'Try fewer or different words',
        valid: false,
      },
    ]);
    return;
  }
  emit(merged);
}

main().catch((e) => {
  // Always leave a visible path back into the browser/profile chooser.
  loginPrompt(`Lark Docs error: ${String(e && e.message ? e.message : e)}`);
});
