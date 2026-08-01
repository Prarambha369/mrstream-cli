#!/bin/sh
# MrStream-Cli: A minimalist sports stream CLI.
# This tool is NOT affiliated with sportsonline.vc, sportssonline.click, or any content provider.

# Unified player launch function
# Consolidates duplicated mpv/vlc/mplayer logic (PONYTAIL-DEBT #5)

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0"

# Find the first available player
find_player() {
    for player in mpv vlc cvlc mplayer; do
        if command -v "$player" >/dev/null 2>&1; then
            printf "%s" "$player"
            return 0
        fi
    done
    return 1
}

# Play stream with given player, title, m3u8 URL, and optional referer
play_stream() {
    player="$1"
    title="$2"
    m3u8="$3"
    refr="$4"

    [ -n "$DEBUG" ] && printf "DEBUG: player=%s title=%s m3u8=%s refr=%s\n" "$player" "$title" "$m3u8" "$refr" >&2

    case "$player" in
        mpv)
            # Try with referer first if provided
            if [ -n "$refr" ] && [ "$refr" != "$m3u8" ]; then
                mpv --title="MrStream: $title" \
                    --http-header-fields="Referer: $refr" \
                    --user-agent="$UA" \
                    "$m3u8" 2>/dev/null && return 0

                mpv --title="MrStream: $title" \
                    --user-agent="$UA" \
                    --referrer="$refr" \
                    "$m3u8" 2>/dev/null && return 0

                # Fallback: without yt-dlp
                mpv --title="MrStream: $title" \
                    --no-ytdl \
                    --user-agent="$UA" \
                    --referrer="$refr" \
                    "$m3u8" 2>/dev/null && return 0
            fi

            # Direct play without referer
            mpv --title="MrStream: $title" "$m3u8" 2>/dev/null && return 0
            mpv --title="MrStream: $title" --no-ytdl "$m3u8" 2>/dev/null
            ;;
        vlc|cvlc)
            # Try with referer first if provided
            if [ -n "$refr" ] && [ "$refr" != "$m3u8" ]; then
                "$player" --quiet --play-and-exit \
                    --meta-title="MrStream: $title" \
                    --http-user-agent="$UA" \
                    --http-referrer="$refr" \
                    "$m3u8" 2>/dev/null && return 0
            fi

            # Direct play without referer
            "$player" --quiet --play-and-exit --meta-title="MrStream: $title" "$m3u8" 2>/dev/null
            ;;
        mplayer)
            mplayer "$m3u8" 2>/dev/null
            ;;
        *)
            [ -n "$DEBUG" ] && printf "DEBUG: unknown player: %s\n" "$player" >&2
            return 1
            ;;
    esac
}
