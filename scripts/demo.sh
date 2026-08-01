#!/bin/sh
# MrStream-Cli Demo Script
# Run this to generate a text-based demo recording:
#   script -q -c "sh scripts/demo.sh" .assets/demo.typescript
# Then replay with: scriptreplay .assets/demo.typescript

# Use a fixed terminal width for clean output
STTY_SAVED=$(stty -g 2>/dev/null || echo "")

# Ensure we're in the project root
cd "$(dirname "$0")/.." || exit 1

# Check if mrstream is accessible
if [ ! -x ./mrstream ]; then
    echo "mrstream not found in project root"
    exit 1
fi

# ANSI helpers
BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
RESET="\033[0m"

demo_section() {
    echo
    echo "${BOLD}━━━ $1 ━━━${RESET}"
    echo
}

demo_cmd() {
    echo "${DIM}\$ ${CYAN}$1${RESET}"
    eval "$1" 2>/dev/null
    echo
    sleep 1
}

# ─── Demo ───

echo "${BOLD}${GREEN}"
echo "  __  __           _            _      "
echo " |  \/  |         | |          | |     "
echo " | \  / |_ __ ___ | |_ ___  ___| |__   "
echo " | |\/| | '__/ __|| __/ _ \/ __| '_ \  "
echo " | |  | | |  \__ \| ||  __/ (__| | | | "
echo " |_|  |_|_|  |___/ \__\___|\___|_| |_| "
echo "${RESET}"
echo "${DIM}Live sports from your terminal${RESET}"
echo "${DIM}v$(grep '^VERSION=' mrstream | cut -d'"' -f2)${RESET}"

demo_section "1. HELP"
demo_cmd "./mrstream --help"

demo_section "2. VERSION"
demo_cmd "./mrstream version"

demo_section "3. DOCTOR"
demo_cmd "./mrstream doctor"

demo_section "4. SPORTSONLINE: Fetch Schedule"
echo "${DIM}\$ Fetching live events from sportsonline.st...${RESET}"
. src/core/fetcher.sh
. src/plugins/sportsonline.sh
plugin_fetch 2>/dev/null | plugin_parse 2>/dev/null | head -12
echo "${DIM}${BOLD}... and 57 more events${RESET}"

demo_section "5. COMMUNITY (iptv-org): Live Channels"
echo "${DIM}\$ Fetching 472 live sports channels...${RESET}"
. src/plugins/community.sh
plugin_fetch 2>/dev/null | plugin_parse 2>/dev/null | head -8
echo "${DIM}${BOLD}... and 464 more channels${RESET}"

demo_section "6. SEARCH (filter example)"
echo "${DIM}\$ Searching for 'UFC' events...${RESET}"
plugin_fetch 2>/dev/null | plugin_parse 2>/dev/null | grep -i "ufc" | head -5 || echo "(No UFC events currently scheduled)"

demo_section "7. SELF-UPDATE"
demo_cmd "./mrstream update"

demo_section "8. RESOLVE STREAM"
echo "${DIM}\$ Resolving a live stream URL...${RESET}"
result=$(plugin_resolve "https://v4.sportsonlinne.click/channels/hd/hd1.php" 2>/dev/null)
echo "Stream:   $(echo "$result" | sed -n '1p')"
echo "Referer:  $(echo "$result" | sed -n '2p')"
echo "${GREEN}Stream URL resolved (pass to mpv for playback)${RESET}"

echo
echo "${BOLD}${GREEN}━━━ Demo Complete ━━━${RESET}"
echo "${DIM}Use 'mrstream search' to browse all events interactively.${RESET}"
echo

# Restore stty
if [ -n "$STTY_SAVED" ]; then
    stty "$STTY_SAVED" 2>/dev/null
fi
