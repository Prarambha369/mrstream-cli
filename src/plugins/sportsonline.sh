#!/bin/sh
# MrStream-Cli: A minimalist sports stream CLI.
# This tool is NOT affiliated with sportsonline.vc, sportssonline.click, or any content provider.

SOURCE_URL="https://sportsonline.vc/prog.txt"

# User agent (matching ani-cli's approach for better compatibility)
AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0"

# Enhanced fetch: send referrer and UA headers (inspired by ani-cli)
fetch_with_headers() {
    url="$1"
    referer="${2:-$url}"  # default referrer to the URL itself
    curl -s -L -e "$referer" -A "$AGENT" --connect-timeout 10 "$url"
}

# Parse m3u8 playlist and extract the best stream URL (like ani-cli does)
parse_m3u8() {
    m3u8_url="$1"
    base_url="${2:-$m3u8_url}"  # base for resolving relative paths

    m3u8_content=$(fetch_with_headers "$m3u8_url" "$base_url")
    [ -z "$m3u8_content" ] && return 1

    # If the m3u8 contains stream info (EXTM3U), it's a playlist with variants
    if printf "%s" "$m3u8_content" | grep -q "EXTM3U"; then
        [ -n "$DEBUG" ] && printf "DEBUG: m3u8 is a playlist\n" >&2

        # Extract variant playlists (lines that don't start with # or are URLs)
        # Prefer high bandwidth/resolution (take last line = highest quality)
        stream_line=$(printf "%s" "$m3u8_content" | grep -v "^#" | grep -v "^$" | tail -n1)

        if [ -z "$stream_line" ]; then
            # Fall back to first non-comment line
            stream_line=$(printf "%s" "$m3u8_content" | grep -v "^#" | grep -v "^$" | head -n1)
        fi
    else
        # Direct .ts file or already-resolved stream
        stream_line=$(printf "%s" "$m3u8_content" | grep -v "^#" | grep -v "^$" | head -n1)
    fi

    [ -z "$stream_line" ] && return 1

    # If stream_line is relative, resolve it relative to the base URL
    case "$stream_line" in
        http* ) printf "%s" "$stream_line" ;;
        /* )  # absolute path
            site=$(printf "%s" "$base_url" | sed -n 's,\(^https\?://[^/]*\).*,\1,p')
            printf "%s%s" "$site" "$stream_line"
            ;;
        * )   # relative path
            dir=$(printf "%s" "$base_url" | sed 's,/[^/]*$,,')
            printf "%s/%s" "$dir" "$stream_line"
            ;;
    esac
}

plugin_fetch() {
    fetch_url "$SOURCE_URL"
}

plugin_parse() {
    # Expects raw content on stdin
    # Allow leading whitespace before the time (source often indents lines). Trim leading space
    grep -E '^[[:space:]]*[0-9]{2}:[0-9]{2}' | sed 's/^[[:space:]]*//' | while IFS='|' read -r time_title url; do
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
    temp_refr=""  # Track referrer for playback

    # Fetch the PHP page with proper headers (referrer helps sports streaming sites)
    html=$(fetch_with_headers "$php_url")

    if [ -z "$html" ]; then
        [ -n "$DEBUG" ] && printf "DEBUG: initial fetch failed for %s\n" "$php_url" >&2
        return 1
    fi

    [ -n "$DEBUG" ] && printf "DEBUG: fetched %s bytes from %s\n" "$(printf "%s" "$html" | wc -c)" "$php_url" >&2

    # Helper function: resolve relative URLs to absolute (like ani-cli does)
    make_abs() {
        base="$1"
        rel="$2"
        # extract scheme+host
        site=$(printf "%s" "$base" | sed -n 's,\(^https\?://[^/]*\).*,\1,p')
        case "$rel" in
            //*) printf "https:%s" "$rel" ;;
            http:/*|https:/*) printf "%s" "$rel" ;;
            /*) printf "%s%s" "$site" "$rel" ;;
            http* ) printf "%s" "$rel" ;;
            *) printf "%s/%s" "$site" "$rel" ;;
        esac
    }

    # 1) Try direct m3u8 URLs in quoted strings (common in player configs)
    m3u8=$(printf "%s" "$html" | grep -oE "['\"]https?://[^'\"]+\.m3u8[^'\"]*['\"]" | sed -E "s/^['\"](.*)['\"]$/\1/" | head -n 1)
    if [ -z "$m3u8" ]; then
        m3u8=$(printf "%s" "$html" | grep -oE 'https?://[^"[:space:]]+\.m3u8[^"[:space:]]*' | head -n 1)
    fi
    if [ -n "$m3u8" ]; then
        [ -n "$DEBUG" ] && printf "DEBUG: found m3u8 URL: %s\n" "$m3u8" >&2
        temp_refr="$php_url"  # m3u8 URL needs PHP page as referrer
        final_url=$(parse_m3u8 "$m3u8" "$php_url")
        [ -n "$final_url" ] && { printf "%s\n" "$final_url"; [ -n "$temp_refr" ] && printf "%s\n" "$temp_refr"; return 0; }
        printf "%s\n" "$m3u8"
        [ -n "$temp_refr" ] && printf "%s\n" "$temp_refr"
        return 0
    fi

    # 2) Look for common player config patterns like file: '...', source: '...', hls: '...'
    m3u8=$(printf "%s" "$html" | grep -oE "(file|source|hls|hlsUrl|streamUrl)\s*:\s*['\"][^'\"]+\.m3u8[^'\"]*['\"]" | sed -E "s/.*['\"](https?:.*m3u8.*)['\"].*/\1/" | head -n 1)
    if [ -n "$m3u8" ]; then
        [ -n "$DEBUG" ] && printf "DEBUG: found m3u8 in config key: %s\n" "$m3u8" >&2
        temp_refr="$php_url"
        final_url=$(parse_m3u8 "$m3u8" "$php_url")
        [ -n "$final_url" ] && { printf "%s\n" "$final_url"; [ -n "$temp_refr" ] && printf "%s\n" "$temp_refr"; return 0; }
        printf "%s\n" "$m3u8"
        [ -n "$temp_refr" ] && printf "%s\n" "$temp_refr"
        return 0
    fi

    # 3) Extract iframe or embed src and follow it (look specifically for iframe src first)
    embed_url=$(printf "%s" "$html" | grep -oE '<iframe[^>]*src="[^"]*"' | sed 's/.*src="\([^"]*\)".*/\1/' | head -n 1)
    if [ -z "$embed_url" ]; then
        embed_url=$(printf "%s" "$html" | grep -oE "<iframe[^>]*src='[^']*'" | sed "s/.*src='\([^']*\)'.*/\1/" | head -n 1)
    fi
    # Fallback: try any src= if no iframe found
    if [ -z "$embed_url" ]; then
        embed_url=$(printf "%s" "$html" | grep -oE 'src="[^"]+"' | sed 's/src="\([^"]*\)"/\1/' | head -n 1)
    fi
    if [ -n "$embed_url" ]; then
        [ -n "$DEBUG" ] && printf "DEBUG: following embed URL: %s\n" "$embed_url" >&2
        embed_url=$(make_abs "$php_url" "$embed_url")
        embed_html=$(fetch_with_headers "$embed_url" "$php_url")
        if [ -z "$embed_html" ]; then
            [ -n "$DEBUG" ] && printf "DEBUG: embed fetch failed, retrying without referrer\n" >&2
            embed_html=$(curl -s -L -A "$AGENT" --connect-timeout 10 "$embed_url" 2>/dev/null)
        fi
        if [ -n "$embed_html" ]; then
            [ -n "$DEBUG" ] && printf "DEBUG: fetched %s bytes from embed %s\n" "$(printf "%s" "$embed_html" | wc -c)" "$embed_url" >&2
            m3u8=$(printf "%s" "$embed_html" | grep -oE "['\"]https?://[^'\"]+\.m3u8[^'\"]*['\"]" | sed -E "s/^['\"](.*)['\"]$/\1/" | head -n 1)
            if [ -z "$m3u8" ]; then
                m3u8=$(printf "%s" "$embed_html" | grep -oE 'https?://[^"[:space:]]+\.m3u8[^"[:space:]]*' | head -n 1)
            fi
            if [ -n "$m3u8" ]; then
                [ -n "$DEBUG" ] && printf "DEBUG: found m3u8 in embed page: %s\n" "$m3u8" >&2
                temp_refr="$embed_url"  # m3u8 from embed needs embed page as referrer
                final_url=$(parse_m3u8 "$m3u8" "$embed_url")
                [ -n "$final_url" ] && { printf "%s\n" "$final_url"; [ -n "$temp_refr" ] && printf "%s\n" "$temp_refr"; return 0; }
                printf "%s\n" "$m3u8"
                [ -n "$temp_refr" ] && printf "%s\n" "$temp_refr"
                return 0
            fi
        fi
    fi

    # 4) Search for any m3u8-like path fragments in scripts and try to resolve to absolute using base
    frag=$(printf "%s" "$html" | grep -oE "['\"][^'\"]+\.m3u8[^'\"]*['\"]" | sed -E "s/^['\"](.*)['\"]$/\1/" | head -n 1)
    if [ -n "$frag" ]; then
        [ -n "$DEBUG" ] && printf "DEBUG: found fragment: %s\n" "$frag" >&2
        case "$frag" in
            http* ) printf "%s\n" "$frag"; printf "%s\n" "$php_url"; return 0 ;;
            //*) printf "https:%s\n" "$frag"; printf "%s\n" "$php_url"; return 0 ;;
            /*) site=$(printf "%s" "$php_url" | sed -n 's,\(^https\?://[^/]*\).*,\1,p'); printf "%s%s\n" "$site" "$frag"; printf "%s\n" "$php_url"; return 0 ;;
            *) site=$(printf "%s" "$php_url" | sed -n 's,\(^https\?://[^/]*\).*,\1,p'); printf "%s/%s\n" "$site" "$frag"; printf "%s\n" "$php_url"; return 0 ;;
        esac
    fi

    # Nothing found
    [ -n "$DEBUG" ] && printf "DEBUG: no m3u8 URL found in page or embeds\n" >&2
    return 1
}


