#!/bin/sh
# MrStream-Cli: A minimalist sports stream CLI.
# This tool is NOT affiliated with sportsonline.vc, sportssonline.click, or any content provider.

CACHE_DIR="${HOME}/.cache/mrstream"
TTL=600 # 10 minutes (ani-cli standard)

init_cache() {
    mkdir -p "$CACHE_DIR"
}

is_cache_valid() {
    cache_file="$1"
    [ -f "$cache_file" ] || return 1

    current_time=$(date +%s)
    file_time=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || date -r "$cache_file" +%s)
    age=$((current_time - file_time))

    [ $age -lt $TTL ]
}

get_cache_path() {
    source_name="$1"
    printf "%s/%s.cache" "$CACHE_DIR" "$source_name"
}
