#!/bin/sh
# MrStream-Cli: A minimalist sports stream CLI.
# This tool is NOT affiliated with sportsonline.vc, sportssonline.click, or any content provider.

# JS/Browser fallback resolver using yt-dlp (PONYTAIL-DEBT #2)
# Called when direct URL extraction fails

resolve_with_ytdlp() {
    url="$1"
    referer="$2"
    
    [ -z "$url" ] && return 1
    
    if ! command -v yt-dlp >/dev/null 2>&1; then
        [ -n "$DEBUG" ] && printf "DEBUG: yt-dlp not found, skipping\n" >&2
        return 1
    fi
    
    [ -n "$DEBUG" ] && printf "DEBUG: trying yt-dlp fallback for: %s\n" "$url" >&2
    
    # Try to extract stream URL using yt-dlp
    if [ -n "$referer" ]; then
        stream_url=$(yt-dlp --no-playlist --get-url --referer "$referer" "$url" 2>/dev/null | head -n 1)
    else
        stream_url=$(yt-dlp --no-playlist --get-url "$url" 2>/dev/null | head -n 1)
    fi
    
    if [ -n "$stream_url" ]; then
        [ -n "$DEBUG" ] && printf "DEBUG: yt-dlp resolved: %s\n" "$stream_url" >&2
        printf "%s\n" "$stream_url"
        # Return the original URL as referer
        printf "%s\n" "$url"
        return 0
    fi
    
    [ -n "$DEBUG" ] && printf "DEBUG: yt-dlp failed to resolve\n" >&2
    return 1
}
