#!/bin/sh

# Ultra-Scale Stream Auditor
# Designed to scan 10,000+ streams from the master index without filters.
# Usage: ./audit_streams.sh ["Search Query"]

QUERY="$1"
LOG_FILE="audit_log.txt"
CONCURRENCY=40 
AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"

if [ -z "$QUERY" ]; then
    echo "🚀 Running MASTER Global Audit (scanning all 12k+ streams)..."
else
    echo "🎯 Running Targeted Audit for: '$QUERY'..."
fi

# Initialize log file
echo "Audit Log - $(date)" > "$LOG_FILE"
[ -n "$QUERY" ] && echo "Query: $QUERY" >> "$LOG_FILE" || echo "Query: GLOBAL MASTER" >> "$LOG_FILE"
echo "-------------------------------------------------------------------" >> "$LOG_FILE"

# Temporary files
TEMP_STREAMS=$(mktemp)

echo "Collecting streams from all sources..."

# 1. Master Community List (Bypassing the "Sport" filter for the audit)
echo "Fetching Master Community List (this may take a moment)..."
# We fetch the master index and parse it without the 'sport' filter
MASTER_URL="https://iptv-org.github.io/iptv/index.m3u"
COMM_RAW=$(curl -sL -A "$AGENT" "$MASTER_URL")
# Custom parser for the auditor to avoid the sport filter in community.sh
COMM_PARSED=$(printf "%s" "$COMM_RAW" | awk -F',' '/^#EXTINF/ {title=$NF} $0 ~ /^http/ {print "LIVE|" title "|Community|" $0}')

# 2. Sportsonline Plugin
echo "Reading Sportsonline Plugin..."
SO_DATA=$(sh -c ". ./src/core/fetcher.sh; . ./src/plugins/sportsonline.sh; plugin_fetch | plugin_parse")

# Merge and Filter
if [ -n "$QUERY" ]; then
    printf "%s\n%s" "$COMM_PARSED" "$SO_DATA" | grep -i "$QUERY" > "$TEMP_STREAMS"
else
    printf "%s\n%s" "$COMM_PARSED" "$SO_DATA" > "$TEMP_STREAMS"
fi

TOTAL=$(grep -c "^" "$TEMP_STREAMS" || echo 0)
if [ "$TOTAL" -eq 0 ]; then
    echo "❌ No streams found to audit."
    rm "$TEMP_STREAMS"
    exit 0
fi

echo "Found $TOTAL total streams. Starting industrial audit (P=$CONCURRENCY)..."
echo "Logging results to $LOG_FILE"

# Background worker logic
count=0
while IFS= read -r line; do
    [ -z "$line" ] && continue
    
    (
        title=$(echo "$line" | cut -d'|' -f2)
        url=$(echo "$line" | cut -d'|' -f4)
        [ -z "$url" ] && exit 0

        # Resolution logic
        if echo "$url" | grep -q "sportsonline"; then
            resolved_url=$(curl -sL -A "$AGENT" -e "$url" --connect-timeout 3 "$url" | grep -oE "https?://[^\"\s]+\.m3u8[^\"\s]*" | head -n 1)
        else
            resolved_url="$url"
        fi

        if [ -z "$resolved_url" ]; then
            echo "❌ RESOLVE FAIL | $title | $url" >> "$LOG_FILE"
        else
            # Perform a light probe
            if curl -sL -A "$AGENT" --connect-timeout 5 -r 0-100 "$resolved_url" > /dev/null; then
                echo "✅ WORKING | $title | $resolved_url" >> "$LOG_FILE"
            else
                echo "❌ DEAD | $title | $resolved_url" >> "$LOG_FILE"
            fi
        fi
    ) &

    count=$((count + 1))
    if [ $((count % CONCURRENCY)) -eq 0 ]; then
        wait
        # Update progress every batch
        printf "\rProcessed %d/%d streams..." "$count" "$TOTAL"
    fi
done < "$TEMP_STREAMS"
wait
echo "" # New line after progress

echo "-------------------------------------------------------------------"
echo "Audit complete!"
echo "Working: $(grep -c "✅ WORKING" "$LOG_FILE")"
echo "Dead: $(grep -c "❌ DEAD" "$LOG_FILE")"
echo "Failed Resolution: $(grep -c "❌ RESOLVE FAIL" "$LOG_FILE")"
echo "Full log available at: $LOG_FILE"

rm "$TEMP_STREAMS"
