#!/bin/sh
# MrStream-Cli: A minimalist sports stream CLI.
# This tool is NOT affiliated with sportsonline.vc, sportssonline.click, or any content provider.

# HLS quality selection - parse m3u8 variant playlists (PONYTAIL-DEBT #3)
# Based on ani-cli's approach

# Parse m3u8 variant playlist and extract quality options
parse_m3u8_variants() {
    m3u8_url="$1"
    referer="$2"
    
    [ -z "$m3u8_url" ] && return 1
    
    # Fetch the m3u8 playlist
    if [ -n "$referer" ]; then
        playlist=$(curl -sL -e "$referer" "$m3u8_url" 2>/dev/null)
    else
        playlist=$(curl -sL "$m3u8_url" 2>/dev/null)
    fi
    
    [ -z "$playlist" ] && return 1
    
    # Check if it's a variant playlist (has #EXT-X-STREAM-INF)
    if ! printf "%s" "$playlist" | grep -q "#EXT-X-STREAM-INF"; then
        [ -n "$DEBUG" ] && printf "DEBUG: not a variant playlist, using as-is\n" >&2
        return 1
    fi
    
    [ -n "$DEBUG" ] && printf "DEBUG: parsing variant playlist\n" >&2
    
    # Extract base URL for relative paths
    base_url=$(printf "%s" "$m3u8_url" | sed 's|[^/]*$||')
    
    # Parse playlist: extract resolution and URL pairs
    # Format: resolution|url
    variants=$(printf "%s" "$playlist" | sed 's|^#EXT-X-STREAM-INF.*RESOLUTION=||g; s|,.*||g; $!N; s|\n| >|' | grep -E '^[0-9]+x[0-9]+' | while read -r line; do
        resolution=$(printf "%s" "$line" | cut -d'>' -f1)
        url=$(printf "%s" "$line" | cut -d'>' -f2 | sed 's/^[[:space:]]*//')
        
        # Make absolute URL if relative
        case "$url" in
            http:/*|https:/*) abs_url="$url" ;;
            /*) 
                site=$(printf "%s" "$m3u8_url" | sed -n 's,\(^https\?://[^/]*\).*,\1,p')
                abs_url="${site}${url}"
                ;;
            *) abs_url="${base_url}${url}" ;;
        esac
        
        # Extract height (e.g., 1920x1080 -> 1080p)
        height=$(printf "%s" "$resolution" | cut -d'x' -f2)
        printf "%sp|%s\n" "$height" "$abs_url"
    done | sort -rn)
    
    if [ -z "$variants" ]; then
        [ -n "$DEBUG" ] && printf "DEBUG: failed to parse variants\n" >&2
        return 1
    fi
    
    printf "%s" "$variants"
    return 0
}

# Select quality from parsed variants
# If quality is specified, try to match it; otherwise return best (first)
select_quality() {
    variants="$1"
    requested_quality="$2"
    
    [ -z "$variants" ] && return 1
    
    case "$requested_quality" in
        best|"")
            # Return best quality (first line)
            selected=$(printf "%s" "$variants" | head -n 1)
            ;;
        worst)
            # Return worst quality (last line)
            selected=$(printf "%s" "$variants" | tail -n 1)
            ;;
        *)
            # Try to match specific quality (e.g., 720p, 1080)
            selected=$(printf "%s" "$variants" | grep -m 1 "^${requested_quality}" || printf "%s" "$variants" | grep -m 1 "$requested_quality")
            
            if [ -z "$selected" ]; then
                [ -n "$DEBUG" ] && printf "DEBUG: quality '%s' not found, defaulting to best\n" "$requested_quality" >&2
                selected=$(printf "%s" "$variants" | head -n 1)
            fi
            ;;
    esac
    
    [ -z "$selected" ] && return 1
    
    quality_label=$(printf "%s" "$selected" | cut -d'|' -f1)
    stream_url=$(printf "%s" "$selected" | cut -d'|' -f2)
    
    [ -n "$DEBUG" ] && printf "DEBUG: selected quality: %s\n" "$quality_label" >&2
    
    printf "%s" "$stream_url"
    return 0
}
