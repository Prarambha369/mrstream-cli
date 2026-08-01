#!/bin/sh
# MrStream-Cli: A minimalist sports stream CLI.
# This tool is NOT affiliated with sportsonline.vc, sportssonline.click, or any content provider.

SOURCE_URL="https://sportsonline.st/prog.txt"

# Use the official domain as the authoritative referer, as requested by the owner
OFFICIAL_DOMAIN="https://sportsonline.st/"
AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0"

# Plugin metadata (Phase 3 requirement)
plugin_name() {
    printf "sportsonline"
}

plugin_version() {
    printf "1.0.0"
}

plugin_description() {
    printf "SportsOnline.st live sports streams"
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
    
    # Fetch the PHP page with proper headers (referer + user-agent)
    html=$(fetch_url "$php_url" "$OFFICIAL_DOMAIN" "$AGENT")

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
    [ -n "$DEBUG" ] && printf "DEBUG: S1 - scanning for direct m3u8 in HTML...\n" >&2
    m3u8=$(printf "%s" "$html" | grep -oE "['\"]https?://[^'\"]+\.m3u8[^'\"]*['\"]" | sed -E "s/^['\"](.*)['\"]$/\1/" | head -n 1)
    if [ -z "$m3u8" ]; then
        m3u8=$(printf "%s" "$html" | grep -oE 'https?://[^"[:space:]]+\.m3u8[^"[:space:]]*' | head -n 1)
    fi
    if [ -n "$m3u8" ]; then
        [ -n "$DEBUG" ] && printf "DEBUG: S1 - found direct m3u8: %s\n" "$m3u8" >&2
        printf "%s\n%s\n" "$m3u8" "$php_url"
        return 0
    fi
    [ -n "$DEBUG" ] && printf "DEBUG: S1 - no direct m3u8 found.\n" >&2

    # --- STRATEGY 2: Config Key Patterns ---
    [ -n "$DEBUG" ] && printf "DEBUG: S2 - scanning JS config keys (file, source, hlsUrl)...\n" >&2
    m3u8=$(printf "%s" "$html" | grep -oE "(file|source|hls|hlsUrl|streamUrl)\s*:\s*['\"][^'\"]+\.m3u8[^'\"]*['\"]" | sed -E "s/.*['\"](https?:.*m3u8.*)['\"].*/\1/" | head -n 1)
    if [ -n "$m3u8" ]; then
        [ -n "$DEBUG" ] && printf "DEBUG: S2 - found m3u8 in config: %s\n" "$m3u8" >&2
        printf "%s\n%s\n" "$m3u8" "$php_url"
        return 0
    fi
    [ -n "$DEBUG" ] && printf "DEBUG: S2 - no config key m3u8 found.\n" >&2

    # --- STRATEGY 3: Iframe/Embed Following ---
    [ -n "$DEBUG" ] && printf "DEBUG: S3 - looking for iframe/embed...\n" >&2
    embed_url=$(printf "%s" "$html" | grep -oE '<iframe[^>]*src="[^"]*"' | sed 's/.*src="\([^"]*\)".*/\1/' | head -n 1)
    if [ -z "$embed_url" ]; then
        embed_url=$(printf "%s" "$html" | grep -oE "<iframe[^>]*src='[^']*'" | sed "s/.*src='\([^']*\)'.*/\1/" | head -n 1)
    fi
    if [ -z "$embed_url" ]; then
        embed_url=$(printf "%s" "$html" | grep -oE 'src="https?://[^"]+"' | sed 's/src="\([^"]*\)"/\1/' | head -n 1)
    fi

    if [ -n "$embed_url" ]; then
        embed_url=$(make_abs "$php_url" "$embed_url")
        [ -n "$DEBUG" ] && printf "DEBUG: S3 - following embed iframe: %s\n" "$embed_url" >&2
        # Use php_url as referer (not generic domain) to bypass domain protection
        # Fast path: try php_url as referer (bypasses domain protection).
        # If it fails, fall through to S5 which handles deep probing & base64 decode.
        embed_html=$(fetch_url "$embed_url" "$php_url" "$AGENT")
        
        if [ -n "$embed_html" ]; then
            [ -n "$DEBUG" ] && printf "DEBUG: S3 - embed page fetched (%d bytes), scanning for m3u8...\n" "${#embed_html}" >&2
            m3u8=$(printf "%s" "$embed_html" | grep -oE "['\"]https?://[^'\"]+\.m3u8[^'\"]*['\"]" | sed -E "s/^['\"](.*)['\"]$/\1/" | head -n 1)
            if [ -z "$m3u8" ]; then
                m3u8=$(printf "%s" "$embed_html" | grep -oE 'https?://[^"[:space:]]+\.m3u8[^"[:space:]]*' | head -n 1)
            fi
            
            if [ -n "$m3u8" ]; then
                [ -n "$DEBUG" ] && printf "DEBUG: S3 - found m3u8 in embed: %s\n" "$m3u8" >&2
                printf "%s\n%s\n" "$m3u8" "$OFFICIAL_DOMAIN"
                return 0
            fi
            [ -n "$DEBUG" ] && printf "DEBUG: S3 - no m3u8 found in embed page.\n" >&2
        else
            [ -n "$DEBUG" ] && printf "DEBUG: S3 - embed page empty or unreachable.\n" >&2
        fi
    else
        [ -n "$DEBUG" ] && printf "DEBUG: S3 - no iframe/embed/src found in HTML.\n" >&2
    fi

    # --- STRATEGY 4: Deep Probe (JS Redirections & Fragments) ---
    [ -n "$DEBUG" ] && printf "DEBUG: S4 - probing JS redirections and m3u8 fragments...\n" >&2
    # Search for patterns like window.location.replace('...') or window.location.href = '...'
    redir_url=$(printf "%s" "$html" | grep -oE "location\.(replace|href)\s*=\s*['\"]https?://[^'\"]*['\"]" | sed -E "s/.*['\"](https?:[^'\"]*)['\"].*/\1/" | head -n 1)
    if [ -n "$redir_url" ]; then
        [ -n "$DEBUG" ] && printf "DEBUG: S4 - found JS redirect: %s\n" "$redir_url" >&2
        # If it's a redirect to another page, we recursively try to resolve it once
        resolved_deep=$(plugin_resolve "$redir_url")
        if [ -n "$resolved_deep" ]; then
            printf "%s" "$resolved_deep"
            return 0
        fi
        [ -n "$DEBUG" ] && printf "DEBUG: S4 - recursive resolve of redirect failed.\n" >&2
    else
        [ -n "$DEBUG" ] && printf "DEBUG: S4 - no JS redirect found.\n" >&2
    fi

    # Search for any .m3u8 fragment and try to make it absolute
    [ -n "$DEBUG" ] && printf "DEBUG: S4b - scanning for relative m3u8 fragments...\n" >&2
    frag=$(printf "%s" "$html" | grep -oE "['\"][^'\"]+\.m3u8[^'\"]*['\"]" | sed -E "s/^['\"](.*)['\"]$/\1/" | head -n 1)
    if [ -n "$frag" ]; then
        abs_frag=$(make_abs "$php_url" "$frag")
        [ -n "$DEBUG" ] && printf "DEBUG: S4b - resolved fragment to: %s\n" "$abs_frag" >&2
        printf "%s\n%s\n" "$abs_frag" "$php_url"
        return 0
    fi
    [ -n "$DEBUG" ] && printf "DEBUG: S4b - no m3u8 fragments found.\n" >&2

    # --- STRATEGY 5: Embedded Player URL Hunting ---
    # Last-resort: collect ALL non-ad external URLs from the page and probe each
    # with the correct referer (php_url) to bypass domain protection.
    # Also attempt base64 config decoding (common in Clappr/AKS embed players).
    [ -n "$DEBUG" ] && printf "DEBUG: S5 - hunting for embedded player URLs...\n" >&2

    # Collect all external URLs from src/href attributes, excluding known ad/tracking domains
    all_urls=$(printf "%s" "$html" | grep -oE '(src|href)="[^"]*"' | sed 's/^[a-z]*="//;s/"$//' | grep -vE '^#' | sort -u)
    [ -n "$all_urls" ] && all_urls=$(printf "%s" "$all_urls" | while IFS= read -r u; do
        [ -z "$u" ] && continue
        # Skip fragment/anchor-only URLs
        case "$u" in
            http://*|https://*) printf "%s" "$u" ;;
            //*) printf "https:%s" "$u" ;;
            *)  # Try make_abs if available, otherwise prefix with php_url domain
                resolved=$(make_abs "$php_url" "$u" 2>/dev/null)
                if [ -n "$resolved" ]; then
                    printf "%s" "$resolved"
                else
                    site=$(printf "%s" "$php_url" | sed -n 's,\(^https\?://[^/]*\).*,\1,p')
                    printf "%s/%s" "$site" "$u"
                fi
                ;;
        esac
        printf "\n"
    done)

    [ -n "$DEBUG" ] && {
        count=$(printf "%s" "$all_urls" | grep -c . 2>/dev/null || echo 0)
        printf "DEBUG: S5 - collected %d URLs total\n" "$count" >&2
    }

    # Remove known ad/tracking domains. Probe all remaining URLs — embed domains change
    # frequently, so keyword filtering is too brittle.
    player_urls=$(printf "%s" "$all_urls" | grep -vE '(googlesyndication|google-analytics|doubleclick|histats|whos\.amung\.us|facebook\.com|twitter\.com|cloudflare|jquery|bootstrap|cdn\.[^/]*\.js|fontawesome|googleapis\.com)' | sort -u)

    if [ -n "$player_urls" ]; then
        count=$(printf "%s" "$player_urls" | wc -l)
        [ -n "$DEBUG" ] && printf "DEBUG: S5 - found %d candidate player URLs\n" "$count" >&2

        # Iterate URLs and probe each - capture result from subshell
        s5_result=$(printf "%s" "$player_urls" | while IFS= read -r pu; do
            [ -z "$pu" ] && continue
            [ -n "$DEBUG" ] && printf "DEBUG: S5 - probing: %s\n" "$pu" >&2

            # Fetch with the PHP page URL as referer (not generic domain)
            # This is critical for domain-protected embeds
            pu_html=$(fetch_url "$pu" "$php_url" "$AGENT")
            if [ -z "$pu_html" ]; then
                # Fallback: try without referer
                pu_html=$(curl -sL -A "$AGENT" --connect-timeout 10 "$pu" 2>/dev/null)
            fi
            [ -z "$pu_html" ] && continue

            # (a) Direct m3u8 URL scan
            m3u8=$(printf "%s" "$pu_html" | grep -oE "['\"]https?://[^'\"]+\.m3u8[^'\"]*['\"]" | sed -E "s/^['\"](.*)['\"]$/\1/" | head -n 1)
            if [ -z "$m3u8" ]; then
                m3u8=$(printf "%s" "$pu_html" | grep -oE 'https?://[^"[:space:]]+\.m3u8[^"[:space:]]*' | head -n 1)
            fi
            if [ -n "$m3u8" ]; then
                [ -n "$DEBUG" ] && printf "DEBUG: S5a - found direct m3u8: %s\n" "$m3u8" >&2
                printf "%s\n%s\n" "$m3u8" "$php_url"
                break
            fi

            # (b) Base64 config decode (Clappr players, e.g. window._econfig)
            b64=$(printf "%s" "$pu_html" | grep -oE "window\._econfig='[A-Za-z0-9+/=_-]+'" | sed "s/window._econfig='//;s/'//")
            if [ -z "$b64" ]; then
                b64=$(printf "%s" "$pu_html" | grep -oE 'window\._econfig="[A-Za-z0-9+/=_-]+"' | sed 's/window._econfig="//;s/"//')
            fi
            if [ -n "$b64" ]; then
                [ -n "$DEBUG" ] && printf "DEBUG: S5b - found base64 config (%d chars), decoding...\n" "${#b64}" >&2
                decoded=$(printf "%s" "$b64" | base64 -d 2>/dev/null || printf "%s" "$b64" | openssl base64 -d 2>/dev/null)
                if [ -n "$decoded" ]; then
                    [ -n "$DEBUG" ] && printf "DEBUG: S5b - decoded config: %.200s\n" "$decoded" >&2
                    # Extract URLs from decoded JSON using POSIX-safe patterns
                    m3u8=$(printf "%s" "$decoded" | grep -oE "https?://[^\"' )}]+\.m3u8[^\"' )}]*" | head -n 1)
                    if [ -z "$m3u8" ]; then
                        m3u8=$(printf "%s" "$decoded" | grep -oE "https?://[^\"' )}]+" | head -n 1)
                    fi
                    if [ -n "$m3u8" ]; then
                        [ -n "$DEBUG" ] && printf "DEBUG: S5b - found m3u8 via base64: %s\n" "$m3u8" >&2
                        printf "%s\n%s\n" "$m3u8" "$php_url"
                        break
                    fi
                else
                    [ -n "$DEBUG" ] && printf "DEBUG: S5b - base64 decode failed\n" >&2
                fi
            fi

            # (c) JS variable assignments with stream URLs (file:, source:, url:)
            js_url=$(printf "%s" "$pu_html" | grep -oE "['\"](file|src|source|url|stream|hls|playlist)['\"]\s*[:=]\s*['\"][^'\"]+['\"]" | sed -E "s/.*['\"](https?:[^'\"]+)['\"].*/\1/" | head -n 1)
            if [ -z "$js_url" ]; then
                js_url=$(printf "%s" "$pu_html" | grep -oE "['\"](file|src|source|url|stream|hls|playlist)['\"]\s*[:=]\s*['\"]([a-zA-Z0-9_./:-]+)['\"]" | sed -E "s/.*['\"]([a-zA-Z0-9_./:-]+)['\"].*/\1/" | grep -E '\.' | head -n 1)
            fi
            if [ -n "$js_url" ]; then
                js_url=$(make_abs "$pu" "$js_url")
                [ -n "$DEBUG" ] && printf "DEBUG: S5c - found URL in JS config: %s\n" "$js_url" >&2
                if echo "$js_url" | grep -qE '\.(m3u8|mp4|ts)$'; then
                    printf "%s\n%s\n" "$js_url" "$php_url"
                    break
                fi
                # It might be another page - follow it
                sub_html=$(fetch_url "$js_url" "$pu" "$AGENT")
                if [ -n "$sub_html" ]; then
                    sub_m3u8=$(printf "%s" "$sub_html" | grep -oE "['\"]https?://[^'\"]+\.m3u8[^'\"]*['\"]" | sed -E "s/^['\"](.*)['\"]$/\1/" | head -n 1)
                    if [ -z "$sub_m3u8" ]; then
                        sub_m3u8=$(printf "%s" "$sub_html" | grep -oE 'https?://[^"[:space:]]+\.m3u8[^"[:space:]]*' | head -n 1)
                    fi
                    if [ -n "$sub_m3u8" ]; then
                        [ -n "$DEBUG" ] && printf "DEBUG: S5c - found m3u8 by following JS URL: %s\n" "$sub_m3u8" >&2
                        printf "%s\n%s\n" "$sub_m3u8" "$php_url"
                        break
                    fi
                fi
            fi

            # (d) Data attributes (data-src, data-url, data-video, data-stream)
            data_url=$(printf "%s" "$pu_html" | grep -oE 'data-(src|url|video|stream|file|source)="[^"]*"' | sed 's/.*="//;s/"$//' | head -n 1)
            if [ -n "$data_url" ]; then
                data_url=$(make_abs "$pu" "$data_url")
                [ -n "$DEBUG" ] && printf "DEBUG: S5d - found data attribute URL: %s\n" "$data_url" >&2
                printf "%s\n%s\n" "$data_url" "$php_url"
                break
            fi
        done)

        if [ -n "$s5_result" ]; then
            printf "%s" "$s5_result"
            return 0
        fi
        [ -n "$DEBUG" ] && printf "DEBUG: S5 - all player URLs exhausted, no m3u8 found\n" >&2
    else
        [ -n "$DEBUG" ] && printf "DEBUG: S5 - no candidate player URLs found in HTML\n" >&2
    fi

    # --- STRATEGY 5e: Deep JS Resolver (Node.js/Playwright) ---
    # Last-resort: launch a headless browser to execute JavaScript and decode
    # obfuscated Clappr/AKS configs (window._econfig) that require JS execution.
    [ -n "$DEBUG" ] && printf "DEBUG: S5e - attempting deep JS resolver...\n" >&2

    # Resolver path is passed via S_DIR (exported by mrstream main script)
    RESOLVER_DIR="${S_DIR:-$HOME/.local/share/mrstream}"
    RESOLVER="$RESOLVER_DIR/src/core/deep-resolver.js"

    js_resolved=""
    if [ -f "$RESOLVER" ] && command -v node >/dev/null 2>&1 && node -e "require.resolve('playwright')" 2>/dev/null; then
        # Try the embed URL first (from S3), then the PHP URL
        for try_url in "$embed_url" "$php_url"; do
            [ -z "$try_url" ] && continue
            [ -n "$DEBUG" ] && printf "DEBUG: S5e - probing with node: %s\n" "$try_url" >&2
            js_resolved=$(node "$RESOLVER" "$try_url" "$php_url" 2>/dev/null)
            if [ -n "$js_resolved" ]; then
                [ -n "$DEBUG" ] && printf "DEBUG: S5e - deep resolver succeeded\n" >&2
                break
            fi
        done
    else
        [ -n "$DEBUG" ] && {
            if ! command -v node >/dev/null 2>&1; then
                printf "DEBUG: S5e - node not found, skipping\n" >&2
            elif ! command -v npx >/dev/null 2>&1; then
                printf "DEBUG: S5e - npx not found, skipping\n" >&2
            elif [ ! -f "$RESOLVER" ]; then
                printf "DEBUG: S5e - resolver script not found at %s\n" "$RESOLVER" >&2
            fi
        }
    fi

    if [ -n "$js_resolved" ]; then
        printf "%s" "$js_resolved"
        return 0
    fi
    [ -n "$DEBUG" ] && printf "DEBUG: S5e - deep JS resolver failed\n" >&2

    # CRITICAL FIX: No fallback to php_url. Return 1 to indicate failure.
    [ -n "$DEBUG" ] && printf "DEBUG: no playable m3u8 found. Refusing to return PHP URL.\n" >&2
    return 1
}
