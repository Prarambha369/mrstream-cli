# Community Streams Plugin - powered by iptv-org
# This plugin fetches open-source M3U playlists and parses them for mrstream-cli

# Using the curated sports category instead of the master index for better quality
SOURCE_URL="https://iptv-org.github.io/iptv/categories/sports.m3u"
AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"

# Plugin metadata (Phase 3 requirement)
plugin_name() {
    printf "community"
}

plugin_version() {
    printf "1.0.0"
}

plugin_description() {
    printf "IPTV-org community curated sports streams"
}

# Fetch raw M3U data
plugin_fetch() {
    # Point directly to the user's config directory for maximum reliability
    VERIFIED_FILE="$HOME/.config/mrstream/verified_streams.m3u"
    
    if [ -f "$VERIFIED_FILE" ]; then
        [ -n "$DEBUG" ] && printf "DEBUG: Using GOLD verified list: %s\n" "$VERIFIED_FILE" >&2
        cat "$VERIFIED_FILE"
        return 0
    fi
    
    # Fallback to the master index if no verified list exists
    curl -sL -A "$AGENT" "$SOURCE_URL"
}

# Parse M3U data into: time|title|channel|url
plugin_parse() {
    # Parse M3U format:
    # 1. Extract title (after the last comma)
    # 2. Extract group (group-title="...")
    # 3. Only keep entries that look like sports (though we are using the sports category now)
    
    awk -F',' '
    /^#EXTINF/ {
        title = $NF
        group = ""
        if (match($0, /group-title="[^"]*"/)) {
            group = substr($0, RSTART + 13, RLENGTH - 14)
        }
        if (group == "") group = "Sports"
        
        # Basic quality filter: prefer HD/4K/1080p if mentioned in title
        quality = "SD"
        if (title ~ /1080p|HD|4K/) quality = "HD"
        
        # Store metadata for the next line (the URL)
        meta = "LIVE|" title "|" group " (" quality ")"
        next
    }
    $0 ~ /^http/ {
        print meta "|" $0
    }'
}

# Resolve the URL (M3U links are usually direct)
plugin_resolve() {
    url="$1"
    
    [ -n "$DEBUG" ] && printf "DEBUG: community: resolving %s\n" "$url" >&2

    # Most community streams prefer NO referer or a blank one.
    # Sending iptv-org.github.io often triggers blocks.
    if echo "$url" | grep -q ".m3u8"; then
        [ -n "$DEBUG" ] && printf "DEBUG: community: URL is direct m3u8, returning as-is\n" >&2
        printf "%s\n" "$url"
        # Return empty string for referrer to let mpv use default behavior
        printf "" 
        return 0
    fi

    # If not a direct m3u8, follow the redirect
    [ -n "$DEBUG" ] && printf "DEBUG: community: following redirect to find effective URL...\n" >&2
    resolved=$(curl -sL -A "$AGENT" -o /dev/null -w "%{url_effective}" "$url")
    
    if [ -n "$resolved" ]; then
        [ -n "$DEBUG" ] && printf "DEBUG: community: resolved to %s\n" "$resolved" >&2
        printf "%s\n" "$resolved"
        printf ""
        return 0
    fi

    [ -n "$DEBUG" ] && printf "DEBUG: community: resolve failed (redirect empty)\n" >&2
    return 1
}
