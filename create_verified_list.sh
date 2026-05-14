#!/bin/sh

# Verified List Creator
# Extracts only the working streams from the audit log and creates a clean M3U file.

LOG_FILE="audit_log.txt"
OUTPUT_FILE="verified_streams.m3u"

if [ ! -f "$LOG_FILE" ]; then
    echo "❌ Error: $LOG_FILE not found. Please run the auditor first."
    exit 1
fi

echo "Extracting verified streams..."

# Start the M3U file
echo "#EXTM3U" > "$OUTPUT_FILE"

# Process the log
# Line format: ✅ WORKING | Title | URL
grep "✅ WORKING" "$LOG_FILE" | while IFS='|' read -r status title url; do
    # Clean up whitespace
    clean_title=$(echo "$title" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    clean_url=$(echo "$url" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [ -n "$clean_url" ]; then
        echo "#EXTINF:-1, $clean_title" >> "$OUTPUT_FILE"
        echo "$clean_url" >> "$OUTPUT_FILE"
    fi
done

COUNT=$(grep -c "#EXTINF" "$OUTPUT_FILE")
echo "✅ Success! $COUNT verified streams saved to $OUTPUT_FILE"
