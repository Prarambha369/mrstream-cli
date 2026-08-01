# mrstream-cli Rebuild Progress

**Mission**: Rebuild mrstream-cli to match ani-cli quality standards
**Started**: 2026-07-18

---

## PHASE 0 — RECONNAISSANCE ✓

### ani-cli Analysis (701 lines)
Key patterns observed:
- **Dependency checking**: `dep_ch()` function (line 125-129) - dies immediately with clear message
- **Argument parsing**: getopts-style with long/short flags (lines 43-100)
- **Error handling**: `die()` function with red color output (lines 38-41)
- **Update mechanism**: `update_script()` (lines 107-122) - curl latest from GitHub, diff+patch
- **Quality selection**: `select_quality()` function (lines 209-234) - best/worst/specific
- **Provider fallback**: multiple providers tried sequentially in background jobs (lines 312-315)
- **No-results handling**: explicit checks and graceful exits (lines 321-324)
- **UI helpers**: `launcher()` wrapper for fzf/rofi/dmenu (lines 12-17)
- **Cleanup trap**: removes temp files on exit (lines 141-145)

### mrstream-cli Current State (READ ALL FILES)

**Main entry**: `~/air/mrstream-cli/mrstream` (339 lines)
- Version: 0.1.0-alpha
- Config: ~/.config/mrstream/sources.yaml
- Cache: ~/.cache/mrstream/
- Modules: src/core/{fetcher.sh, cache.sh}, src/plugins/{sportsonline.sh, community.sh}

**Core modules**:
- `src/core/fetcher.sh` - fetch_url() function
- `src/core/cache.sh` - cache helpers (init, get_path, is_valid)

**Plugins**:
- `src/plugins/sportsonline.sh` - plugin_fetch(), plugin_parse(), plugin_resolve()
- `src/plugins/community.sh` - same contract

**Known issues from PONYTAIL-DEBT.md**:
1. ❌ check_consent() simplified awk → grep (no section scoping)
2. ❌ resolver.js deleted (no JS/browser fallback)
3. ❌ parse_m3u8() deleted (no quality selection)
4. ❌ fetch_with_headers() duplicates fetch_url()
5. ❌ Player functions not unified (mpv/vlc/mplayer)

**Uncommitted changes**:
- Modified: mrstream, src/core/{cache,fetcher}.sh, src/plugins/{sportsonline,community}.sh
- Deleted: src/core/resolver.js
- New: PONYTAIL-DEBT.md, mrstream.1, scripts/demo.sh, src/core/deep-resolver.js

---

## PHASE 0 - Audit current state ✓

### Test 1: Dependencies check
```
./mrstream doctor
❌ Missing dependency: yt-dlp
❌ No video player found (need mpv, vlc/cvlc, or mplayer)
```

**System has**: curl, fzf, grep, sed
**System missing**: mpv, yt-dlp

**Note**: User needs to install mpv and yt-dlp before testing further.

### Code audit complete

**mrstream** (411 lines):
- Version 0.1.0-alpha
- Has self_update() function (lines 141-170)
- Has check_deps() with distro-aware install suggestions (lines 88-124)
- Has play_stream_with_player() with mpv/vlc/mplayer support (lines 174+)
- Consent checking implemented but simplified (PONYTAIL-DEBT #1)
- Player functions duplicated (PONYTAIL-DEBT #5)

**src/core/fetcher.sh** (28 lines):
- fetch_url() with retry logic (3 attempts, 10s timeout)
- Accepts url, referer, user_agent parameters

**src/core/cache.sh** (26 lines):
- TTL=3600 (1 hour) — should be reduced to 600 (10 min) per ani-cli standard
- init_cache(), is_cache_valid(), get_cache_path() functions

**src/plugins/sportsonline.sh** (322 lines):
- SOURCE_URL: https://sportsonline.st/prog.txt
- 5-strategy resolver (S1-S5e) with debug logging
- Includes deep-resolver.js fallback (requires node + playwright)
- Proper referer handling per owner request
- No quality selection (PONYTAIL-DEBT #3)

**src/plugins/community.sh** (81 lines):
- SOURCE_URL: https://iptv-org.github.io/iptv/categories/sports.m3u
- Falls back to verified_streams.m3u if present
- Direct M3U parsing with awk
- Returns empty referer for community streams

---

## Done
- ✓ Cloned ani-cli reference implementation (701 lines)
- ✓ Read ani-cli architecture - key patterns identified
- ✓ Read PONYTAIL-DEBT.md (5 technical debt items)
- ✓ Read AGENTS.md (project structure)
- ✓ Read all mrstream-cli source files (mrstream + 4 modules)
- ✓ Ran mrstream doctor - dependencies identified
- ✓ Created PROGRESS.md tracking document
- ✓ **Phase 1a**: Fixed cache TTL (3600s → 600s)
- ✓ **Phase 1b**: Consolidated player functions into src/core/player.sh (PONYTAIL-DEBT #5)
- ✓ Updated mrstream to use unified play_stream() function
- ✓ **Phase 1c**: Fixed consent checking with proper awk section scoping (PONYTAIL-DEBT #1)
- ✓ **Phase 1d**: Implemented yt-dlp fallback resolver (PONYTAIL-DEBT #2) in src/core/resolver.sh
- ✓ **Phase 1e**: Implemented HLS quality selection (PONYTAIL-DEBT #3) in src/core/quality.sh
- ✓ Added -q/--quality flag to argument parser (best/worst/720p/1080p/360p)
- ✓ Integrated quality selection and yt-dlp fallback into resolution flow
- ✓ Updated help text with quality examples

**Phase 1 Complete** — All 5 PONYTAIL-DEBT items addressed

- ✓ **Phase 2**: Added short flags (-h, -v, -U, -p)
- ✓ **Phase 2**: Dependency check on startup (before search command)
- ✓ **Phase 2**: Cache expiry (10 minutes, done in Phase 1a)
- ✓ **Phase 2**: No-results handling (prints "No events found matching 'query'")
- ✓ **Phase 2**: Improved fetcher.sh with HTTP status checking
- ✓ **Phase 2**: Offline graceful degradation (uses stale cache, warns on total failure)
- ✓ **Phase 2**: Human-readable error messages throughout

**Phase 2 Complete** — Matches ani-cli quality bar

---

## In Progress

### Phase 3 — Plugin Hardening

- [x] Added plugin_name(), plugin_version(), plugin_description() to sportsonline.sh
- [x] Added plugin_name(), plugin_version(), plugin_description() to community.sh
- [ ] Test each plugin independently
- [ ] Verify timeout handling in resolvers
- [ ] Verify clean stream URLs passed to player

### Phase 4 — Final Polish

Next tasks:
- [ ] Run shellcheck on all .sh files
- [ ] Update README.md with complete installation and usage
- [ ] Update man page (mrstream.1)
- [ ] Sync version strings across files
- [ ] Git commit with proper messages

---

## Blocked
None. Proceeding to Phase 1.

---

## Next Steps
1. Run mrstream to see current state
2. Read remaining source files
3. Document exact failure modes
4. Begin Phase 1: Build working skeleton
