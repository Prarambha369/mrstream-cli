#!/bin/sh
# MrStream-Cli: A minimalist sports stream CLI.
# This tool is NOT affiliated with sportsonline.vc, sportssonline.click, or any content provider.

#!/bin/sh
INSTALL_DIR="${HOME}/.local/bin"
SHARE_DIR="${HOME}/.local/share/mrstream"
CONFIG_DIR="${HOME}/.config/mrstream"
CACHE_DIR="${HOME}/.cache/mrstream"

rm -f "$INSTALL_DIR/mrstream"
rm -rf "$SHARE_DIR"
rm -rf "$CACHE_DIR"

printf "MrStream-Cli has been uninstalled.\n"
printf "Note: Configuration at %s was preserved.\n" "$CONFIG_DIR"
