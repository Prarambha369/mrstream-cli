# Ponytail Debt Ledger

Deliberate shortcuts and deferrals taken during simplification passes.
Each marker documents what was simplified, the ceiling it imposes, and
the trigger to revisit.

---

## `mrstream` — consent section scoping

```
mrstream:<check_consent()> — check_consent() simplified awk → grep
ceiling:   global match, not scoped to sportsonline section.
           Space-only whitespace matching, no tab support.
upgrade:   if config grows multiple sources with different consent
           requirements, restore awk section tracking (`in_section`).
```

The original awk one-liner correctly scoped `enabled: true` checks to the
`sportsonline:` YAML section and used `[[:space:]]*` (spaces + tabs).
Replaced with two `grep -q` calls — simpler but checks the whole file
and only matches spaces, not tabs.

---

## `src/core/resolver.js` — browser-based stream resolution

```
src/core/resolver.js — entire file deleted (~60 lines + playwright dep)
ceiling:   no Playwright/Chromium fallback for JS-protected streams.
upgrade:   if sportsonline domains start requiring Cloudflare bypass or
           JS execution to expose m3u8 URLs, restore (or rewrite leaner).
```

The Playwright-based stealth browser resolver was never called by the CLI.
It added a ~300MB dependency (chromium + playwright) for a speculative
feature. Deleted entirely. If stream providers ever add JS challenges,
this will need to be rewritten (possibly using a simpler headless
approach like `curl -H` or a dedicated service).

---

## `src/plugins/sportsonline.sh` — variant playlist parsing

```
src/plugins/sportsonline.sh:<parse_m3u8()> — parse_m3u8() deleted (~50 lines)
ceiling:   no best-quality selection from variant m3u8 playlists.
upgrade:   if streams start serving multi-resolution variant playlists
           and mpv picks the wrong quality, restore a leaner parser.
```

The `parse_m3u8()` function parsed HLS variant playlists to select the
best stream URL (like ani-cli does). It was never called anywhere in the
codebase. Deleted. `mpv` handles single playlists natively, but if
stream providers serve multi-resolution playlists and mpv's default
selection is suboptimal, this will need to be rewritten.

---

## `src/plugins/sportsonline.sh` — `fetch_with_headers()` duplicates `fetch_url()`

```
src/plugins/sportsonline.sh:<fetch_with_headers()> — not unified with fetch_url()
ceiling:   two curl wrappers with similar logic in different files.
upgrade:   if a third call site emerges, refactor fetch_url() to accept
           optional -e/-A arguments instead of a separate function.
```

`sportsonline.sh` defines `fetch_with_headers()` (custom referer + user-agent)
that duplicates `fetch_url()` from `fetcher.sh`. Both retry different ways
and use different timeout defaults. Not unified because there's only one
caller of each.

---

## `mrstream` — player launch functions not unified

```
mrstream:<play_with_mpv() play_with_vlc() play_with_mplayer()> — 3 separate functions
ceiling:   duplicated with-refr/without-refr fallback pattern in each.
upgrade:   if a fourth player is added, refactor into a single player-agnostic
           launcher that maps --referrer per player flag.
```

`play_with_mpv()`, `play_with_vlc()`, and `play_with_mplayer()` all follow
the same structure (try with referer, fall back without). Not unified because
each player uses different flag names (`--referrer` vs `--http-referrer`).
`mplayer` is legacy and may be droppable entirely.

---

## Summary

| Shortcut | Ceiling | File |
|----------|---------|------|
| check_consent() → grep | No section scoping, spaces only | mrstream |
| resolver.js deleted | No JS/browser stream resolution | (deleted) |
| parse_m3u8() deleted | No variant quality selection | (deleted) |
| fetch_with_headers() not unified | Duplicated curl wrappers | sportsonline.sh |
| Player functions not unified | Duplicated launch pattern | mrstream |

**5 markers, 2 with no trigger** (player functions, fetch duplication — pure duplication, no correctness ceiling).
