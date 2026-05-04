#!/bin/sh
# MrStream-Cli: A minimalist sports stream CLI.
# This tool is NOT affiliated with sportsonline.vc, sportssonline.click, or any content provider.

SOURCE_URL="https://sportsonline.vc/prog.txt"

plugin_fetch() {
    fetch_url "$SOURCE_URL"
}

plugin_parse() {
    # Expects raw content on stdin
    grep -E '^[0-9]{2}:[0-9]{2}' | while IFS='|' read -r time_title url; do
        [ -z "$time_title" ] && continue
        time=$(printf "%s" "$time_title" | cut -c 1-5)
        title=$(printf "%s" "$time_title" | sed 's/^[0-9:]*[[:space:]]*//' | sed 's/[[:space:]]*$//')
        url=$(printf "%s" "$url" | sed 's/^[[:space:]]*//')

        # Extract channel from URL
        channel=$(printf "%s" "$url" | sed 's/.*\/\([^/]*\)\.php/\1/' | tr '[:lower:]' '[:upper:]')

        printf "%s|%s|%s|%s\n" "$time" "$title" "$channel" "$url"
    done
}

plugin_resolve() {
    php_url="$1"
    html=$(fetch_url "$php_url")
    [ -z "$html" ] && return 1

    # Match source src="..." or source src='...' with optional spaces and .m3u8 extension
    # Also added support for data-url or other common stream attributes if necessary, 
    # but sticking to the observed pattern first with more flexibility.
    m3u8=$(printf "%s" "$html" | grep -oE "https?://[^\"']+\.m3u8" | head -n 1)

    if [ -n "$m3u8" ]; then
        printf "%s" "$m3u8"
        return 0
    fi
    return 1
}
