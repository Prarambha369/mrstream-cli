#!/bin/sh
# MrStream-Cli: A minimalist sports stream CLI.
# This tool is NOT affiliated with sportsonline.vc, sportssonline.click, or any content provider.

fetch_url() {
    url="$1"
    max_retries=3
    retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        if curl -s -L --connect-timeout 10 "$url"; then
            return 0
        fi
        retry_count=$((retry_count + 1))
        sleep 2
    done
    return 1
}
