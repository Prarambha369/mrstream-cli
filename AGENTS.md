AGENTS.md

# Guidance for AI coding agents working on mrstream-cli

This file captures the concrete, discoverable knowledge an AI agent needs to be productive in this repository.

1) Big picture
- Language & runtime: POSIX shell scripts (#!/bin/sh). Keep changes strictly POSIX-compatible (no bash-only syntax).
- Structure: single CLI entrypoint `mrstream` that sources small core modules in `src/core/` and plugins in `src/plugins/`.
  - Core responsibilities:
    - `src/core/fetcher.sh` — network fetching: fetch_url(url) -> writes body to stdout.
    - `src/core/cache.sh` — cache helpers: init_cache(), get_cache_path(name), is_cache_valid(path).
  - Plugin contract (examples: `src/plugins/sportsonline.sh`):
    - plugin_fetch(): outputs raw source to stdout
    - plugin_parse(): reads raw source from stdin, outputs lines of the form: time|title|channel|url
    - plugin_resolve(url): given an item URL returns a playable m3u8 (or empty on failure)

2) Important file locations (refer to them directly)
- CLI: `./mrstream` — main flow (parses flags, enforces consent, calls search_events)
- Installers: `scripts/install.sh`, `scripts/uninstall.sh` — how the project is installed to ~/.local
- Config: default config path `~/.config/mrstream/sources.yaml` (initialized by `init_config` in `mrstream`).
- Cache: `~/.cache/mrstream/*.cache` via functions in `src/core/cache.sh`.
- Tests: `tests/*.bats` (BATS test definitions showing expected plugin parsing and cache behavior).

3) Key runtime & developer workflows
- Run locally without installing: `./mrstream search "query"` or `./mrstream doctor`.
- Install (recommended):
  - `sh scripts/install.sh` — copies `mrstream` to `~/.local/bin` and copies `src/` to `~/.local/share/mrstream` and patches the executable to source from the share dir.
- Run tests: repository uses BATS. Example:
  - install bats (distribution package `bats`/`bats-core`), then run `bats tests` or `bats tests/test_parser.bats`.
- Debugging/tracing: run with shell tracing: `sh -x ./mrstream search` to see sourced-code execution. Use `--refresh` to bypass caches.

4) Project-specific conventions & patterns
- Plugin API is explicit: new sources must implement `plugin_fetch`, `plugin_parse`, and `plugin_resolve`.
  - `plugin_parse` must output a pipe-delimited line with 4 fields in this exact order because `mrstream` uses `cut -d'|' -f4` to pick the URL and `fzf --delimiter='|' --with-nth=1,2,3` to show columns.
- Caching: cache TTL is defined in `src/core/cache.sh` (variable TTL). `is_cache_valid` expects a cache file path, not a source name.
- Consent/config: `mrstream` requires explicit consent for external sources. The code checks both `enabled: true` and `acknowledge_non_affiliation: true` in `~/.config/mrstream/sources.yaml`.
  - The installer patches `mrstream` to source from `$SHARE_DIR/src/` — be careful when editing the installed copy vs. repo copy.
- Network calls: `fetch_url` retries up to 3 times with a 10s connect timeout — plugins should rely on it and not reimplement retries.

5) Integration points & external dependencies
- External tools required at runtime: `curl`, `fzf`, `mpv`, `grep`, `sed` (see README and `check_deps`). Tests and development may require `bats`.
- Remote data source example: `src/plugins/sportsonline.sh` fetches `https://sportsonline.vc/prog.txt` and expects lines like in `tests/test_parser.bats`:
  - `15:00   Chelsea x Nottingham Forest | https://.../hd1.php`
  - `plugin_parse` transforms the above into `15:00|Chelsea x Nottingham Forest|HD1|https://.../hd1.php`.
- Playback: `mrstream` resolves an m3u8 and passes it to `mpv --title="MrStream: $title" $m3u8`.

6) Safe edit rules for agents
- Preserve the plugin contract (function names and field ordering). Changing parse output order requires updating `mrstream` selection and extraction code.
- When adding files that will be sourced, add them to the installer (`scripts/install.sh`) or update install patching logic.
- Do not remove the explicit consent checks for external sources; tests and README depend on the config layout.

7) Quick examples for common tasks
- Add a plugin: create `src/plugins/myplug.sh` implementing plugin_fetch/parse/resolve; source it from `mrstream` (or rely on installer to copy); ensure parser emits `time|title|channel|url`.
- Force refresh during development: `./mrstream --refresh search` (or set REFRESH= true in the environment before invoking).
- Run parser test locally: `echo "15:00   Chelsea x Nottingham Forest | https://.../hd1.php" | ./src/plugins/sportsonline.sh plugin_parse` (plugin_parse reads stdin).

8) Non-discoverable runtime notes (observed in code)
- `mrstream` uses `awk` (complex check) to validate YAML structure in the repo copy; the test harness uses simpler `grep` checks — be mindful of both behaviours when updating consent logic.
- Installer sed replacement: `sed -i "s|\. src/|. $SHARE_DIR/src/|g"` — avoid editing that pattern in the repo without updating installer semantics.

References: `mrstream`, `src/core/fetcher.sh`, `src/core/cache.sh`, `src/plugins/sportsonline.sh`, `scripts/install.sh`, `tests/*.bats`, `README.md`

