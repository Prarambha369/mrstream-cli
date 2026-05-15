#!/bin/sh
# MrStream-Cli: A minimalist sports stream CLI.
# This tool is NOT affiliated with sportsonline.vc, sportssonline.click, or any content provider.

SOURCE_URL="https://sportsonline.vc/prog.txt"

# Use the official domain as the authoritative referer, as requested by the owner
OFFICIAL_DOMAIN="https://sportsonline.vc/"
AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0"

fetch_with_headers() {
    url="$1"
    # Default to the official domain if no specific referer is provided
    referer="${2:-$OFFICIAL_DOMAIN}"
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

        # First, check if this is a variant playlist (has EXT-X-STREAM-INF)
        if printf "%s" "$m3u8_content" | grep -q "EXT-X-STREAM-INF"; then
            [ -n "$DEBUG" ] && printf "DEBUG: m3u8 is a variant playlist (multiple quality options)\n" >&2
            # Extract variant playlists (lines that don't start with # or are URLs)
            stream_line=$(printf "%s" "$m3u8_content" | grep -v "^#" | grep -v "^$" | tail -n1)
        else
            [ -n "$DEBUG" ] && printf "DEBUG: m3u8 is a segment playlist (direct stream)\n" >&2
            # Direct segment playlist - try to return the m3u8 URL itself for mpv to handle
            printf "%s" "$m3u8_url"
            return 0
        fi

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
    
    # Fetch the PHP page with proper headers
    html=$(fetch_with_headers "$php_url")

    if [ -z "$html" ]; then
        [ -n "$DEBUG" ] && printf "DEBUG: initial fetch failed for %s\n" "$php_url" >&2
        return 1
    fi

    # Helper function: resolve relative URLs to absolute
    make_abs() {
        base="$1"
        rel="$2"
        site=$(printf "%s" "$base" | sed -n 's,\(^https\?://[^/]*\).*,\1,p')
        case "$rel" in
            //*) printf "https:%s" "$rel" ;;
            http:/*|https:/*) printf "%s" "$rel" ;;
            /*) printf "%s%s" "$site" "$rel" ;;
            http* ) printf "%s" "$rel" ;;
            *) printf "%s/%s" "$site" "$rel" ;;
        esac
    }

    # --- STRATEGY 1: Direct m3u8 in HTML ---
    m3u8=$(printf "%s" "$html" | grep -oE "['\"]https?://[^'\"]+\.m3u8[^'\"]*['\"]" | sed -E "s/^['\"](.*)['\"]$/\1/" | head -n 1)
    if [ -z "$m3u8" ]; then
        m3u8=$(printf "%s" "$html" | grep -oE 'https?://[^"[:space:]]+\.m3u8[^"[:space:]]*' | head -n 1)
    fi
    if [ -n "$m3u8" ]; then
        printf "%s\n%s\n" "$m3u8" "$php_url"
        return 0
    fi

    # --- STRATEGY 2: Config Key Patterns ---
    m3u8=$(printf "%s" "$html" | grep -oE "(file|source|hls|hlsUrl|streamUrl)\s*:\s*['\"][^'\"]+\.m3u8[^'\"]*['\"]" | sed -E "s/.*['\"](https?:.*m3u8.*)['\"].*/\1/" | head -n 1)
    if [ -n "$m3u8" ]; then
        printf "%s\n%s\n" "$m3u8" "$php_url"
        return 0
    fi

    # --- STRATEGY 3: Iframe/Embed Following ---
    embed_url=$(printf "%s" "$html" | grep -oE '<iframe[^>]*src="[^"]*"' | sed 's/.*src="\([^"]*\)".*/\1/' | head -n 1)
    if [ -z "$embed_url" ]; then
        embed_url=$(printf "%s" "$html" | grep -oE "<iframe[^>]*src='[^']*'" | sed "s/.*src='\([^']*\)'.*/\1/" | head -n 1)
    fi
    if [ -z "$embed_url" ]; then
        embed_url=$(printf "%s" "$html" | grep -oE 'src="https?://[^"]+"' | sed 's/src="\([^"]*\)"/\1/' | head -n 1)
    fi

    if [ -n "$embed_url" ]; then
        embed_url=$(make_abs "$php_url" "$embed_url")
        embed_html=$(fetch_with_headers "$embed_url" "$OFFICIAL_DOMAIN")
        if [ -z "$embed_html" ]; then
            embed_html=$(curl -s -L -A "$AGENT" --connect-timeout 10 "$embed_url" 2>/dev/null)
        fi
        
        if [ -n "$embed_html" ]; then
            m3u8=$(printf "%s" "$embed_html" | grep -oE "['\"]https?://[^'\"]+\.m3u8[^'\"]*['\"]" | sed -E "s/^['\"](.*)['\"]$/\1/" | head -n 1)
            if [ -z "$m3u8" ]; then
                m3u8=$(printf "%s" "$embed_html" | grep -oE 'https?://[^"[:space:]]+\.m3u8[^"[:space:]]*' | head -n 1)
            fi
            
            if [ -n "$m3u8" ]; then
                printf "%s\n%s\n" "$m3u8" "$OFFICIAL_DOMAIN"
                return 0
            fi
        fi
    fi

    # --- STRATEGY 4: Deep Probe (JS Redirections & Fragments) ---
    # Search for patterns like window.location.replace('...') or window.location.href = '...'
    # Use escaped parentheses for grep
    redir_url=$(printf "%s" "$html" | grep -oE "location\.(replace|href)\s*=\s*['\"]https?://[^'\"]*['\"]" | sed -E "s/.*['\"](https?:[^'\"]*)['\"].*/\1/" | head -n 1)
    if [ -n "$redir_url" ]; then
        # If it's a redirect to another page, we recursively try to resolve it once
        resolved_deep=$(plugin_resolve "$redir_url")
        if [ -n "$resolved_deep" ]; then
            printf "%s" "$resolved_deep"
            return 0
        fi
    fi

    # Search for any .m3u8 fragment and try to make it absolute
    frag=$(printf "%s" "$html" | grep -oE "['\"][^'\"]+\.m3u8[^'\"]*['\"]" | sed -E "s/^['\"](.*)['\"]$/\1/" | head -n 1)
    if [ -n "$frag" ]; then
        abs_frag=$(make_abs "$php_url" "$frag")
        printf "%s\n%s\n" "$abs_frag" "$php_url"
        return 0
    fi

    # CRITICAL FIX: No fallback to php_url. Return 1 to indicate failure.
    [ -n "$DEBUG" ] && printf "DEBUG: no playable m3u8 found. Refusing to return PHP URL.\n" >&2
    return 1
}
