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
// scheme, and this filter's ↩ already feeds an Open URL action — so handing back
// a runtrigger URL makes the row itself sign you in. That replaced the old `ll`
// keyword outright: an entry point you have to remember, which does nothing on
// 99% of days, and which the human could not find at the one moment it mattered.
const LOGIN_URL = 'alfred://runtrigger/com.lukew.larkdocs/login/';

function loginPrompt(detail) {
  emit([
    {
      title: 'Sign in to Lark',
      subtitle: `↩ opens Chrome to refresh the session${detail ? `  ·  ${detail}` : ''}`,
      valid: true,
      arg: LOGIN_URL,
      icon: { path: join(ICON_DIR, 'login.png') },
    },
  ]);
}

async function main() {
  ensureDirs();
  let query = (process.argv[2] || '').trim();
  // Safety net: if Alfred's "{query}" placeholder wasn't substituted (argv vs
  // {query} mode mismatch), treat it as an empty query and show recents.
  if (query === '{query}') query = '';
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
  // Signing in is the fix for most failures here, and since the `ll` keyword was
  // retired this row is the only way in — so always offer it, even when the
  // error was not recognised as an auth problem. Without this, one unclassified
  // server message would leave the workflow with no login path at all.
  emit([
    {
      title: 'Lark Docs error',
      subtitle: String(e && e.message ? e.message : e),
      valid: false,
    },
    {
      title: 'Sign in to Lark',
      subtitle: '↩ opens Chrome to refresh the session',
      valid: true,
      arg: LOGIN_URL,
      icon: { path: join(ICON_DIR, 'login.png') },
    },
  ]);
});
