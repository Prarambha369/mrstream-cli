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

    # Try direct m3u8 in the PHP page first
    m3u8=$(printf "%s" "$html" | grep -oE 'https?://[^"[:space:]]+\.m3u8[^"[:space:]]*' | head -n 1)
    [ -n "$m3u8" ] && { printf "%s" "$m3u8"; return 0; }

    # Fallback: extract iframe src and follow it (common embed pattern)
    embed_url=$(printf "%s" "$html" | grep -oE 'iframe src="([^"]+)"' | sed 's/iframe src="\([^"]*\)"/\1/' | head -n 1)
    if [ -n "$embed_url" ]; then
        embed_html=$(fetch_url "$embed_url")
        if [ -n "$embed_html" ]; then
            m3u8=$(printf "%s" "$embed_html" | grep -oE 'https?://[^"[:space:]]+\.m3u8[^"[:space:]]*' | head -n 1)
            [ -n "$m3u8" ] && { printf "%s" "$m3u8"; return 0; }
        fi
    fi

    # Final fallback: any .m3u8-looking URL in either page
    return 1
}
