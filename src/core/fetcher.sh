#!/bin/sh
# MrStream-Cli: A minimalist sports stream CLI.
# This tool is NOT affiliated with sportsonline.vc, sportssonline.click, or any content provider.

# Improved fetch with HTTP status checking (Phase 2 requirement)
fetch_url() {
    url="$1"
    referer="${2:-}"
    user_agent="${3:-}"
    max_retries=3
    retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        # Build curl command with status code in stderr
        if [ -n "$referer" ]; then
            if [ -n "$user_agent" ]; then
                response=$(curl -s -L -w "\n%{http_code}" -e "$referer" -A "$user_agent" --connect-timeout 10 "$url" 2>/dev/null)
            else
                response=$(curl -s -L -w "\n%{http_code}" -e "$referer" --connect-timeout 10 "$url" 2>/dev/null)
            fi
        elif [ -n "$user_agent" ]; then
            response=$(curl -s -L -w "\n%{http_code}" -A "$user_agent" --connect-timeout 10 "$url" 2>/dev/null)
        else
            response=$(curl -s -L -w "\n%{http_code}" --connect-timeout 10 "$url" 2>/dev/null)
        fi
        
        # Extract status code from last line
        http_code=$(printf "%s" "$response" | tail -n 1)
        body=$(printf "%s" "$response" | sed '$d')
        
        # Check HTTP status
        case "$http_code" in
            200|201|204|301|302|303|307|308)
                printf "%s" "$body"
                return 0
                ;;
            4*|5*)
                [ -n "$DEBUG" ] && printf "DEBUG: HTTP %s from %s\n" "$http_code" "$url" >&2
                ;;
            *)
                [ -n "$DEBUG" ] && printf "DEBUG: curl failed for %s\n" "$url" >&2
                ;;
        esac
        
        retry_count=$((retry_count + 1))
        [ $retry_count -lt $max_retries ] && sleep 2
    done
    
    return 1
}

# Simplified fetch for JSON APIs
fetch_json() {
    url="$1"
    result=$(fetch_url "$url")
    if [ -n "$result" ]; then
        printf "%s" "$result"
        return 0
    fi
    return 1
}
